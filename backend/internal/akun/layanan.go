package akun

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"net/http"
	"net/mail"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"github.com/orkvacy/sisa-rasa/backend/internal/httpx"
	"golang.org/x/crypto/bcrypt"
)

// PanjangSandiMinimal F-29
const PanjangSandiMinimal = 8

// umur token sesi sebelum harus masuk lagi
const umurSesi = 30 * 24 * time.Hour

// pesan masuk gagal sengaja sama buat email ga terdaftar dan sandi salah (SRS 3.4)
var errMasukGagal = httpx.NewGalat(http.StatusUnauthorized,
	"Email atau kata sandi salah. Coba lagi, atau atur ulang kata sandi.")

// ErrSesiTidakBerlaku token kosong, salah, dicabut, atau kedaluwarsa
var ErrSesiTidakBerlaku = httpx.NewGalat(http.StatusUnauthorized, "Sesi berakhir. Masuk lagi.")

// Layanan aturan akun, ga tau soal HTTP selain jenis galatnya
type Layanan struct {
	Store Store
	// BiayaBcrypt diturunin di tes biar cepet, di server pake bawaan
	BiayaBcrypt int
	// Jam bisa diganti di tes
	Jam func() time.Time

	// hash pura-pura buat email yg ga terdaftar, biar waktu jawabnya sama
	// kayak sandi salah dan ga bisa dipake nebak email terdaftar
	hashPalsuSekali sync.Once
	hashPalsu       []byte
}

func (l *Layanan) sekarang() time.Time {
	if l.Jam != nil {
		return l.Jam()
	}
	return time.Now()
}

func (l *Layanan) biaya() int {
	if l.BiayaBcrypt != 0 {
		return l.BiayaBcrypt
	}
	return bcrypt.DefaultCost
}

// Hasil masuk / daftar: data akun + token sesi
type Hasil struct {
	Akun  Akun   `json:"akun"`
	Token string `json:"token"`
}

// Daftar F-29. admin ga bisa daftar lewat sini (F-36)
func (l *Layanan) Daftar(ctx context.Context, nama, email, sandi, peran string) (Hasil, error) {
	nama = strings.Join(strings.Fields(nama), " ")
	email = rapikanEmail(email)
	switch {
	case utf8.RuneCountInString(nama) < 2 || utf8.RuneCountInString(nama) > 100:
		return Hasil{}, httpx.NewGalat(http.StatusUnprocessableEntity, "Isi nama 2–100 karakter.")
	case !emailValid(email):
		return Hasil{}, httpx.NewGalat(http.StatusUnprocessableEntity, "Format email belum benar.")
	case utf8.RuneCountInString(sandi) < PanjangSandiMinimal:
		return Hasil{}, httpx.NewGalat(http.StatusUnprocessableEntity, "Kata sandi minimal 8 karakter.")
	// bcrypt cuma baca 72 byte pertama, lebih dari itu ditolak biar ga nyesatin
	case len(sandi) > 72:
		return Hasil{}, httpx.NewGalat(http.StatusUnprocessableEntity, "Kata sandi maksimal 72 karakter.")
	case peran != "pembeli" && peran != "mitra":
		return Hasil{}, httpx.NewGalat(http.StatusUnprocessableEntity, "Peran tidak dikenal.")
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(sandi), l.biaya())
	if err != nil {
		return Hasil{}, err
	}
	a, err := l.Store.BuatAkun(ctx, nama, email, string(hash), peran)
	if errors.Is(err, ErrEmailDipakai) {
		return Hasil{}, httpx.NewGalat(http.StatusConflict, "Email ini sudah terdaftar. Masuk saja.")
	}
	if err != nil {
		return Hasil{}, err
	}
	return l.bukaSesi(ctx, a)
}

// Masuk F-30
func (l *Layanan) Masuk(ctx context.Context, email, sandi string) (Hasil, error) {
	a, err := l.Store.AkunDariEmail(ctx, rapikanEmail(email))
	if errors.Is(err, ErrTidakAda) {
		l.hashPalsuSekali.Do(func() {
			l.hashPalsu, _ = bcrypt.GenerateFromPassword([]byte("bukan-sandi-siapa-siapa"), l.biaya())
		})
		_ = bcrypt.CompareHashAndPassword(l.hashPalsu, []byte(sandi))
		return Hasil{}, errMasukGagal
	}
	if err != nil {
		return Hasil{}, err
	}
	if bcrypt.CompareHashAndPassword([]byte(a.HashSandi), []byte(sandi)) != nil {
		return Hasil{}, errMasukGagal
	}
	return l.bukaSesi(ctx, a.Akun)
}

