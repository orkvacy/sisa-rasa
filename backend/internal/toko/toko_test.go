package toko

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/orkvacy/sisa-rasa/backend/internal/akun"
	"github.com/orkvacy/sisa-rasa/backend/internal/httpx"
)

var (
	rani  = akun.Akun{ID: "11111111-1111-4111-8111-111111111111", Nama: "Rani Amelia", Peran: "pembeli"}
	dimas = akun.Akun{ID: "22222222-2222-4222-8222-222222222222", Nama: "Dimas Pratama", Peran: "pembeli"}
	ibis  = akun.Akun{ID: "33333333-3333-4333-8333-333333333333", Nama: "Ibis Hotel", Peran: "mitra"}
	prime = akun.Akun{ID: "44444444-4444-4444-8444-444444444444", Nama: "Prime Cut", Peran: "mitra"}
)

// jamTes jam palsu yang bisa dimajuin
type jamTes struct{ t time.Time }

func (j *jamTes) sekarang() time.Time  { return j.t }
func (j *jamTes) maju(d time.Duration) { j.t = j.t.Add(d) }

type siap struct {
	l       *Layanan
	s       Store
	jam     *jamTes
	sarapan Paket // Ibis, 3 dari 8 porsi, 85rb -> 34rb, tutup 17.00
	kue     Paket // Ibis, 6 porsi, 95rb -> 38rb
	steak   Paket // Prime Cut
}

// pembeli tes "pesan barengan", di Postgres dibikinin baris akunnya juga
func pembeliBarengan() []akun.Akun {
	var hasil []akun.Akun
	for i := range 10 {
		hasil = append(hasil, akun.Akun{ID: fmt.Sprintf("55555555-5555-4555-8555-%012d", i), Nama: "Pembeli", Peran: "pembeli"})
	}
	return hasil
}

func siapkanMemori(t *testing.T) siap {
	s := memoriBaru()
	s.tambahMitra(ibis.ID, ibis.Nama)
	s.tambahMitra(prime.ID, prime.Nama)
	return siapkanDengan(t, s)
}

// siapkanDengan isi [s] dengan paket contoh. akun mitranya harus udah ada di [s]
func siapkanDengan(t *testing.T, s Store) siap {
	t.Helper()
	jam := &jamTes{t: time.Date(2026, 10, 20, 16, 20, 0, 0, wita)}
	l := &Layanan{Store: s, Jam: jam.sekarang}
	ctx := context.Background()
	buat := func(a akun.Akun, nama string, asli, diskon, porsi int) Paket {
		p, err := l.BuatPaket(ctx, a, IsianPaket{Nama: nama, Kategori: "Hidangan utama",
			HargaAsli: asli, HargaDiskon: diskon, TotalPorsi: porsi, Mulai: 15 * 60, Tutup: 17 * 60})
		if err != nil {
			t.Fatal(err)
		}
		return p
	}
	sarapan := buat(ibis, "American Breakfast Set", 85000, 34000, 8)
	sarapan, _ = l.AturSisa(ctx, ibis, sarapan.ID, 3)
	return siap{l: l, s: s, jam: jam, sarapan: sarapan,
		kue: buat(ibis, "Petit Four", 95000, 38000, 6), steak: buat(prime, "Sirloin", 245000, 62000, 4)}
}

func (x siap) sisa(t *testing.T, id string) int {
	t.Helper()
	semua, _ := x.l.Store.SemuaPaket(context.Background())
	for _, p := range semua {
		if p.ID == id {
			return p.SisaPorsi
		}
	}
	t.Fatalf("paket %s ga ada", id)
	return 0
}

func kodeGalat(err error) int {
	var g *httpx.Galat
	if errors.As(err, &g) {
		return g.Kode
	}
	return 0
}

