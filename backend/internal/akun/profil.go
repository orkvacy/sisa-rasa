package akun

import (
	"context"
	"net/http"
	"unicode/utf8"

	"github.com/orkvacy/sisa-rasa/backend/internal/httpx"
	"golang.org/x/crypto/bcrypt"
)

// GantiSandiSaya F-64: ganti sandi dari halaman akun, pakai sandi lama.
// semua HP lain yang masih masuk dikeluarin, HP ini dapet sesi baru biar
// ga ikut ketendang
func (l *Layanan) GantiSandiSaya(ctx context.Context, a Akun, lama, baru string) (Hasil, error) {
	tersimpan, err := l.Store.AkunDariEmail(ctx, a.Email)
	if err != nil {
		return Hasil{}, err
	}
	if tersimpan.HashSandi == "" {
		return Hasil{}, httpx.NewGalat(http.StatusConflict,
			"Akunmu masuk dengan Google, jadi tidak memakai kata sandi.")
	}
	if bcrypt.CompareHashAndPassword([]byte(tersimpan.HashSandi), []byte(lama)) != nil {
		return Hasil{}, httpx.NewGalat(http.StatusUnauthorized, "Kata sandi lama salah.")
	}
	switch {
	case utf8.RuneCountInString(baru) < PanjangSandiMinimal:
		return Hasil{}, httpx.NewGalat(http.StatusUnprocessableEntity, "Kata sandi baru minimal 8 karakter.")
	case len(baru) > 72:
		return Hasil{}, httpx.NewGalat(http.StatusUnprocessableEntity, "Kata sandi baru maksimal 72 karakter.")
	case baru == lama:
		return Hasil{}, httpx.NewGalat(http.StatusUnprocessableEntity,
			"Kata sandi baru harus beda dari yang lama.")
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(baru), l.biaya())
	if err != nil {
		return Hasil{}, err
	}
	if err := l.Store.GantiSandi(ctx, a.ID, string(hash), l.sekarang()); err != nil {
		return Hasil{}, err
	}
	a.PunyaSandi = true
	return l.bukaSesi(ctx, a)
}

// AturFoto F-63 foto profil. [url] hasil unggahan foto.Penyimpanan, "" = hapus
// (balik ke inisial nama). semua peran boleh, nama mitra tetap lewat tim
func (l *Layanan) AturFoto(ctx context.Context, a Akun, url string) (Akun, error) {
	if err := l.Store.AturFoto(ctx, a.ID, url); err != nil {
		return Akun{}, err
	}
	a.Foto = url
	return a, nil
}
