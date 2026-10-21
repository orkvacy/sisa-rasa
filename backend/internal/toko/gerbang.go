package toko

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"time"

	"github.com/orkvacy/sisa-rasa/backend/internal/akun"
)

// status pembayaran dari penyedia, udah disederhanain
const (
	BayarMenunggu = "menunggu"
	BayarLunas    = "lunas"
	// kedaluwarsa, dibatalkan, atau ditolak penyedia
	BayarGagal = "gagal"
)

// PermintaanTagihan isi tagihan yang diminta ke penyedia pembayaran
type PermintaanTagihan struct {
	// IDTagihan id pesanan + akhiran acak. tiap ganti metode bayar dapet id baru,
	// soalnya penyedia nolak id yang sama dipakai dua kali
	IDTagihan   string
	Total       int
	Metode      string
	NamaPembeli string
	// BerlakuMenit tagihan kedaluwarsa setelah ini, sedikit lebih awal dari batas bayar
	// pesanan biar ga ada pembayaran yang masuk setelah pesanannya dibatalin
	BerlakuMenit int
}

// StatusBayar jawaban penyedia soal satu tagihan
type StatusBayar struct {
	Status string
	Total  int
}

// NotifikasiBayar isi webhook dari penyedia, cuma bagian yang dipakai
type NotifikasiBayar struct {
	IDTagihan   string
	KodeStatus  string
	Total       string
	TandaTangan string
}

// Gerbang penyedia pembayaran (Midtrans, lihat internal/midtrans).
// nil = mode uji: tagihan tiruan dan "Saya sudah bayar" langsung lunas
type Gerbang interface {
	// Tagih bikin tagihan, balikin isi buat aplikasi (isiQr / nomorVa / tautan)
	Tagih(ctx context.Context, t PermintaanTagihan) (map[string]string, error)
	// Status nanya langsung ke penyedia. ini yang dipercaya, bukan isi webhook
	Status(ctx context.Context, idTagihan string) (StatusBayar, error)
	// Batalkan tagihan lama pas pembeli ganti metode
	Batalkan(ctx context.Context, idTagihan string) error
	// SahNotifikasi ngecek tanda tangan webhook pakai kunci rahasia server
	SahNotifikasi(n NotifikasiBayar) bool
}

var errGerbang = galat(http.StatusBadGateway,
	"Layanan pembayaran sedang gangguan. Coba lagi sebentar.")

// pastikanTagihan pesanan yang belum lunas dan belum punya tagihan dari penyedia
// dibikinin tagihannya. dipanggil abis pesanan dibuat / metodenya diganti, dan
// aman diulang: kalau tagihannya udah ada, ga minta lagi
func (l *Layanan) pastikanTagihan(ctx context.Context, p Pesanan) (Pesanan, error) {
	if l.Gerbang == nil || p.Status != MenungguBayar || p.Tagihan["idTagihan"] != "" {
		return p, nil
	}
	akhiran, err := acak("abcdefghjkmnpqrstuvwxyz23456789", 5)
	if err != nil {
		return p, err
	}
	berlaku := int(p.BatasBayar.Sub(l.sekarang())/time.Minute) - 1
	tagihan, err := l.Gerbang.Tagih(ctx, PermintaanTagihan{
		IDTagihan: p.ID + "-" + akhiran, Total: p.Total, Metode: p.Metode,
		NamaPembeli: p.NamaPembeli, BerlakuMenit: max(1, berlaku),
	})
	if err != nil {
		slog.Error("bikin tagihan gagal", "pesanan", p.ID, "galat", err)
		return p, errGerbang
	}
	var dobel string
	hasil, err := tanganiTidakAda(l.Store.UbahPesanan(ctx, p.ID, func(q *Pesanan) (Perubahan, error) {
		// keduluan request lain yang juga bikin tagihan: pakai punya dia
		if q.Status != MenungguBayar || q.Tagihan["idTagihan"] != "" {
			dobel = tagihan["idTagihan"]
			return Perubahan{}, nil
		}
		q.Tagihan = tagihan
		return Perubahan{}, nil
	}))
	if dobel != "" {
		_ = l.Gerbang.Batalkan(ctx, dobel)
	}
	return hasil, err
}

