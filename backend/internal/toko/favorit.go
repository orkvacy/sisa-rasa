package toko

import (
	"context"
	"errors"

	"github.com/orkvacy/sisa-rasa/backend/internal/akun"
)

// MitraFavorit satu mitra di daftar favorit. nama + jenis ikut dikirim biar
// mitra yang hari ini ga punya paket tetap bisa ditampilin
type MitraFavorit struct {
	ID    string `json:"id"`
	Nama  string `json:"nama"`
	Jenis string `json:"jenis"`
}

// StoreFavorit bagian Store buat mitra favorit pembeli
type StoreFavorit interface {
	// Favorit mitra yang disukai [idPembeli], yang terbaru di depan
	Favorit(ctx context.Context, idPembeli string) ([]MitraFavorit, error)
	// AturFavorit nambah ([suka] true) atau ngapus favorit. dua-duanya
	// idempoten: nambah yang udah ada / ngapus yang ga ada tetap berhasil.
	// ErrTidakAda kalau [idMitra] bukan akun mitra
	AturFavorit(ctx context.Context, idPembeli, idMitra string, suka bool) error
}

// DaftarFavorit mitra favorit pembeli yang lagi masuk
func (l *Layanan) DaftarFavorit(ctx context.Context, a akun.Akun) ([]MitraFavorit, error) {
	if a.Peran != "pembeli" {
		return nil, errBukanPembeli
	}
	return l.Store.Favorit(ctx, a.ID)
}

// AturFavorit simpan / lepas mitra dari favorit (ikon hati di halaman mitra)
func (l *Layanan) AturFavorit(ctx context.Context, a akun.Akun, idMitra string, suka bool) error {
	if a.Peran != "pembeli" {
		return errBukanPembeli
	}
	if !idSah(idMitra) {
		return errTidakAda
	}
	err := l.Store.AturFavorit(ctx, a.ID, idMitra, suka)
	if errors.Is(err, ErrTidakAda) {
		return errTidakAda
	}
	return err
}
