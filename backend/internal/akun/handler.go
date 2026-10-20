package akun

import (
	"context"
	"net/http"
	"strings"

	"github.com/orkvacy/sisa-rasa/backend/internal/httpx"
)

// Pasang daftarin rute akun ke [mux]. [batasi] dipasang di rute yang rawan ditebak (NF-13)
func Pasang(mux *http.ServeMux, l *Layanan, batasi func(http.Handler) http.Handler) {
	mux.Handle("POST /v1/akun/daftar", batasi(httpx.Handler(l.handleDaftar)))
	mux.Handle("POST /v1/akun/masuk", batasi(httpx.Handler(l.handleMasuk)))
	mux.Handle("GET /v1/akun/saya", l.Wajib(httpx.Handler(handleSaya)))
	mux.Handle("POST /v1/akun/keluar", httpx.Handler(l.handleKeluar))
}

func (l *Layanan) handleDaftar(w http.ResponseWriter, r *http.Request) error {
	var isi struct {
		Nama  string `json:"nama"`
		Email string `json:"email"`
		Sandi string `json:"sandi"`
		Peran string `json:"peran"`
	}
	if err := httpx.BacaJSON(w, r, &isi); err != nil {
		return err
	}
	hasil, err := l.Daftar(r.Context(), isi.Nama, isi.Email, isi.Sandi, isi.Peran)
	if err != nil {
		return err
	}
	httpx.TulisJSON(w, http.StatusCreated, hasil)
	return nil
}

func (l *Layanan) handleMasuk(w http.ResponseWriter, r *http.Request) error {
	var isi struct {
		Email string `json:"email"`
		Sandi string `json:"sandi"`
	}
	if err := httpx.BacaJSON(w, r, &isi); err != nil {
		return err
	}
	hasil, err := l.Masuk(r.Context(), isi.Email, isi.Sandi)
	if err != nil {
		return err
	}
	httpx.TulisJSON(w, http.StatusOK, hasil)
	return nil
}

func handleSaya(w http.ResponseWriter, r *http.Request) error {
	httpx.TulisJSON(w, http.StatusOK, map[string]Akun{"akun": DariKonteks(r.Context())})
	return nil
}

// keluar selalu 204, walau tokennya udah ga berlaku: hasil akhirnya sama-sama keluar
func (l *Layanan) handleKeluar(w http.ResponseWriter, r *http.Request) error {
	if token := tokenDari(r); token != "" {
		if err := l.Keluar(r.Context(), token); err != nil {
			return err
		}
	}
	w.WriteHeader(http.StatusNoContent)
	return nil
}

type kunciAkun struct{}

// Wajib nolak request tanpa sesi yang berlaku, akunnya ditaruh di context
func (l *Layanan) Wajib(berikut http.Handler) http.Handler {
	return httpx.Handler(func(w http.ResponseWriter, r *http.Request) error {
		a, err := l.Sesi(r.Context(), tokenDari(r))
		if err != nil {
			return err
		}
		berikut.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), kunciAkun{}, a)))
		return nil
	})
}

// KeKonteks naruh akun di context kayak Wajib. dipakai tes paket lain
func KeKonteks(ctx context.Context, a Akun) context.Context {
	return context.WithValue(ctx, kunciAkun{}, a)
}

// DariKonteks akun yang lagi masuk, cuma ada di handler yang dibungkus Wajib
func DariKonteks(ctx context.Context) Akun {
	a, _ := ctx.Value(kunciAkun{}).(Akun)
	return a
}

// token dari header "Authorization: Bearer <token>"
func tokenDari(r *http.Request) string {
	nilai := r.Header.Get("Authorization")
	if awalan := "Bearer "; strings.HasPrefix(nilai, awalan) {
		return strings.TrimSpace(nilai[len(awalan):])
	}
	return ""
}
