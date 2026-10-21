// Package akun ngurus daftar, masuk, sesi, dan keluar (F-29 s.d. F-33).
package akun

import (
	"context"
	"errors"
	"time"
)

// Akun yang dikirim ke aplikasi. hash sandi sengaja ga ikut
type Akun struct {
	ID    string `json:"id"`
	Nama  string `json:"nama"`
	Email string `json:"email"`
	Peran string `json:"peran"`
	// PunyaSandi false = akun dibikin lewat Google, belum pernah pasang sandi.
	// aplikasi pakai ini buat nentuin konfirmasi hapus akun
	PunyaSandi bool `json:"punyaSandi"`
	// Foto URL foto profil (F-63), kosong = pakai inisial nama
	Foto string `json:"foto,omitempty"`
}

// akunTersimpan isi baris tabel akun, termasuk hash sandinya
type akunTersimpan struct {
	Akun
	HashSandi string
	// GoogleSub id akun Google yang nyambung, kosong kalau ga ada
	GoogleSub string
}

// ErrTidakAda dibalikin Store kalau barisnya ga ketemu
var ErrTidakAda = errors.New("tidak ada")

// ErrEmailDipakai dibalikin Store kalau email-nya udah terdaftar
var ErrEmailDipakai = errors.New("email sudah dipakai")

// ErrPesananAktif akun masih punya pesanan yang belum selesai, belum boleh dihapus
var ErrPesananAktif = errors.New("pesanan aktif")

// Store tempat nyimpen akun sama sesi. versi aslinya Postgres (store_pg.go),
// di tes pake versi di memori biar ga butuh database
type Store interface {
	BuatAkun(ctx context.Context, nama, email, hashSandi, peran string) (Akun, error)
	AkunDariEmail(ctx context.Context, email string) (akunTersimpan, error)
	// BuatAkunGoogle akun pembeli tanpa sandi, nyambung ke akun Google [sub]
	BuatAkunGoogle(ctx context.Context, nama, email, sub string) (Akun, error)
	AkunDariGoogle(ctx context.Context, sub string) (akunTersimpan, error)
	BuatSesi(ctx context.Context, tokenHash, idAkun string, kedaluwarsa time.Time) error
	// AkunDariSesi cuma balikin akun kalau sesinya belum dicabut dan belum kedaluwarsa
	AkunDariSesi(ctx context.Context, tokenHash string, sekarang time.Time) (Akun, error)
	CabutSesi(ctx context.Context, tokenHash string, sekarang time.Time) error
	// UbahNama F-63
	UbahNama(ctx context.Context, idAkun, nama string) error
	// HapusAkun F-62: data pribadi dikosongkan, semua sesi dicabut, nama di
	// pesanan lama dianonimkan. ErrPesananAktif kalau masih ada pesanan berjalan
	HapusAkun(ctx context.Context, idAkun string, sekarang time.Time) error
	// AturFoto F-63, [url] "" = hapus foto
	AturFoto(ctx context.Context, idAkun, url string) error

	StoreReset
}
