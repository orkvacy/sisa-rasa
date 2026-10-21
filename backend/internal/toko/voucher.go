package toko

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/orkvacy/sisa-rasa/backend/internal/akun"
)

// Voucher potongan dari platform. dibuat admin, potongannya ditanggung platform
// (diambil dari biaya layanan + komisi), jadi penerimaan mitra tetap dihitung
// dari harga paket (subtotal)
type Voucher struct {
	ID    string `json:"id"`
	Kode  string `json:"kode"`
	Judul string `json:"judul"`
	// Persen potongan dari subtotal, paling banyak MaksPotongan rupiah
	Persen       int       `json:"persen"`
	MaksPotongan int       `json:"maksPotongan"`
	MinBelanja   int       `json:"minBelanja"`
	Mulai        time.Time `json:"mulai"`
	Berakhir     time.Time `json:"berakhir"`
	// Kuota nil = ga dibatasi
	Kuota    *int `json:"kuota"`
	Terpakai int  `json:"terpakai"`
	// KhususBaru cuma buat pembeli yang belum pernah punya pesanan (selain yang batal)
	KhususBaru bool `json:"khususBaru"`
	// Publik tampil di daftar voucher aplikasi. false = kode rahasia (promo Instagram, brosur)
	Publik bool      `json:"publik"`
	Aktif  bool      `json:"aktif"`
	Dibuat time.Time `json:"dibuat"`
}

// StoreVoucher bagian Store buat voucher
type StoreVoucher interface {
	// BuatVoucher ErrBentrok kalau kodenya udah dipakai
	BuatVoucher(ctx context.Context, v Voucher) (Voucher, error)
	SemuaVoucher(ctx context.Context) ([]Voucher, error)
	AturVoucherAktif(ctx context.Context, id string, aktif bool) (Voucher, error)
	VoucherDariKode(ctx context.Context, kode string) (Voucher, error)
	// PernahPesan pembeli punya pesanan yang ga batal (buat voucher khusus pengguna baru)
	PernahPesan(ctx context.Context, idPembeli string) (bool, error)
}

var (
	polaKodeVoucher = regexp.MustCompile(`^[A-Z0-9]{4,20}$`)
	errVoucherHabis = galat(http.StatusConflict, "Kuota voucher sudah habis.")
)

// potonganVoucher persen dari subtotal, dibulatkan, paling banyak MaksPotongan
func potonganVoucher(v Voucher, subtotal int) int {
	return min(v.MaksPotongan, (subtotal*v.Persen+50)/100)
}

// RapikanKode kode voucher ga peduli huruf besar kecil dan spasi
func RapikanKode(kode string) string {
	return strings.ToUpper(strings.ReplaceAll(strings.TrimSpace(kode), " ", ""))
}

// cekVoucher syarat yang ga bergantung isi keranjang: ada, aktif, masa berlaku,
// kuota, dan khusus pengguna baru. minimal belanja dicek pas subtotalnya udah pasti
func (l *Layanan) cekVoucher(ctx context.Context, a akun.Akun, kode string) (Voucher, error) {
	v, err := l.Store.VoucherDariKode(ctx, RapikanKode(kode))
	if errors.Is(err, ErrTidakAda) || (err == nil && !v.Aktif) {
		return Voucher{}, galat(http.StatusNotFound, "Kode voucher tidak ditemukan.")
	}
	if err != nil {
		return Voucher{}, err
	}
	now := l.sekarang()
	switch {
	case now.Before(v.Mulai):
		return Voucher{}, galat(http.StatusConflict, "Voucher ini belum bisa dipakai.")
	case !now.Before(v.Berakhir):
		return Voucher{}, galat(http.StatusConflict, "Voucher ini sudah berakhir.")
	case v.Kuota != nil && v.Terpakai >= *v.Kuota:
		return Voucher{}, errVoucherHabis
	}
	if v.KhususBaru {
		pernah, err := l.Store.PernahPesan(ctx, a.ID)
		if err != nil {
			return Voucher{}, err
		}
		if pernah {
			return Voucher{}, galat(http.StatusConflict, "Voucher ini khusus pesanan pertama.")
		}
	}
	return v, nil
}

func cekMinBelanja(v Voucher, subtotal int) error {
	if subtotal < v.MinBelanja {
		return galat(http.StatusUnprocessableEntity,
			fmt.Sprintf("Voucher %s butuh belanja minimal %s.", v.Kode, rupiahTeks(v.MinBelanja)))
	}
	return nil
}

// rupiahTeks 25000 -> "Rp25.000", sama kayak format rupiah di aplikasi
func rupiahTeks(n int) string {
	s := fmt.Sprint(n)
	var b strings.Builder
	for i, c := range s {
		if i > 0 && (len(s)-i)%3 == 0 {
			b.WriteByte('.')
		}
		b.WriteRune(c)
	}
	return "Rp" + b.String()
}

// HasilCekVoucher jawaban "Pakai" di checkout: potongan buat subtotal keranjang
type HasilCekVoucher struct {
	Voucher  Voucher `json:"voucher"`
	Potongan int     `json:"potongan"`
}

