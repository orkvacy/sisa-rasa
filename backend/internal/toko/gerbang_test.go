package toko

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
)

// gerbangPalsu Midtrans tiruan: status tiap tagihan diatur dari tes
type gerbangPalsu struct {
	mu      sync.Mutex
	status  map[string]StatusBayar
	ditagih []PermintaanTagihan
	dibatal []string
	rusak   bool // Tagih gagal (Midtrans gangguan)
}

func (g *gerbangPalsu) Tagih(_ context.Context, t PermintaanTagihan) (map[string]string, error) {
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.rusak {
		return nil, errors.New("midtrans mati")
	}
	g.ditagih = append(g.ditagih, t)
	return map[string]string{"idTagihan": t.IDTagihan, "penyedia": "midtrans", "isiQr": "QR-" + t.IDTagihan}, nil
}

func (g *gerbangPalsu) Status(_ context.Context, id string) (StatusBayar, error) {
	g.mu.Lock()
	defer g.mu.Unlock()
	if st, ada := g.status[id]; ada {
		return st, nil
	}
	return StatusBayar{Status: BayarMenunggu}, nil
}

func (g *gerbangPalsu) Batalkan(_ context.Context, id string) error {
	g.mu.Lock()
	defer g.mu.Unlock()
	g.dibatal = append(g.dibatal, id)
	return nil
}

func (g *gerbangPalsu) SahNotifikasi(n NotifikasiBayar) bool { return n.TandaTangan == "sah" }

func (g *gerbangPalsu) atur(id string, st StatusBayar) {
	g.mu.Lock()
	defer g.mu.Unlock()
	g.status[id] = st
}

func ujiGerbang(t *testing.T, siapkan func(*testing.T) siap) {
	x := siapkan(t)
	g := &gerbangPalsu{status: map[string]StatusBayar{}}
	x.l.Gerbang = g
	ctx := context.Background()
	webhook := func(id string) error {
		return x.l.TerimaNotifikasi(ctx, NotifikasiBayar{IDTagihan: id, KodeStatus: "200", Total: "1", TandaTangan: "sah"})
	}

	p, _, err := x.l.BuatPesanan(ctx, rani, map[string]int{x.sarapan.ID: 1}, "qris", "kunci-gerbang-1")
	if err != nil {
		t.Fatal(err)
	}
	lama := p.Tagihan["idTagihan"]
	if !strings.HasPrefix(lama, p.ID+"-") || p.Tagihan["isiQr"] == "" || g.ditagih[0].Total != p.Total {
		t.Fatalf("tagihan midtrans: %v / %+v", p.Tagihan, g.ditagih)
	}
	if b := g.ditagih[0].BerlakuMenit; b < 1 || b >= menitBatasBayar {
		t.Errorf("tagihan harus kedaluwarsa sebelum batas bayar: %d menit", b)
	}
	// request diulang (kunci sama): ga minta tagihan lagi
	if ulang, _, _ := x.l.BuatPesanan(ctx, rani, map[string]int{x.sarapan.ID: 1}, "qris", "kunci-gerbang-1"); ulang.Tagihan["idTagihan"] != lama || len(g.ditagih) != 1 {
		t.Fatalf("tagihan dobel: %v %d", ulang.Tagihan, len(g.ditagih))
	}

	// belum bayar: "Saya sudah bayar" ga bikin lunas
	if q, err := x.l.CekBayar(ctx, rani, p.ID); kodeGalat(err) != http.StatusConflict || q.Status != MenungguBayar {
		t.Fatalf("cek bayar sebelum bayar: %v %s", err, q.Status)
	}
	// webhook palsu ditolak
	if err := x.l.TerimaNotifikasi(ctx, NotifikasiBayar{IDTagihan: lama, TandaTangan: "palsu"}); kodeGalat(err) != http.StatusUnauthorized {
		t.Fatalf("webhook palsu: %v", err)
	}

	// ganti metode: tagihan lama dibatalin, dapet tagihan baru
	p, err = x.l.GantiMetode(ctx, rani, p.ID, "va_bca")
	if err != nil {
		t.Fatal(err)
	}
	baru := p.Tagihan["idTagihan"]
	if baru == "" || baru == lama || len(g.dibatal) != 1 || g.dibatal[0] != lama {
		t.Fatalf("ganti metode: %v dibatal %v", p.Tagihan, g.dibatal)
	}
	// tagihan lama kedaluwarsa: pesanan tetap nunggu
	g.atur(lama, StatusBayar{Status: BayarGagal})
	if err := webhook(lama); err != nil {
		t.Fatal(err)
	}
	// nominal ga cocok: ga dianggap lunas
	g.atur(baru, StatusBayar{Status: BayarLunas, Total: p.Total - 1})
	if err := webhook(baru); err != nil {
		t.Fatal(err)
	}
	if q, _ := x.l.Satu(ctx, rani, p.ID); q.Status != MenungguBayar {
		t.Fatalf("harus masih nunggu: %s", q.Status)
	}

	// dibayar: webhook bikin lunas, webhook dobel ga ngubah kode
	g.atur(baru, StatusBayar{Status: BayarLunas, Total: p.Total})
	if err := webhook(baru); err != nil {
		t.Fatal(err)
	}
	q, _ := x.l.Satu(ctx, rani, p.ID)
	if q.Status != Disiapkan || q.Kode == nil {
		t.Fatalf("abis webhook harus lunas: %s", q.Status)
	}
	kode := *q.Kode
	if err := webhook(baru); err != nil {
		t.Fatal(err)
	}
	if q, _ := x.l.CekBayar(ctx, rani, p.ID); q.Kode == nil || *q.Kode != kode {
		t.Fatal("webhook dobel ngubah kode ambil")
	}

	// pesanan lain kedaluwarsa di Midtrans: batal, porsinya balik
	sisa := func() int {
		for _, pk := range mustDaftar(t, x.l, ctx) {
			if pk.ID == x.kue.ID {
				return pk.SisaPorsi
			}
		}
		return -1
	}
	awal := sisa()
	p2, _, err := x.l.BuatPesanan(ctx, rani, map[string]int{x.kue.ID: 2}, "gopay", "kunci-gerbang-2")
	if err != nil {
		t.Fatal(err)
	}
	g.atur(p2.Tagihan["idTagihan"], StatusBayar{Status: BayarGagal})
	if err := webhook(p2.Tagihan["idTagihan"]); err != nil {
		t.Fatal(err)
	}
	if q, _ := x.l.Satu(ctx, rani, p2.ID); q.Status != Dibatalkan || sisa() != awal {
		t.Fatalf("kedaluwarsa: %s, sisa %d dari %d", q.Status, sisa(), awal)
	}

	// Midtrans gangguan: 502, tapi pesanannya ada dan dicoba lagi pas request diulang
	g.rusak = true
	if _, _, err := x.l.BuatPesanan(ctx, dimas, map[string]int{x.kue.ID: 1}, "qris", "kunci-gerbang-3"); kodeGalat(err) != http.StatusBadGateway {
		t.Fatalf("midtrans mati: %v", err)
	}
	g.rusak = false
	p3, _, err := x.l.BuatPesanan(ctx, dimas, map[string]int{x.kue.ID: 1}, "qris", "kunci-gerbang-3")
	if err != nil || p3.Tagihan["idTagihan"] == "" {
		t.Fatalf("diulang abis midtrans pulih: %v %v", err, p3.Tagihan)
	}

	// webhook buat tagihan yang bukan dari aplikasi ini: diterima, ga ngapa-ngapain
	if err := webhook("pesanan-toko-lain"); err != nil {
		t.Fatal(err)
	}
}