func ujiBuatPesananNgitungDanNahanStok(t *testing.T, siapkan func(*testing.T) siap) {
	x := siapkan(t)
	p, dibuat, err := x.l.BuatPesanan(context.Background(), rani,
		map[string]int{x.sarapan.ID: 2, x.kue.ID: 1}, "qris", "kunci-pesanan-1")
	if err != nil || !dibuat {
		t.Fatalf("buat: %v %v", dibuat, err)
	}
	// 2 x 34rb + 38rb = 106rb, biaya layanan 10%
	if p.Subtotal != 106000 || p.BiayaLayanan != 10600 || p.Total != 116600 {
		t.Fatalf("hitungan salah: %+v", p)
	}
	if p.Hemat != 2*85000+95000-106000 || p.Porsi != 3 || p.Status != MenungguBayar || p.Kode != nil {
		t.Fatalf("isi salah: %+v", p)
	}
	if p.NamaPembeli != "Rani A." || p.Mitra != "Ibis Hotel" || !strings.HasPrefix(p.Nomor, "SR-261020") {
		t.Fatalf("nama / nomor salah: %q %q %q", p.NamaPembeli, p.Mitra, p.Nomor)
	}
	// F-40: ditahan 15 menit
	if p.BatasBayar.Sub(x.jam.t) != 15*time.Minute || p.BatasMenit != 16*60+35 {
		t.Fatalf("batas bayar: %v %d", p.BatasBayar, p.BatasMenit)
	}
	if p.Tagihan["isiQr"] == "" || p.Tagihan["nomorVa"] == "" {
		t.Fatalf("tagihan kosong: %v", p.Tagihan)
	}
	if p.Tagihan["qrisAsli"] != "" {
		t.Fatal("tanpa QRIS_STATIS harusnya QR tiruan")
	}
	if x.sisa(t, x.sarapan.ID) != 1 || x.sisa(t, x.kue.ID) != 5 {
		t.Fatal("stok ga berkurang")
	}
	// QRIS statis diisi: pesanan QRIS dapet QR asli dengan total di tag 54
	x.l.QRISStatis = qrisContoh()
	q, _, err := x.l.BuatPesanan(context.Background(), dimas, map[string]int{x.kue.ID: 1}, "qris", "kunci-qris-asli")
	if err != nil || q.Tagihan["qrisAsli"] != "1" || CekQRIS(q.Tagihan["isiQr"]) != nil ||
		!strings.Contains(q.Tagihan["isiQr"], fmt.Sprintf("54%02d%d", len(fmt.Sprint(q.Total)), q.Total)) {
		t.Fatalf("QRIS asli: %v %v", q.Tagihan, err)
	}
}

func ujiIdempotencyPesananGaDobel(t *testing.T, siapkan func(*testing.T) siap) {
	x := siapkan(t)
	ctx := context.Background()
	isi := map[string]int{x.sarapan.ID: 1}
	satu, _, err := x.l.BuatPesanan(ctx, rani, isi, "qris", "kunci-sama-123")
	if err != nil {
		t.Fatal(err)
	}
	// request yang sama dikirim ulang (sinyal putus, tombol kepencet dua kali)
	dua, dibuat, err := x.l.BuatPesanan(ctx, rani, isi, "qris", "kunci-sama-123")
	if err != nil || dibuat || dua.ID != satu.ID {
		t.Fatalf("pesanan dobel: %v %v %v", dibuat, dua.ID, err)
	}
	if x.sisa(t, x.sarapan.ID) != 2 {
		t.Fatal("stok kepotong dua kali")
	}
	// kunci sama tapi isinya beda = kemungkinan bug di aplikasi, ditolak
	_, _, err = x.l.BuatPesanan(ctx, rani, map[string]int{x.sarapan.ID: 2}, "qris", "kunci-sama-123")
	if kodeGalat(err) != http.StatusUnprocessableEntity {
		t.Fatalf("isi beda harus ditolak, dapet %v", err)
	}
	// pembeli lain boleh pakai kunci yang kebetulan sama
	if _, dibuat, err := x.l.BuatPesanan(ctx, dimas, isi, "qris", "kunci-sama-123"); err != nil || !dibuat {
		t.Fatalf("pembeli lain: %v %v", dibuat, err)
	}
	// tanpa kunci ditolak
	if _, _, err := x.l.BuatPesanan(ctx, rani, isi, "qris", ""); kodeGalat(err) != http.StatusBadRequest {
		t.Fatalf("tanpa kunci: %v", err)
	}
}