// lunasi pesanan dibayar: dapet kode ambil, porsinya tetap ditahan
func (l *Layanan) lunasi(p *Pesanan) (Perubahan, error) {
	kode, err := acak("ABCDEFGHJKLMNPQRSTUVWXYZ23456789", 4)
	if err != nil {
		return Perubahan{}, err
	}
	now := l.sekarang()
	menit := l.menitSekarang()
	kode = "SR-" + kode
	p.Status = Disiapkan
	p.Kode = &kode
	p.DibayarPada = &now
	p.Dibayar = &menit
	return Perubahan{}, nil
}

// terapkanStatus jawaban penyedia buat tagihan [idTagihan] diterapin ke pesanan.
// idempoten: webhook yang dikirim ulang / dobel ga ngubah apa-apa lagi
func (l *Layanan) terapkanStatus(ctx context.Context, idPesanan, idTagihan string, st StatusBayar) (Pesanan, error) {
	for range 5 {
		p, err := l.Store.UbahPesanan(ctx, idPesanan, func(p *Pesanan) (Perubahan, error) {
			if p.Status != MenungguBayar {
				return Perubahan{}, nil
			}
			switch st.Status {
			case BayarLunas:
				// nominalnya harus pas sama total pesanan
				if st.Total != p.Total {
					slog.Error("nominal bayar beda", "pesanan", p.ID, "total", p.Total, "dibayar", st.Total)
					return Perubahan{}, nil
				}
				return l.lunasi(p)
			case BayarGagal:
				// tagihan lama (sebelum ganti metode) yang kedaluwarsa ga ngebatalin pesanan
				if p.Tagihan["idTagihan"] != idTagihan {
					return Perubahan{}, nil
				}
				l.batal(p, "Pembayaran kedaluwarsa atau dibatalkan.", true)
				return Perubahan{KembalikanStok: true}, nil
			}
			return Perubahan{}, nil
		})
		if errors.Is(err, ErrBentrok) {
			continue // kode ambil kebetulan kembar
		}
		return p, err
	}
	return Pesanan{}, errors.New("kode ambil bentrok terus")
}

// TerimaNotifikasi webhook dari penyedia (POST /v1/pembayaran/midtrans).
// tanda tangan dicek dulu, terus statusnya ditanya ulang langsung ke penyedia,
// jadi isi webhook palsu ga bisa bikin pesanan lunas (NF-10)
func (l *Layanan) TerimaNotifikasi(ctx context.Context, n NotifikasiBayar) error {
	if l.Gerbang == nil {
		return errTidakAda
	}
	if !l.Gerbang.SahNotifikasi(n) {
		return galat(http.StatusUnauthorized, "Tanda tangan tidak sah.")
	}
	// idTagihan = <uuid pesanan>-<akhiran>
	if len(n.IDTagihan) < 37 || !idSah(n.IDTagihan[:36]) {
		return nil // bukan tagihan dari aplikasi ini, cukup diterima
	}
	st, err := l.Gerbang.Status(ctx, n.IDTagihan)
	if err != nil {
		slog.Error("cek status tagihan gagal", "tagihan", n.IDTagihan, "galat", err)
		return errGerbang // penyedia bakal ngirim ulang webhook-nya
	}
	_, err = l.terapkanStatus(ctx, n.IDTagihan[:36], n.IDTagihan, st)
	if errors.Is(err, ErrTidakAda) {
		return nil
	}
	return err
}

// cekBayarGerbang "Saya sudah bayar" kalau udah pakai penyedia asli:
// statusnya ditanya ke penyedia, ga langsung dianggap lunas
func (l *Layanan) cekBayarGerbang(ctx context.Context, a akun.Akun, id string) (Pesanan, error) {
	p, err := l.Satu(ctx, a, id)
	if err != nil {
		return p, err
	}
	if p.IDAkun != a.ID || a.Peran != "pembeli" {
		return Pesanan{}, errTidakAda
	}
	if p.Status != MenungguBayar {
		return p, nil
	}
	idTagihan := p.Tagihan["idTagihan"]
	if idTagihan == "" {
		// tagihannya dulu gagal dibikin, coba lagi
		return l.pastikanTagihan(ctx, p)
	}
	st, err := l.Gerbang.Status(ctx, idTagihan)
	if err != nil {
		slog.Error("cek status tagihan gagal", "tagihan", idTagihan, "galat", err)
		return p, errGerbang
	}
	p, err = l.terapkanStatus(ctx, p.ID, idTagihan, st)
	if err == nil && p.Status == MenungguBayar {
		return p, galat(http.StatusConflict,
			"Pembayaran belum kami terima. Kalau sudah bayar, tunggu sebentar lalu cek lagi.")
	}
	return p, err
}
