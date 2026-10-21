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
	mux.Handle("POST /v1/akun/google", batasi(httpx.Handler(l.handleGoogle)))
	// F-61 atur ulang sandi. semua dibatasi: kode cuma 6 angka, jangan sampai ditebak
	mux.Handle("POST /v1/akun/lupa-sandi", batasi(httpx.Handler(l.handleLupaSandi)))
	mux.Handle("POST /v1/akun/lupa-sandi/cek", batasi(httpx.Handler(l.handleCekKode)))
	mux.Handle("POST /v1/akun/lupa-sandi/atur", batasi(httpx.Handler(l.handleAturSandi)))
	mux.Handle("GET /v1/akun/saya", l.Wajib(httpx.Handler(handleSaya)))
	mux.Handle("POST /v1/akun/keluar", httpx.Handler(l.handleKeluar))
	mux.Handle("PATCH /v1/akun/saya", l.Wajib(httpx.Handler(l.handleUbahNama)))
	// minta sandi lama, jadi dibatasi juga
	mux.Handle("POST /v1/akun/sandi", batasi(l.Wajib(httpx.Handler(l.handleGantiSandi))))
	// unggah foto profil ada di main.go (butuh penyimpanan foto), hapusnya di sini
	mux.Handle("DELETE /v1/akun/foto", l.Wajib(httpx.Handler(l.handleHapusFoto)))
	// minta sandi, jadi ikut dibatasi biar ga bisa dipakai nebak sandi
	mux.Handle("POST /v1/akun/hapus", batasi(l.Wajib(httpx.Handler(l.handleHapus))))
}

func (l *Layanan) handleUbahNama(w http.ResponseWriter, r *http.Request) error {
	var isi struct {
		Nama string `json:"nama"`
	}
	if err := httpx.BacaJSON(w, r, &isi); err != nil {
		return err
	}
	a, err := l.UbahNama(r.Context(), DariKonteks(r.Context()), isi.Nama)
	if err != nil {
		return err
	}
	httpx.TulisJSON(w, http.StatusOK, map[string]Akun{"akun": a})
	return nil
}

func (l *Layanan) handleGantiSandi(w http.ResponseWriter, r *http.Request) error {
	var isi struct {
		Lama string `json:"lama"`
		Baru string `json:"baru"`
	}
	if err := httpx.BacaJSON(w, r, &isi); err != nil {
		return err
	}
	hasil, err := l.GantiSandiSaya(r.Context(), DariKonteks(r.Context()), isi.Lama, isi.Baru)
	if err != nil {
		return err
	}
	httpx.TulisJSON(w, http.StatusOK, hasil)
	return nil
}

func (l *Layanan) handleHapusFoto(w http.ResponseWriter, r *http.Request) error {
	a, err := l.AturFoto(r.Context(), DariKonteks(r.Context()), "")
	if err != nil {
		return err
	}
	httpx.TulisJSON(w, http.StatusOK, map[string]Akun{"akun": a})
	return nil
}

func (l *Layanan) handleHapus(w http.ResponseWriter, r *http.Request) error {
	var isi struct {
		Sandi   string `json:"sandi"`
		IDToken string `json:"idToken"`
	}
	if err := httpx.BacaJSON(w, r, &isi); err != nil {
		return err
	}
	if err := l.HapusAkun(r.Context(), DariKonteks(r.Context()), isi.Sandi, isi.IDToken); err != nil {
		return err
	}
	w.WriteHeader(http.StatusNoContent)
	return nil
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

func (l *Layanan) handleGoogle(w http.ResponseWriter, r *http.Request) error {
	var isi struct {
		IDToken string `json:"idToken"`
	}
	if err := httpx.BacaJSON(w, r, &isi); err != nil {
		return err
	}
	hasil, err := l.MasukGoogle(r.Context(), isi.IDToken)
	if err != nil {
		return err
	}
	httpx.TulisJSON(w, http.StatusOK, hasil)
	return nil
}

func (l *Layanan) handleLupaSandi(w http.ResponseWriter, r *http.Request) error {
	var isi struct {
		Email string `json:"email"`
	}
	if err := httpx.BacaJSON(w, r, &isi); err != nil {
		return err
	}
	if err := l.MintaKodeReset(r.Context(), isi.Email); err != nil {
		return err
	}
	w.WriteHeader(http.StatusNoContent)
	return nil
}

func (l *Layanan) handleCekKode(w http.ResponseWriter, r *http.Request) error {
	var isi struct {
		Email string `json:"email"`
		Kode  string `json:"kode"`
	}
	if err := httpx.BacaJSON(w, r, &isi); err != nil {
		return err
	}
	tiket, err := l.CekKodeReset(r.Context(), isi.Email, strings.TrimSpace(isi.Kode))
	if err != nil {
		return err
	}
	httpx.TulisJSON(w, http.StatusOK, map[string]string{"tiket": tiket})
	return nil
}

func (l *Layanan) handleAturSandi(w http.ResponseWriter, r *http.Request) error {
	var isi struct {
		Tiket string `json:"tiket"`
		Sandi string `json:"sandi"`
	}
	if err := httpx.BacaJSON(w, r, &isi); err != nil {
		return err
	}
	if err := l.AturSandiBaru(r.Context(), isi.Tiket, isi.Sandi); err != nil {
		return err
	}
	w.WriteHeader(http.StatusNoContent)
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

// Opsional kayak Wajib, tapi request tanpa token / token ga berlaku tetap
// diterusin tanpa akun (dipakai daftar paket yang boleh dibuka tamu)
func (l *Layanan) Opsional(berikut http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if a, err := l.Sesi(r.Context(), tokenDari(r)); err == nil {
			r = r.WithContext(context.WithValue(r.Context(), kunciAkun{}, a))
		}
		berikut.ServeHTTP(w, r)
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