func ujiStokGaBisaMinusWalauBarengan(t *testing.T, siapkan func(*testing.T) siap) {
	x := siapkan(t)
	// sisa 3 porsi, 10 pembeli pesan 1 porsi barengan: cuma 3 yang dapet
	var wg sync.WaitGroup
	var mu sync.Mutex
	berhasil := 0
	for i := range 10 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			pembeli := pembeliBarengan()[i]
			_, _, err := x.l.BuatPesanan(context.Background(), pembeli,
				map[string]int{x.sarapan.ID: 1}, "qris", "kunci-barengan")
			if err == nil {
				mu.Lock()
				berhasil++
				mu.Unlock()
			} else if kodeGalat(err) != http.StatusConflict {
				t.Errorf("galat lain: %v", err)
			}
		}()
	}
	wg.Wait()
	if berhasil != 3 || x.sisa(t, x.sarapan.ID) != 0 {
		t.Fatalf("berhasil %d, sisa %d", berhasil, x.sisa(t, x.sarapan.ID))
	}
}

func ujiAturanPesanan(t *testing.T, siapkan func(*testing.T) siap) {
	x := siapkan(t)
	ctx := context.Background()
	cek := func(nama string, a akun.Akun, isi map[string]int, metode string, kode int) {
		t.Helper()
		_, _, err := x.l.BuatPesanan(ctx, a, isi, metode, "kunci-"+nama)
		if kodeGalat(err) != kode {
			t.Errorf("%s: mau %d, dapet %v", nama, kode, err)
		}
	}
	cek("dua-mitra", rani, map[string]int{x.sarapan.ID: 1, x.steak.ID: 1}, "qris", http.StatusUnprocessableEntity)
	cek("kelebihan", rani, map[string]int{x.sarapan.ID: 4}, "qris", http.StatusConflict)
	cek("metode-ngawur", rani, map[string]int{x.sarapan.ID: 1}, "utang", http.StatusUnprocessableEntity)
	cek("mitra-pesan", ibis, map[string]int{x.sarapan.ID: 1}, "qris", http.StatusForbidden)
	cek("id-ngawur", rani, map[string]int{"bukan-uuid": 1}, "qris", http.StatusConflict)
	cek("kosong", rani, map[string]int{}, "qris", http.StatusUnprocessableEntity)

	// F-51 gerai tutup, F-45 nonaktif
	_ = x.l.AturGerai(ctx, prime, true)
	cek("gerai-tutup", rani, map[string]int{x.steak.ID: 1}, "qris", http.StatusConflict)
	_, _ = x.l.AturAktif(ctx, ibis, x.kue.ID, false)
	cek("nonaktif", rani, map[string]int{x.kue.ID: 1}, "qris", http.StatusConflict)

	// F-25 jam ambil udah lewat
	x.jam.maju(time.Hour)
	cek("lewat-tutup", rani, map[string]int{x.sarapan.ID: 1}, "qris", http.StatusConflict)
}