// Sesi akun pemilik token, buat middleware dan GET /v1/akun/saya
func (l *Layanan) Sesi(ctx context.Context, token string) (Akun, error) {
	if token == "" {
		return Akun{}, ErrSesiTidakBerlaku
	}
	a, err := l.Store.AkunDariSesi(ctx, hashToken(token), l.sekarang())
	if errors.Is(err, ErrTidakAda) {
		return Akun{}, ErrSesiTidakBerlaku
	}
	return a, err
}

// UbahNama F-63. khusus pembeli: nama mitra = nama gerai yang nempel di
// paket dan riwayat pesanan, jadi gantinya lewat tim Sisa Rasa
func (l *Layanan) UbahNama(ctx context.Context, a Akun, nama string) (Akun, error) {
	if a.Peran != "pembeli" {
		return Akun{}, httpx.NewGalat(http.StatusForbidden,
			"Nama usaha diubah lewat tim Sisa Rasa, karena terhubung ke paket dan rekening.")
	}
	nama = strings.Join(strings.Fields(nama), " ")
	if n := len([]rune(nama)); n < 2 || n > 60 {
		return Akun{}, httpx.NewGalat(http.StatusUnprocessableEntity, "Nama 2 sampai 60 huruf.")
	}
	if err := l.Store.UbahNama(ctx, a.ID, nama); err != nil {
		return Akun{}, err
	}
	a.Nama = nama
	return a, nil
}

// HapusAkun F-62. minta sandi lagi biar HP yang kebetulan kebuka ga bisa
// dipakai orang lain buat ngehapus akun
func (l *Layanan) HapusAkun(ctx context.Context, a Akun, sandi string) error {
	if a.Peran != "pembeli" {
		return httpx.NewGalat(http.StatusForbidden,
			"Akun mitra ditutup lewat tim Sisa Rasa, karena masih ada saldo dan rekening.")
	}
	tersimpan, err := l.Store.AkunDariEmail(ctx, a.Email)
	if err != nil {
		return err
	}
	if bcrypt.CompareHashAndPassword([]byte(tersimpan.HashSandi), []byte(sandi)) != nil {
		return httpx.NewGalat(http.StatusUnauthorized, "Kata sandi salah.")
	}
	err = l.Store.HapusAkun(ctx, a.ID, l.sekarang())
	if errors.Is(err, ErrPesananAktif) {
		return httpx.NewGalat(http.StatusConflict,
			"Masih ada pesanan yang berjalan. Selesaikan atau batalkan dulu, lalu coba lagi.")
	}
	return err
}

// Cari akun dari email, dipakai penyemai data contoh
func (l *Layanan) Cari(ctx context.Context, email string) (Akun, error) {
	a, err := l.Store.AkunDariEmail(ctx, rapikanEmail(email))
	return a.Akun, err
}

// Keluar F-33: token dicabut, ga bisa dipake lagi
func (l *Layanan) Keluar(ctx context.Context, token string) error {
	return l.Store.CabutSesi(ctx, hashToken(token), l.sekarang())
}

func (l *Layanan) bukaSesi(ctx context.Context, a Akun) (Hasil, error) {
	acak := make([]byte, 32)
	if _, err := rand.Read(acak); err != nil {
		return Hasil{}, err
	}
	token := base64.RawURLEncoding.EncodeToString(acak)
	if err := l.Store.BuatSesi(ctx, hashToken(token), a.ID, l.sekarang().Add(umurSesi)); err != nil {
		return Hasil{}, err
	}
	return Hasil{Akun: a, Token: token}, nil
}

// yang disimpan di database cuma hash-nya, jadi kalau database bocor tokennya ga ikut bocor
func hashToken(token string) string {
	h := sha256.Sum256([]byte(token))
	return hex.EncodeToString(h[:])
}

func rapikanEmail(email string) string { return strings.ToLower(strings.TrimSpace(email)) }

// format email sederhana: ada@nama.domain, tanpa nama tampilan
func emailValid(email string) bool {
	if len(email) > 254 {
		return false
	}
	alamat, err := mail.ParseAddress(email)
	if err != nil || alamat.Address != email {
		return false
	}
	domain := email[strings.LastIndex(email, "@")+1:]
	return strings.Contains(domain, ".")
}