func mustDaftar(t *testing.T, l *Layanan, ctx context.Context) []Paket {
	t.Helper()
	d, err := l.DaftarPaket(ctx, rani)
	if err != nil {
		t.Fatal(err)
	}
	return d
}

func TestWebhookHTTP(t *testing.T) {
	x := siapkanMemori(t)
	mux := http.NewServeMux()
	lewat := func(h http.Handler) http.Handler { return h }
	Pasang(mux, x.l, lewat, lewat)
	kirim := func(isi string) int {
		req := httptest.NewRequest(http.MethodPost, "/v1/pembayaran/midtrans", strings.NewReader(isi))
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)
		return rec.Code
	}
	// field lain dari Midtrans (transaction_time, dll) tetap diterima
	isi := `{"order_id":"x","status_code":"200","gross_amount":"1.00","signature_key":"sah","transaction_time":"2026-10-21 16:30:00","payment_type":"qris"}`
	if kode := kirim(isi); kode != http.StatusNotFound {
		t.Errorf("mode uji (tanpa Midtrans) harus 404, dapet %d", kode)
	}
	x.l.Gerbang = &gerbangPalsu{status: map[string]StatusBayar{}}
	if kode := kirim(isi); kode != http.StatusOK {
		t.Errorf("webhook sah: %d", kode)
	}
	if kode := kirim(strings.Replace(isi, `"sah"`, `"palsu"`, 1)); kode != http.StatusUnauthorized {
		t.Errorf("webhook palsu: %d", kode)
	}
	if kode := kirim(`bukan json`); kode != http.StatusBadRequest {
		t.Errorf("isi rusak: %d", kode)
	}
}