func ujiBayarBatalDanBatasBayar(t *testing.T, siapkan func(*testing.T) siap) {
	x := siapkan(t)
	ctx := context.Background()
	p, _, _ := x.l.BuatPesanan(ctx, rani, map[string]int{x.sarapan.ID: 2}, "qris", "kunci-bayar-1")

	// orang lain ga bisa ngecek / batalin pesanan Rani
	if _, err := x.l.CekBayar(ctx, dimas, p.ID); kodeGalat(err) != http.StatusNotFound {
		t.Fatalf("akun lain: %v", err)
	}
	// mitra belum liat pesanan yang belum dibayar
	if daftar, _ := x.l.Daftar(ctx, ibis); len(daftar) != 0 {
		t.Fatal("mitra liat pesanan belum dibayar")
	}

	lunas, err := x.l.CekBayar(ctx, rani, p.ID)
	if err != nil || lunas.Status != Disiapkan || lunas.Kode == nil || !strings.HasPrefix(*lunas.Kode, "SR-") {
		t.Fatalf("cek bayar: %+v %v", lunas, err)
	}
	// dicek ulang: kode ga berubah (aman dipanggil berkali-kali)
	lagi, _ := x.l.CekBayar(ctx, rani, p.ID)
	if *lagi.Kode != *lunas.Kode {
		t.Fatal("kode berubah")
	}
	// F-55 udah lunas ga bisa dibatalin pembeli
	if _, err := x.l.Batal(ctx, rani, p.ID, "", false); kodeGalat(err) != http.StatusConflict {
		t.Fatalf("batal lunas: %v", err)
	}
	if daftar, _ := x.l.Daftar(ctx, ibis); len(daftar) != 1 {
		t.Fatal("mitra harus liat pesanan lunas")
	}

	// pesanan kedua dibatalin pembeli: porsi balik (F-40)
	q, _, _ := x.l.BuatPesanan(ctx, rani, map[string]int{x.kue.ID: 2}, "va_bca", "kunci-bayar-2")
	if x.sisa(t, x.kue.ID) != 4 {
		t.Fatal("stok kue")
	}
	ganti, err := x.l.GantiMetode(ctx, rani, q.ID, "va_bri")
	if err != nil || ganti.Metode != "va_bri" {
		t.Fatalf("ganti metode: %v", err)
	}
	batal, err := x.l.Batal(ctx, rani, q.ID, "Berubah pikiran", false)
	if err != nil || batal.Status != Dibatalkan || x.sisa(t, x.kue.ID) != 6 {
		t.Fatalf("batal: %+v %v sisa %d", batal, err, x.sisa(t, x.kue.ID))
	}
	// batal dua kali: porsi ga balik dua kali
	if _, err := x.l.Batal(ctx, rani, q.ID, "", false); err != nil || x.sisa(t, x.kue.ID) != 6 {
		t.Fatalf("batal ulang: %v sisa %d", err, x.sisa(t, x.kue.ID))
	}

	// pesanan ketiga dibiarkan lewat batas bayar, dibersihin otomatis
	r, _, _ := x.l.BuatPesanan(ctx, dimas, map[string]int{x.kue.ID: 1}, "qris", "kunci-bayar-3")
	x.jam.maju(16 * time.Minute)
	x.l.Bersihkan(ctx)
	habis, _ := x.l.Satu(ctx, dimas, r.ID)
	if habis.Status != Dibatalkan || !habis.Otomatis || x.sisa(t, x.kue.ID) != 6 {
		t.Fatalf("batas bayar: %+v sisa %d", habis, x.sisa(t, x.kue.ID))
	}
}

