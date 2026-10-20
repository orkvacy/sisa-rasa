package toko

import (
	"context"
	"log/slog"
	"net/http"
	"regexp"
	"slices"
	"strings"
	"time"

	"github.com/orkvacy/sisa-rasa/backend/internal/akun"
)

// komisi platform dalam persen, dipotong dari bagian mitra (F-48).
// sama kayak persenKomisi di aplikasi
const persenKomisi = 10

var bankPencairan = []string{"BCA", "Mandiri", "BRI", "BNI", "BSI", "CIMB Niaga"}

var polaNomorRekening = regexp.MustCompile(`^[0-9]{6,20}$`)

// Rekening tujuan pencairan
type Rekening struct {
	Bank  string `json:"bank"`
	Nomor string `json:"nomor"`
	Nama  string `json:"nama"`
}

// Pencairan satu kali transfer saldo ke rekening mitra
type Pencairan struct {
	ID     string    `json:"id"`
	Jumlah int       `json:"jumlah"`
	Bank   string    `json:"bank"`
	Nomor  string    `json:"nomor"`
	Nama   string    `json:"nama"`
	Status string    `json:"status"`
	Waktu  time.Time `json:"waktu"`
	kunci  string
}

// StoreSaldo bagian Store buat saldo mitra
type StoreSaldo interface {
	Rekening(ctx context.Context, idMitra string) (*Rekening, error)
	SimpanRekening(ctx context.Context, idMitra string, r Rekening, sekarang time.Time) error
	DaftarPencairan(ctx context.Context, idMitra string) ([]Pencairan, error)
	// Pendapatan subtotal tiap pesanan mitra yang selesai / tidak diambil
	Pendapatan(ctx context.Context, idMitra string) ([]int, error)
	// MitraBerekening id semua mitra yang udah ngisi rekening
	MitraBerekening(ctx context.Context) ([]string, error)
	// Cairkan ngunci saldo satu mitra, manggil [hitung] dengan data terbaru,
	// lalu nyimpen pencairan hasilnya (kalau ada) dalam satu transaksi.
	// kalau kuncinya udah pernah dipakai, ga ngapa-ngapain
	Cairkan(ctx context.Context, idMitra, kunci string,
		hitung func(pendapatan []int, lama []Pencairan, r *Rekening) *Pencairan) (*Pencairan, error)
}

func komisiDari(jual int) int { return (jual*persenKomisi + 50) / 100 }

// saldoTersedia semua penerimaan bersih dikurangi pencairan yang belum gagal
func saldoTersedia(pendapatan []int, cair []Pencairan) int {
	saldo := 0
	for _, jual := range pendapatan {
		saldo += jual - komisiDari(jual)
	}
	for _, c := range cair {
		if c.Status != "Gagal" {
			saldo -= c.Jumlah
		}
	}
	return saldo
}

// namaCocok F-49: nama pemilik rekening harus sama dengan nama usaha
func namaCocok(nama, usaha string) bool {
	rapi := func(s string) string { return strings.ToUpper(strings.Join(strings.Fields(s), " ")) }
	return rapi(nama) != "" && rapi(nama) == rapi(usaha)
}

// Saldo isi halaman saldo mitra
type Saldo struct {
	Rekening *Rekening   `json:"rekening"`
	Tersedia int         `json:"tersedia"`
	Riwayat  []Pencairan `json:"riwayat"`
}

func (l *Layanan) SaldoSaya(ctx context.Context, a akun.Akun) (Saldo, error) {
	if a.Peran != "mitra" {
		return Saldo{}, errBukanMitra
	}
	rek, err := l.Store.Rekening(ctx, a.ID)
	if err != nil {
		return Saldo{}, err
	}
	cair, err := l.Store.DaftarPencairan(ctx, a.ID)
	if err != nil {
		return Saldo{}, err
	}
	pendapatan, err := l.Store.Pendapatan(ctx, a.ID)
	if err != nil {
		return Saldo{}, err
	}
	return Saldo{Rekening: rek, Tersedia: saldoTersedia(pendapatan, cair), Riwayat: cair}, nil
}

// SimpanRekening F-49
func (l *Layanan) SimpanRekening(ctx context.Context, a akun.Akun, r Rekening) (Rekening, error) {
	if a.Peran != "mitra" {
		return Rekening{}, errBukanMitra
	}
	r.Nomor = strings.ReplaceAll(strings.TrimSpace(r.Nomor), " ", "")
	r.Nama = strings.ToUpper(strings.Join(strings.Fields(r.Nama), " "))
	switch {
	case !slices.Contains(bankPencairan, r.Bank):
		return Rekening{}, galat(http.StatusUnprocessableEntity, "Pilih bank.")
	case !polaNomorRekening.MatchString(r.Nomor):
		return Rekening{}, galat(http.StatusUnprocessableEntity, "Nomor rekening harus 6 sampai 20 angka.")
	case !namaCocok(r.Nama, a.Nama):
		return Rekening{}, galat(http.StatusUnprocessableEntity,
			"Nama tidak cocok. Nama pemilik rekening harus sama dengan nama usaha: "+a.Nama+".")
	}
	return r, l.Store.SimpanRekening(ctx, a.ID, r, l.sekarang())
}

// CairkanHarian NF-11: saldo semua mitra dicairkan ke rekeningnya tiap hari 09.00 WITA.
// kuncinya per tanggal, jadi aman dipanggil berkali-kali di hari yang sama
func (l *Layanan) CairkanHarian(ctx context.Context) {
	sekarang := l.sekarang()
	kunci := "harian-" + sekarang.In(wita).Format("2006-01-02")
	id, err := l.Store.MitraBerekening(ctx)
	if err != nil {
		slog.Error("pencairan harian", "galat", err)
		return
	}
	for _, satu := range id {
		_, err := l.Store.Cairkan(ctx, satu, kunci, func(pendapatan []int, lama []Pencairan, r *Rekening) *Pencairan {
			jumlah := saldoTersedia(pendapatan, lama)
			if r == nil || jumlah <= 0 {
				return nil
			}
			status := "Diproses"
			if l.PencairanUji {
				// belum ada transfer bank beneran: di server demo langsung dianggap berhasil
				status = "Berhasil"
			}
			return &Pencairan{Jumlah: jumlah, Bank: r.Bank, Nomor: r.Nomor, Nama: r.Nama,
				Status: status, Waktu: sekarang, kunci: kunci}
		})
		if err != nil {
			slog.Error("pencairan harian", "mitra", satu, "galat", err)
		}
	}
}

// JadwalCairkan jalan terus di belakang: tiap menit ngecek, kalau lagi di jendela
// 09.00-11.59 WITA pencairan hari itu dijalanin. sekali per hari berkat kunci per tanggal;
// jendelanya 3 jam biar tetap jalan walau server sempat mati pas jam 9.
// saldo yang masuk setelah jendela ditutup ikut pencairan besok pagi
func (l *Layanan) JadwalCairkan(ctx context.Context) {
	detak := time.NewTicker(time.Minute)
	defer detak.Stop()
	for {
		t := l.sekarang().In(wita)
		if t.Hour() >= 9 && t.Hour() < 12 {
			l.CairkanHarian(ctx)
		}
		select {
		case <-ctx.Done():
			return
		case <-detak.C:
		}
	}
}