// CekVoucher pembeli ngetik / milih voucher di checkout, sebelum bayar
func (l *Layanan) CekVoucher(ctx context.Context, a akun.Akun, kode string, subtotal int) (HasilCekVoucher, error) {
	if a.Peran != "pembeli" {
		return HasilCekVoucher{}, errBukanPembeli
	}
	v, err := l.cekVoucher(ctx, a, kode)
	if err != nil {
		return HasilCekVoucher{}, err
	}
	if err := cekMinBelanja(v, subtotal); err != nil {
		return HasilCekVoucher{}, err
	}
	return HasilCekVoucher{Voucher: v, Potongan: potonganVoucher(v, subtotal)}, nil
}

// VoucherTersedia daftar voucher publik yang bisa dipakai pembeli ini sekarang
func (l *Layanan) VoucherTersedia(ctx context.Context, a akun.Akun) ([]Voucher, error) {
	if a.Peran != "pembeli" {
		return nil, errBukanPembeli
	}
	semua, err := l.Store.SemuaVoucher(ctx)
	if err != nil {
		return nil, err
	}
	pernah, err := l.Store.PernahPesan(ctx, a.ID)
	if err != nil {
		return nil, err
	}
	now := l.sekarang()
	hasil := []Voucher{}
	for _, v := range semua {
		bisa := v.Aktif && v.Publik && !now.Before(v.Mulai) && now.Before(v.Berakhir) &&
			(v.Kuota == nil || v.Terpakai < *v.Kuota) && !(v.KhususBaru && pernah)
		if bisa {
			hasil = append(hasil, v)
		}
	}
	return hasil, nil
}

// IsianVoucher form buat voucher di halaman admin
type IsianVoucher struct {
	Kode         string    `json:"kode"`
	Judul        string    `json:"judul"`
	Persen       int       `json:"persen"`
	MaksPotongan int       `json:"maksPotongan"`
	MinBelanja   int       `json:"minBelanja"`
	Mulai        time.Time `json:"mulai"`
	Berakhir     time.Time `json:"berakhir"`
	Kuota        *int      `json:"kuota"`
	KhususBaru   bool      `json:"khususBaru"`
	Publik       bool      `json:"publik"`
}

// BuatVoucher admin bikin voucher baru
func (l *Layanan) BuatVoucher(ctx context.Context, a akun.Akun, isi IsianVoucher) (Voucher, error) {
	if a.Peran != "admin" {
		return Voucher{}, errBukanAdmin
	}
	isi.Kode = RapikanKode(isi.Kode)
	isi.Judul = strings.Join(strings.Fields(isi.Judul), " ")
	salah := func(pesan string) (Voucher, error) {
		return Voucher{}, galat(http.StatusUnprocessableEntity, pesan)
	}
	switch {
	case !polaKodeVoucher.MatchString(isi.Kode):
		return salah("Kode 4–20 huruf atau angka, tanpa spasi.")
	case len([]rune(isi.Judul)) < 3 || len([]rune(isi.Judul)) > 60:
		return salah("Judul 3–60 karakter.")
	case isi.Persen < 1 || isi.Persen > 100:
		return salah("Potongan 1–100 persen.")
	case isi.MaksPotongan < 1000:
		return salah("Maksimal potongan minimal Rp1.000.")
	case isi.MinBelanja < 0:
		return salah("Minimal belanja tidak boleh minus.")
	case isi.Mulai.IsZero() || !isi.Berakhir.After(isi.Mulai):
		return salah("Tanggal berakhir harus setelah tanggal mulai.")
	case isi.Kuota != nil && *isi.Kuota < 1:
		return salah("Kuota minimal 1, atau kosongkan kalau tidak dibatasi.")
	}
	v, err := l.Store.BuatVoucher(ctx, Voucher{
		Kode: isi.Kode, Judul: isi.Judul, Persen: isi.Persen, MaksPotongan: isi.MaksPotongan,
		MinBelanja: isi.MinBelanja, Mulai: isi.Mulai, Berakhir: isi.Berakhir, Kuota: isi.Kuota,
		KhususBaru: isi.KhususBaru, Publik: isi.Publik, Aktif: true, Dibuat: l.sekarang(),
	})
	if errors.Is(err, ErrBentrok) {
		return Voucher{}, galat(http.StatusConflict, "Kode "+isi.Kode+" sudah dipakai voucher lain.")
	}
	return v, err
}

// DaftarVoucher semua voucher buat halaman admin, yang terbaru di atas
func (l *Layanan) DaftarVoucher(ctx context.Context, a akun.Akun) ([]Voucher, error) {
	if a.Peran != "admin" {
		return nil, errBukanAdmin
	}
	return l.Store.SemuaVoucher(ctx)
}

// AturVoucherAktif admin matiin / nyalain voucher
func (l *Layanan) AturVoucherAktif(ctx context.Context, a akun.Akun, id string, aktif bool) (Voucher, error) {
	if a.Peran != "admin" {
		return Voucher{}, errBukanAdmin
	}
	if !idSah(id) {
		return Voucher{}, errTidakAda
	}
	return tanganiTidakAda(l.Store.AturVoucherAktif(ctx, id, aktif))
}