func ujiAlurMitra(t *testing.T, siapkan func(*testing.T) siap) {
	x := siapkan(t)
	ctx := context.Background()
	p, _, _ := x.l.BuatPesanan(ctx, rani, map[string]int{x.sarapan.ID: 1}, "qris", "kunci-mitra-1")
	p, _ = x.l.CekBayar(ctx, rani, p.ID)

	// mitra lain ga bisa nyentuh
	if _, err := x.l.UbahStatus(ctx, prime, p.ID, SiapDiambil); kodeGalat(err) != http.StatusNotFound {
		t.Fatalf("mitra lain: %v", err)
	}
	// pembeli ga bisa ubah status sendiri
	if _, err := x.l.UbahStatus(ctx, rani, p.ID, Selesai); kodeGalat(err) != http.StatusNotFound {
		t.Fatalf("pembeli ubah status: %v", err)
	}
	siapAmbil, err := x.l.UbahStatus(ctx, ibis, p.ID, SiapDiambil)
	if err != nil || siapAmbil.Status != SiapDiambil {
		t.Fatalf("siap diambil: %v", err)
	}
	// F-46 scan kode, huruf kecil + tanpa awalan tetap ketemu
	selesai, err := x.l.AmbilDenganKode(ctx, ibis, strings.ToLower(strings.TrimPrefix(*p.Kode, "SR-")))
	if err != nil || selesai.Status != Selesai || selesai.DiambilPada == nil {
		t.Fatalf("ambil: %+v %v", selesai, err)
	}
	if _, err := x.l.AmbilDenganKode(ctx, ibis, *p.Kode); kodeGalat(err) != http.StatusConflict {
		t.Fatalf("kode dipakai dua kali: %v", err)
	}

	// F-42 mitra batalin pesanan lunas: porsinya ga dibalikin
	q, _, _ := x.l.BuatPesanan(ctx, dimas, map[string]int{x.sarapan.ID: 1}, "qris", "kunci-mitra-2")
	_, _ = x.l.CekBayar(ctx, dimas, q.ID)
	if _, err := x.l.BatalMitra(ctx, ibis, q.ID, ""); kodeGalat(err) != http.StatusUnprocessableEntity {
		t.Fatalf("batal tanpa alasan: %v", err)
	}
	batal, err := x.l.BatalMitra(ctx, ibis, q.ID, "Paket habis")
	if err != nil || !batal.OlehMitra || batal.Status != Dibatalkan || x.sisa(t, x.sarapan.ID) != 1 {
		t.Fatalf("batal mitra: %+v %v sisa %d", batal, err, x.sisa(t, x.sarapan.ID))
	}
}

func ujiKelolaPaket(t *testing.T, siapkan func(*testing.T) siap) {
	x := siapkan(t)
	ctx := context.Background()
	isi := IsianPaket{Nama: "Nasi Kuning", Kategori: "Hidangan utama", HargaAsli: 30000,
		HargaDiskon: 30000, TotalPorsi: 3, Mulai: 16 * 60, Tutup: 18 * 60}
	// F-16
	if _, err := x.l.BuatPaket(ctx, ibis, isi); kodeGalat(err) != http.StatusUnprocessableEntity {
		t.Fatalf("diskon = asli: %v", err)
	}
	if _, err := x.l.BuatPaket(ctx, rani, isi); kodeGalat(err) != http.StatusForbidden {
		t.Fatalf("pembeli bikin paket: %v", err)
	}
	isi.HargaDiskon = 12000
	p, err := x.l.BuatPaket(ctx, ibis, isi)
	if err != nil || p.SisaPorsi != 3 || p.Foto == "" {
		t.Fatalf("buat: %+v %v", p, err)
	}
	// F-18 total porsi 3 -> 5, sisa ikut naik 2
	_, _ = x.l.AturSisa(ctx, ibis, p.ID, 1)
	isi.TotalPorsi = 5
	p, _ = x.l.UbahPaket(ctx, ibis, p.ID, isi)
	if p.SisaPorsi != 3 {
		t.Fatalf("sisa setelah ubah: %d", p.SisaPorsi)
	}
	// mitra lain ga bisa ngubah / hapus
	if _, err := x.l.UbahPaket(ctx, prime, p.ID, isi); kodeGalat(err) != http.StatusNotFound {
		t.Fatalf("mitra lain ubah: %v", err)
	}
	if err := x.l.HapusPaket(ctx, ibis, p.ID); err != nil {
		t.Fatal(err)
	}
	if daftar, _ := x.l.PaketSaya(ctx, ibis); len(daftar) != 2 {
		t.Fatalf("paket Ibis setelah hapus: %d", len(daftar))
	}
}

