package akun

import (
	"context"
	"errors"
	"net/http"

	"github.com/orkvacy/sisa-rasa/backend/internal/httpx"
)

// SandiContoh kata sandi akun contoh, sama kayak sandiUji di aplikasi.
// cuma disemai di lingkungan dev, ga pernah di staging / production
const SandiContoh = "sisarasa123"

var akunContoh = []struct{ nama, email, peran string }{
	{"Rani Amelia", "rani.amelia@gmail.com", "pembeli"},
	{"Dimas Pratama", "dimas.pratama@contoh.id", "pembeli"},
	{"Ibis Hotel", "dapur.ibis@contoh.id", "mitra"},
}

// SemaiContoh bikin akun contoh buat demo / tes kalau belum ada
func SemaiContoh(ctx context.Context, l *Layanan) error {
	for _, a := range akunContoh {
		_, err := l.Daftar(ctx, a.nama, a.email, SandiContoh, a.peran)
		var g *httpx.Galat
		if errors.As(err, &g) && g.Kode == http.StatusConflict {
			continue // udah ada
		}
		if err != nil {
			return err
		}
	}
	return nil
}
