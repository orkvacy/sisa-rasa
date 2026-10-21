package akun

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"log/slog"
	"math/big"
	"net/http"
	"time"
	"unicode/utf8"

	"github.com/orkvacy/sisa-rasa/backend/internal/httpx"
	"golang.org/x/crypto/bcrypt"
)

// aturan atur ulang kata sandi (F-61), sama kayak domain/repositories/layanan_akun.dart
const (
	berlakuKode    = 10 * time.Minute
	jedaKirimUlang = 60 * time.Second
	batasSalahKode = 5
	// tiket dari kode yang cocok, dipakai sekali buat ganti sandi
	berlakuTiket = 15 * time.Minute
)

// ResetSandi satu permintaan atur ulang sandi. satu akun cuma punya satu yang aktif
type ResetSandi struct {
	IDAkun           string
	KodeHash         string // kosong = kodenya udah dipakai
	Kedaluwarsa      time.Time
	Salah            int
	Dibuat           time.Time
	TiketHash        string
	TiketKedaluwarsa time.Time
}

// StoreReset bagian Store buat atur ulang sandi
type StoreReset interface {
	// SimpanReset nimpa permintaan lama akun ini
	SimpanReset(ctx context.Context, r ResetSandi) error
	ResetAkun(ctx context.Context, idAkun string) (ResetSandi, error)
	ResetDariTiket(ctx context.Context, tiketHash string) (ResetSandi, error)
	// CatatSalah nambah hitungan salah kode, balikin jumlah terbarunya
	CatatSalah(ctx context.Context, idAkun string) (int, error)
	// GantiSandi ganti hash sandi, cabut semua sesi, hapus permintaan reset
	GantiSandi(ctx context.Context, idAkun, hashSandi string, sekarang time.Time) error
}

// Pengirim kirim email (Resend, lihat internal/surel). nil = atur ulang sandi mati
type Pengirim interface {
	Kirim(ctx context.Context, ke, subjek, teks, html string) error
}

var (
	errResetMati = httpx.NewGalat(http.StatusServiceUnavailable,
		"Atur ulang kata sandi belum tersedia. Hubungi admin Sisa Rasa.")
	errKodeSalah  = httpx.NewGalat(http.StatusUnprocessableEntity, "Kode salah atau sudah kedaluwarsa.")
	errKodeHangus = httpx.NewGalat(http.StatusUnprocessableEntity, "Terlalu banyak percobaan. Minta kode baru.")
	errTiketHabis = httpx.NewGalat(http.StatusUnauthorized, "Sesi atur ulang sudah habis. Ulangi dari awal.")
)

func hashKode(idAkun, kode string) string { return hashToken(idAkun + ":" + kode) }

// MintaKodeReset F-61 langkah 1: kirim kode ke email. jawabannya selalu sama,
// terdaftar atau ga, biar ga bisa dipake nebak email orang
func (l *Layanan) MintaKodeReset(ctx context.Context, email string) error {
	if l.Pengirim == nil {
		return errResetMati
	}
	email = rapikanEmail(email)
	if !emailValid(email) {
		return httpx.NewGalat(http.StatusUnprocessableEntity, "Format email belum benar.")
	}
	a, err := l.Store.AkunDariEmail(ctx, email)
	if errors.Is(err, ErrTidakAda) {
		return nil
	}
	if err != nil {
		return err
	}
	now := l.sekarang()
	// baru aja dikirim: ga dikirim lagi (aplikasi sendiri yang nahan tombolnya)
	if lama, err := l.Store.ResetAkun(ctx, a.ID); err == nil && now.Sub(lama.Dibuat) < jedaKirimUlang {
		return nil
	}
	n, err := rand.Int(rand.Reader, big.NewInt(900000))
	if err != nil {
		return err
	}
	kode := fmt.Sprint(n.Int64() + 100000)
	if err := l.Store.SimpanReset(ctx, ResetSandi{
		IDAkun: a.ID, KodeHash: hashKode(a.ID, kode), Kedaluwarsa: now.Add(berlakuKode), Dibuat: now,
	}); err != nil {
		return err
	}
	// dikirim di belakang: jawaban ke aplikasi ga nunggu Resend, dan lamanya
	// sama buat email terdaftar maupun ga
	kirim := func() {
		ctx, batal := context.WithTimeout(context.Background(), 20*time.Second)
		defer batal()
		subjek, teks, html := isiEmailKode(a.Nama, kode)
		if err := l.Pengirim.Kirim(ctx, a.Email, subjek, teks, html); err != nil {
			slog.Error("kirim kode atur ulang gagal", "akun", a.ID, "galat", err)
		}
	}
	if l.KirimLangsung {
		kirim()
	} else {
		go kirim()
	}
	return nil
}