func ujiHTTPPesanan(t *testing.T, siapkan func(*testing.T) siap) {
	x := siapkan(t)
	mux := http.NewServeMux()
	// pengganti akun.Layanan.Wajib: akun dari header X-Tes
	akunTes := map[string]akun.Akun{"rani": rani, "ibis": ibis}
	Pasang(mux, x.l, func(h http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			a, ada := akunTes[r.Header.Get("X-Tes")]
			if !ada {
				httpx.TulisGalat(w, r, httpx.NewGalat(http.StatusUnauthorized, "Sesi berakhir."))
				return
			}
			h.ServeHTTP(w, r.WithContext(akun.KeKonteks(r.Context(), a)))
		})
	})
	panggil := func(metode, jalur, siapa, kunci, isi string) (int, map[string]json.RawMessage) {
		r := httptest.NewRequest(metode, jalur, strings.NewReader(isi))
		r.Header.Set("X-Tes", siapa)
		if kunci != "" {
			r.Header.Set("Idempotency-Key", kunci)
		}
		w := httptest.NewRecorder()
		mux.ServeHTTP(w, r)
		var hasil map[string]json.RawMessage
		_ = json.Unmarshal(w.Body.Bytes(), &hasil)
		return w.Code, hasil
	}

	// daftar paket boleh tanpa masuk
	if kode, hasil := panggil("GET", "/v1/paket", "", "", ""); kode != 200 || len(hasil["paket"]) < 10 {
		t.Fatalf("daftar paket: %d", kode)
	}
	isi := `{"isi":{"` + x.sarapan.ID + `":1},"metode":"qris"}`
	if kode, _ := panggil("POST", "/v1/pesanan", "", "kunci-http-1", isi); kode != 401 {
		t.Fatalf("tanpa sesi: %d", kode)
	}
	if kode, _ := panggil("POST", "/v1/pesanan", "rani", "", isi); kode != 400 {
		t.Fatalf("tanpa Idempotency-Key: %d", kode)
	}
	kode, hasil := panggil("POST", "/v1/pesanan", "rani", "kunci-http-1", isi)
	if kode != 201 {
		t.Fatalf("buat: %d", kode)
	}
	var p map[string]any
	_ = json.Unmarshal(hasil["pesanan"], &p)
	if p["status"] != MenungguBayar || p["porsiPaket"] == nil || p["tagihan"] == nil {
		t.Fatalf("isi JSON: %v", p)
	}
	if kode, _ := panggil("POST", "/v1/pesanan", "rani", "kunci-http-1", isi); kode != 200 {
		t.Fatalf("kirim ulang harus 200: %d", kode)
	}
	id := p["id"].(string)
	if kode, _ := panggil("POST", "/v1/pesanan/"+id+"/cek-bayar", "rani", "", ""); kode != 200 {
		t.Fatalf("cek bayar: %d", kode)
	}
	if kode, _ := panggil("POST", "/v1/pesanan/"+id+"/status", "ibis", "", `{"status":"siap_diambil"}`); kode != 200 {
		t.Fatalf("status: %d", kode)
	}
	if kode, _ := panggil("GET", "/v1/pesanan/bukan-id", "rani", "", ""); kode != 404 {
		t.Fatalf("id ngawur: %d", kode)
	}
	if kode, _ := panggil("GET", "/v1/pesanan", "ibis", "", ""); kode != 200 {
		t.Fatalf("daftar mitra: %d", kode)
	}
}

// skenario dijalanin di memori (selalu) dan di Postgres asli (store_pg_test.go)
var skenario = map[string]func(*testing.T, func(*testing.T) siap){
	"Chat":                           ujiChat,
	"BuatPesananNgitungDanNahanStok": ujiBuatPesananNgitungDanNahanStok,
	"IdempotencyPesananGaDobel":      ujiIdempotencyPesananGaDobel,
	"StokGaBisaMinusWalauBarengan":   ujiStokGaBisaMinusWalauBarengan,
	"AturanPesanan":                  ujiAturanPesanan,
	"BayarBatalDanBatasBayar":        ujiBayarBatalDanBatasBayar,
	"AlurMitra":                      ujiAlurMitra,
	"KelolaPaket":                    ujiKelolaPaket,
	"HTTPPesanan":                    ujiHTTPPesanan,
}

func TestSkenarioMemori(t *testing.T) {
	for nama, uji := range skenario {
		t.Run(nama, func(t *testing.T) { uji(t, siapkanMemori) })
	}
}

