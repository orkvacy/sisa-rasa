// Package httpx berisi alat bantu HTTP yang dipakai semua handler:
// baca/tulis JSON, format galat, dan middleware.
package httpx

import (
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
)

// Galat dibalikin ke aplikasi sebagai {"pesan": "..."} dengan kode HTTP-nya.
// pesannya langsung ditampilin di layar, jadi ditulis buat pengguna
type Galat struct {
	Kode  int
	Pesan string
}

func (g *Galat) Error() string { return g.Pesan }

func NewGalat(kode int, pesan string) *Galat { return &Galat{Kode: kode, Pesan: pesan} }

// batas isi request, biar ga bisa dikirimin isian raksasa
const batasIsi = 64 << 10

// BacaJSON isi body request ke [tujuan]. field yg ga dikenal ditolak
func BacaJSON(w http.ResponseWriter, r *http.Request, tujuan any) error {
	r.Body = http.MaxBytesReader(w, r.Body, batasIsi)
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(tujuan); err != nil {
		return NewGalat(http.StatusBadRequest, "Isian tidak bisa dibaca.")
	}
	if err := dec.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		return NewGalat(http.StatusBadRequest, "Isian tidak bisa dibaca.")
	}
	return nil
}

// TulisJSON kirim [isi] sebagai JSON dengan kode [kode]
func TulisJSON(w http.ResponseWriter, kode int, isi any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(kode)
	if isi != nil {
		_ = json.NewEncoder(w).Encode(isi)
	}
}

// TulisGalat kirim galat ke aplikasi. galat yg bukan *Galat dianggap galat server:
// detailnya cuma dicatat di log, ke aplikasi cuma dikirim pesan umum
func TulisGalat(w http.ResponseWriter, r *http.Request, err error) {
	var g *Galat
	if errors.As(err, &g) {
		TulisJSON(w, g.Kode, map[string]string{"pesan": g.Pesan})
		return
	}
	slog.Error("galat server", "metode", r.Method, "jalur", r.URL.Path, "galat", err)
	TulisJSON(w, http.StatusInternalServerError,
		map[string]string{"pesan": "Terjadi gangguan di server. Coba lagi sebentar."})
}

// Handler kayak http.HandlerFunc tapi bisa balikin error, biar handler ga ngulang TulisGalat
type Handler func(w http.ResponseWriter, r *http.Request) error

func (h Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if err := h(w, r); err != nil {
		TulisGalat(w, r, err)
	}
}