// CekKodeReset F-61 langkah 2: kode cocok -> tiket sekali pakai buat langkah 3
func (l *Layanan) CekKodeReset(ctx context.Context, email, kode string) (string, error) {
	if l.Pengirim == nil {
		return "", errResetMati
	}
	a, err := l.Store.AkunDariEmail(ctx, rapikanEmail(email))
	if errors.Is(err, ErrTidakAda) {
		return "", errKodeSalah
	}
	if err != nil {
		return "", err
	}
	r, err := l.Store.ResetAkun(ctx, a.ID)
	if errors.Is(err, ErrTidakAda) {
		return "", errKodeSalah
	}
	if err != nil {
		return "", err
	}
	now := l.sekarang()
	switch {
	case r.KodeHash == "" || !now.Before(r.Kedaluwarsa):
		return "", errKodeSalah
	case r.Salah >= batasSalahKode:
		return "", errKodeHangus
	}
	if hashKode(a.ID, kode) != r.KodeHash {
		salah, err := l.Store.CatatSalah(ctx, a.ID)
		if err != nil {
			return "", err
		}
		if salah >= batasSalahKode {
			return "", errKodeHangus
		}
		return "", errKodeSalah
	}
	acak := make([]byte, 32)
	if _, err := rand.Read(acak); err != nil {
		return "", err
	}
	tiket := base64.RawURLEncoding.EncodeToString(acak)
	// kode sekali pakai: abis cocok langsung dikosongin
	r.KodeHash = ""
	r.TiketHash = hashToken(tiket)
	r.TiketKedaluwarsa = now.Add(berlakuTiket)
	if err := l.Store.SimpanReset(ctx, r); err != nil {
		return "", err
	}
	return tiket, nil
}

// AturSandiBaru F-61 langkah 3: ganti sandi, semua HP yang masih masuk dikeluarin
func (l *Layanan) AturSandiBaru(ctx context.Context, tiket, sandi string) error {
	if utf8.RuneCountInString(sandi) < PanjangSandiMinimal {
		return httpx.NewGalat(http.StatusUnprocessableEntity, "Kata sandi minimal 8 karakter.")
	}
	if len(sandi) > 72 {
		return httpx.NewGalat(http.StatusUnprocessableEntity, "Kata sandi maksimal 72 karakter.")
	}
	if tiket == "" {
		return errTiketHabis
	}
	r, err := l.Store.ResetDariTiket(ctx, hashToken(tiket))
	if errors.Is(err, ErrTidakAda) {
		return errTiketHabis
	}
	if err != nil {
		return err
	}
	if !l.sekarang().Before(r.TiketKedaluwarsa) {
		return errTiketHabis
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(sandi), l.biaya())
	if err != nil {
		return err
	}
	return l.Store.GantiSandi(ctx, r.IDAkun, string(hash), l.sekarang())
}

func isiEmailKode(nama, kode string) (subjek, teks, html string) {
	subjek = "Kode atur ulang kata sandi Sisa Rasa: " + kode
	teks = fmt.Sprintf("Halo %s,\n\nKode atur ulang kata sandi Sisa Rasa kamu: %s\n\n"+
		"Kode berlaku 10 menit dan hanya bisa dipakai sekali. Jangan berikan kode ini ke siapa pun, "+
		"termasuk yang mengaku dari Sisa Rasa.\n\nKalau kamu tidak meminta atur ulang kata sandi, abaikan email ini.\n\nSisa Rasa",
		nama, kode)
	html = fmt.Sprintf(`<div style="font-family:Arial,sans-serif;max-width:480px;color:#1a1a1a">
<p>Halo %s,</p>
<p>Kode atur ulang kata sandi Sisa Rasa kamu:</p>
<p style="font-size:32px;font-weight:700;letter-spacing:6px;color:#1A382B;margin:16px 0">%s</p>
<p>Kode berlaku <b>10 menit</b> dan hanya bisa dipakai sekali. Jangan berikan kode ini ke siapa pun, termasuk yang mengaku dari Sisa Rasa.</p>
<p style="color:#6b6b6b">Kalau kamu tidak meminta atur ulang kata sandi, abaikan email ini.</p>
</div>`, htmlAman(nama), kode)
	return subjek, teks, html
}

// htmlAman nama akun ditulis apa adanya di email, jadi karakter HTML-nya di-escape
func htmlAman(s string) string {
	b := make([]rune, 0, len(s))
	for _, c := range s {
		switch c {
		case '<', '>', '&', '"', '\'':
			b = append(b, []rune(fmt.Sprintf("&#%d;", c))...)
		default:
			b = append(b, c)
		}
	}
	return string(b)
}