func ujiChat(t *testing.T, siapkan func(*testing.T) siap) {
	x := siapkan(t)
	ctx := context.Background()
	p, _, _ := x.l.BuatPesanan(ctx, rani, map[string]int{x.sarapan.ID: 1}, "qris", "kunci-chat-1")

	// belum dibayar: percakapan belum ada
	if _, err := x.l.KirimChat(ctx, rani, p.ID, "pesan-0001", "Halo"); kodeGalat(err) != http.StatusNotFound {
		t.Fatalf("chat sebelum bayar: %v", err)
	}
	_, _ = x.l.CekBayar(ctx, rani, p.ID)
	mulai := x.jam.t.Add(-time.Second)

	satu, err := x.l.KirimChat(ctx, rani, p.ID, "pesan-0001", "  Saya sudah sampai  ")
	if err != nil || satu.Peran != "pembeli" || satu.Teks != "Saya sudah sampai" {
		t.Fatalf("kirim: %+v %v", satu, err)
	}
	// NF-18 kiriman ulang dengan id sama ga dobel
	if _, err := x.l.KirimChat(ctx, rani, p.ID, "pesan-0001", "Saya sudah sampai"); err != nil {
		t.Fatal(err)
	}
	x.jam.maju(time.Second)
	if _, err := x.l.KirimChat(ctx, ibis, p.ID, "pesan-0002", "Pesanan sudah siap"); err != nil {
		t.Fatal(err)
	}
	riwayat, _ := x.l.RiwayatChat(ctx, rani, p.ID)
	if len(riwayat) != 2 || riwayat[1].Peran != "mitra" {
		t.Fatalf("riwayat: %+v", riwayat)
	}
	// orang lain ga bisa baca / kirim
	if _, err := x.l.RiwayatChat(ctx, dimas, p.ID); kodeGalat(err) != http.StatusNotFound {
		t.Fatalf("akun lain baca: %v", err)
	}
	if _, err := x.l.KirimChat(ctx, prime, p.ID, "pesan-0003", "hai"); kodeGalat(err) != http.StatusNotFound {
		t.Fatalf("mitra lain kirim: %v", err)
	}
	if _, err := x.l.KirimChat(ctx, rani, p.ID, "pesan-0004", "   "); kodeGalat(err) != http.StatusUnprocessableEntity {
		t.Fatalf("pesan kosong: %v", err)
	}

	// F-70 Rani baca: pesan mitra jadi dibaca, pesan Rani sendiri tetap terkirim
	x.jam.maju(time.Second)
	if err := x.l.BacaChat(ctx, rani, p.ID); err != nil {
		t.Fatal(err)
	}
	riwayat, _ = x.l.RiwayatChat(ctx, ibis, p.ID)
	for _, c := range riwayat {
		if (c.Peran == "mitra") != (c.DibacaPada != nil) {
			t.Fatalf("status baca salah: %+v", c)
		}
	}

	// pesan baru: mitra narik semua yang berubah sejak awal, termasuk tanda dibaca
	baru, sekarang, err := x.l.ChatBaru(ctx, ibis, mulai)
	if err != nil || len(baru) != 2 || !sekarang.Equal(x.jam.t) {
		t.Fatalf("chat baru mitra: %d %v", len(baru), err)
	}
	if baru, _, _ := x.l.ChatBaru(ctx, ibis, x.jam.t); len(baru) != 0 {
		t.Fatalf("setelah sekarang harusnya kosong: %d", len(baru))
	}
	if baru, _, _ := x.l.ChatBaru(ctx, dimas, time.Time{}); len(baru) != 0 {
		t.Fatalf("pembeli lain dapet pesan orang: %d", len(baru))
	}

	// selesai + lewat 2 jam: baca saja
	_, _ = x.l.UbahStatus(ctx, ibis, p.ID, Selesai)
	x.jam.maju(2*time.Hour + time.Minute)
	if _, err := x.l.KirimChat(ctx, rani, p.ID, "pesan-0005", "Terima kasih"); kodeGalat(err) != http.StatusConflict {
		t.Fatalf("chat ditutup: %v", err)
	}
	if riwayat, err := x.l.RiwayatChat(ctx, rani, p.ID); err != nil || len(riwayat) != 2 {
		t.Fatalf("riwayat tetap bisa dibaca: %d %v", len(riwayat), err)
	}
}

