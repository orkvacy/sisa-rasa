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
}

// akunTersimpan isi baris tabel akun, termasuk hash sandinya
type akunTersimpan struct {
	Akun
	HashSandi string
}

// ErrTidakAda dibalikin Store kalau barisnya ga ketemu
var ErrTidakAda = errors.New("tidak ada")

// ErrEmailDipakai dibalikin Store kalau email-nya udah terdaftar
var ErrEmailDipakai = errors.New("email sudah dipakai")

// Store tempat nyimpen akun sama sesi. versi aslinya Postgres (store_pg.go),
// di tes pake versi di memori biar ga butuh database
type Store interface {
	BuatAkun(ctx context.Context, nama, email, hashSandi, peran string) (Akun, error)
	AkunDariEmail(ctx context.Context, email string) (akunTersimpan, error)
	BuatSesi(ctx context.Context, tokenHash, idAkun string, kedaluwarsa time.Time) error
	// AkunDariSesi cuma balikin akun kalau sesinya belum dicabut dan belum kedaluwarsa
	AkunDariSesi(ctx context.Context, tokenHash string, sekarang time.Time) (Akun, error)
	CabutSesi(ctx context.Context, tokenHash string, sekarang time.Time) error
}
