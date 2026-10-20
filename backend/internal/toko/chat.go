package toko

import (
	"context"
	"encoding/json"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/orkvacy/sisa-rasa/backend/internal/akun"
)

// percakapan tetap bisa dibuka sampai 2 jam setelah pesanan berakhir (F-67)
const jamChatSetelahSelesai = 2 * time.Hour

// PesanChat satu pesan di percakapan pesanan
type PesanChat struct {
	ID         string     `json:"id"`
	IDPesanan  string     `json:"idPesanan"`
	Peran      string     `json:"peran"`
	Teks       string     `json:"teks"`
	Waktu      time.Time  `json:"waktu"`
	DibacaPada *time.Time `json:"-"`
	Diubah     time.Time  `json:"-"`
}

// MarshalJSON nambahin status yang dipakai layar: terkirim / dibaca
func (p PesanChat) MarshalJSON() ([]byte, error) {
	type polos PesanChat
	status := "terkirim"
	if p.DibacaPada != nil {
		status = "dibaca"
	}
	return json.Marshal(struct {
		polos
		Status string `json:"status"`
	}{polos(p), status})
}

// StoreChat bagian Store buat percakapan
type StoreChat interface {
	// SimpanPesan nyimpen pesan baru. kalau id-nya udah ada di pesanan itu,
	// pesan lama yang dibalikin (kiriman ulang, NF-18)
	SimpanPesan(ctx context.Context, p PesanChat) (PesanChat, error)
	DaftarPesan(ctx context.Context, idPesanan string) ([]PesanChat, error)
	// TandaiDibaca semua pesan dari lawan bicara [oleh] yang belum dibaca
	TandaiDibaca(ctx context.Context, idPesanan, oleh string, sekarang time.Time) error
	// PesanBaru pesan yang berubah setelah [setelah] di semua pesanan milik akun:
	// pembeli = pesanannya sendiri, mitra = pesanan lunas di gerainya
	PesanBaru(ctx context.Context, idAkun, peran string, setelah time.Time) ([]PesanChat, error)
}

var polaIDPesan = regexp.MustCompile(`^[A-Za-z0-9_-]{8,64}$`)

// peranDi peran akun di pesanan ini, "" kalau bukan pihak pesanan
func peranDi(p Pesanan, a akun.Akun) string {
	switch {
	case a.Peran == "pembeli" && p.IDAkun == a.ID:
		return "pembeli"
	case a.Peran == "mitra" && p.IDMitra == a.ID && p.DibayarPada != nil:
		return "mitra"
	}
	return ""
}

// keadaanChat sama kayak keadaanPercakapan di aplikasi:
// "tidakAda" (belum dibayar), "terbuka", atau "bacaSaja"
func keadaanChat(p Pesanan, sekarang time.Time) string {
	if p.DibayarPada == nil {
		return "tidakAda"
	}
	if p.Status == Disiapkan || p.Status == SiapDiambil {
		return "terbuka"
	}
	akhir := p.DiambilPada
	if akhir == nil {
		akhir = p.DibatalkanPada
	}
	if akhir == nil || !sekarang.Before(akhir.Add(jamChatSetelahSelesai)) {
		return "bacaSaja"
	}
	return "terbuka"
}

// pesananChat pesanan yang boleh diakses [a] buat chat, plus perannya
func (l *Layanan) pesananChat(ctx context.Context, a akun.Akun, id string) (Pesanan, string, error) {
	p, err := l.Satu(ctx, a, id)
	if err != nil {
		return p, "", err
	}
	peran := peranDi(p, a)
	if peran == "" || keadaanChat(p, l.sekarang()) == "tidakAda" {
		return p, "", galat(http.StatusNotFound, "Percakapan belum ada. Pesanan harus dibayar dulu.")
	}
	return p, peran, nil
}

// RiwayatChat F-68
func (l *Layanan) RiwayatChat(ctx context.Context, a akun.Akun, id string) ([]PesanChat, error) {
	if _, _, err := l.pesananChat(ctx, a, id); err != nil {
		return nil, err
	}
	return l.Store.DaftarPesan(ctx, id)
}

// KirimChat F-67, F-69. [idPesan] dari aplikasi biar kiriman ulang ga dobel
func (l *Layanan) KirimChat(ctx context.Context, a akun.Akun, id, idPesan, teks string) (PesanChat, error) {
	p, peran, err := l.pesananChat(ctx, a, id)
	if err != nil {
		return PesanChat{}, err
	}
	if keadaanChat(p, l.sekarang()) != "terbuka" {
		return PesanChat{}, galat(http.StatusConflict, "Percakapan sudah ditutup karena pesanan sudah berakhir.")
	}
	teks = strings.TrimSpace(teks)
	switch {
	case !polaIDPesan.MatchString(idPesan):
		return PesanChat{}, galat(http.StatusBadRequest, "Id pesan tidak valid.")
	case teks == "" || len([]rune(teks)) > 500:
		return PesanChat{}, galat(http.StatusUnprocessableEntity, "Pesan harus 1 sampai 500 huruf.")
	}
	sekarang := l.sekarang()
	return l.Store.SimpanPesan(ctx, PesanChat{
		ID: idPesan, IDPesanan: id, Peran: peran, Teks: teks, Waktu: sekarang, Diubah: sekarang,
	})
}

// BacaChat F-70: pesan dari lawan bicara ditandai udah dibaca
func (l *Layanan) BacaChat(ctx context.Context, a akun.Akun, id string) error {
	_, peran, err := l.pesananChat(ctx, a, id)
	if err != nil {
		return err
	}
	return l.Store.TandaiDibaca(ctx, id, peran, l.sekarang())
}

// ChatBaru pesan yang berubah setelah [setelah] di semua pesanan akun.
// aplikasi manggil ini berkala, lalu pakai [sekarang] buat panggilan berikutnya
func (l *Layanan) ChatBaru(ctx context.Context, a akun.Akun, setelah time.Time) ([]PesanChat, time.Time, error) {
	sekarang := l.sekarang()
	if a.Peran != "pembeli" && a.Peran != "mitra" {
		return []PesanChat{}, sekarang, nil
	}
	daftar, err := l.Store.PesanBaru(ctx, a.ID, a.Peran, setelah)
	return daftar, sekarang, err
}