func ujiSaldo(t *testing.T, siapkan func(*testing.T) siap) {
	x := siapkan(t)
	ctx := context.Background()
	x.l.PencairanUji = true
	selesaikan := func(kunci string) {
		t.Helper()
		p, _, err := x.l.BuatPesanan(ctx, rani, map[string]int{x.kue.ID: 1}, "qris", kunci)
		if err != nil {
			t.Fatal(err)
		}
		p, _ = x.l.CekBayar(ctx, rani, p.ID)
		if _, err := x.l.AmbilDenganKode(ctx, ibis, *p.Kode); err != nil {
			t.Fatal(err)
		}
	}
	tersedia := func() int {
		t.Helper()
		s, err := x.l.SaldoSaya(ctx, ibis)
		if err != nil {
			t.Fatal(err)
		}
		return s.Tersedia
	}

	if _, err := x.l.SaldoSaya(ctx, rani); kodeGalat(err) != http.StatusForbidden {
		t.Fatalf("pembeli liat saldo: %v", err)
	}
	// 38rb - komisi 10% = 34.200
	selesaikan("kunci-saldo-1")
	if tersedia() != 34200 {
		t.Fatalf("saldo: %d", tersedia())
	}

	// belum ada rekening: ga ada yang dicairin
	x.l.CairkanHarian(ctx)
	if tersedia() != 34200 {
		t.Fatal("cair tanpa rekening")
	}
	// F-49 nama harus sama dengan nama usaha
	if _, err := x.l.SimpanRekening(ctx, ibis, Rekening{Bank: "BCA", Nomor: "1234567890", Nama: "Orang Lain"}); kodeGalat(err) != http.StatusUnprocessableEntity {
		t.Fatalf("nama beda: %v", err)
	}
	if _, err := x.l.SimpanRekening(ctx, ibis, Rekening{Bank: "Bank Ngawur", Nomor: "1234567890", Nama: "Ibis Hotel"}); kodeGalat(err) != http.StatusUnprocessableEntity {
		t.Fatalf("bank ngawur: %v", err)
	}
	rek, err := x.l.SimpanRekening(ctx, ibis, Rekening{Bank: "BCA", Nomor: "1234 5678 90", Nama: "  ibis   hotel "})
	if err != nil || rek.Nomor != "1234567890" || rek.Nama != "IBIS HOTEL" {
		t.Fatalf("rekening: %+v %v", rek, err)
	}

	// pencairan harian dijalanin dua kali (server restart): tetap sekali
	x.l.CairkanHarian(ctx)
	x.l.CairkanHarian(ctx)
	s, _ := x.l.SaldoSaya(ctx, ibis)
	if s.Tersedia != 0 || len(s.Riwayat) != 1 || s.Riwayat[0].Jumlah != 34200 || s.Riwayat[0].Status != "Berhasil" {
		t.Fatalf("cair dobel: %+v", s)
	}

	// pesanan baru selesai hari ini: nunggu pencairan besok
	selesaikan("kunci-saldo-2")
	x.l.CairkanHarian(ctx)
	if tersedia() != 34200 {
		t.Fatalf("hari yg sama cair lagi: %d", tersedia())
	}
	x.jam.maju(24 * time.Hour)
	x.l.PencairanUji = false
	x.l.CairkanHarian(ctx)
	s, _ = x.l.SaldoSaya(ctx, ibis)
	// status Diproses tetap ngurangin saldo, biar ga dicairin dua kali
	if s.Tersedia != 0 || len(s.Riwayat) != 2 || s.Riwayat[0].Status != "Diproses" {
		t.Fatalf("cair besok: %+v", s)
	}
}
