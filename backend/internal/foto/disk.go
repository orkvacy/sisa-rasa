package foto

import (
	"context"
	"errors"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/orkvacy/sisa-rasa/backend/internal/httpx"
)

// Disk nyimpen foto di folder lokal, disajikan lewat GET /v1/foto/{nama}.
// dipakai di laptop / kalau R2 belum diatur. di Coolify foldernya harus
// dipasang Persistent Storage, kalau ga fotonya ilang tiap deploy
type Disk struct{ Folder string }

func (d Disk) Taruh(_ context.Context, nama string, isi []byte) (string, error) {
	if err := os.MkdirAll(d.Folder, 0o755); err != nil {
		return "", err
	}
	// tulis ke file sementara dulu, baru diganti nama: ga ada file setengah jadi
	sementara := filepath.Join(d.Folder, "."+nama)
	if err := os.WriteFile(sementara, isi, 0o644); err != nil {
		return "", err
	}
	if err := os.Rename(sementara, filepath.Join(d.Folder, nama)); err != nil {
		os.Remove(sementara)
		return "", err
	}
	return "/v1/foto/" + nama, nil
}

func (d Disk) Sah(url string) bool {
	nama, ada := strings.CutPrefix(url, "/v1/foto/")
	return ada && polaNama.MatchString(nama)
}

// Sajikan GET /v1/foto/{nama}. nama dicek ketat biar ga bisa dipakai buka file lain
func (d Disk) Sajikan() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		nama := r.PathValue("nama")
		if !polaNama.MatchString(nama) {
			http.NotFound(w, r)
			return
		}
		f, err := os.Open(filepath.Join(d.Folder, nama))
		if errors.Is(err, os.ErrNotExist) {
			http.NotFound(w, r)
			return
		}
		if err != nil {
			httpx.TulisGalat(w, r, err)
			return
		}
		defer f.Close()
		info, err := f.Stat()
		if err != nil {
			httpx.TulisGalat(w, r, err)
			return
		}
		// nama file acak dan isinya ga pernah berubah, jadi boleh di-cache selamanya
		w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
		w.Header().Set("Content-Type", "image/jpeg")
		http.ServeContent(w, r, nama, info.ModTime(), f)
	})
}
