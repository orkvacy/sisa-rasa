// Package foto ngurus foto paket yang diunggah mitra dan foto profil akun.
//
// tiap foto di-decode lalu di-encode ulang jadi JPEG lebar maksimal 1200 px:
// ukurannya kecil buat HP, file yang bukan gambar ketolak, dan metadata
// (EXIF, termasuk lokasi GPS dari kamera HP) ikut kebuang.
// hasilnya disimpan ke Cloudflare R2 (production) atau ke disk (dev, cadangan)
package foto

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"image"
	"image/jpeg"
	_ "image/png" // daftarin decoder PNG
	"io"
	"net/http"
	"regexp"

	"golang.org/x/image/draw"
	_ "golang.org/x/image/webp" // daftarin decoder WebP

	"github.com/orkvacy/sisa-rasa/backend/internal/akun"
	"github.com/orkvacy/sisa-rasa/backend/internal/httpx"
)

const (
	// BatasUnggah ukuran file paling besar yang diterima
	BatasUnggah = 8 << 20
	lebarMaks   = 1200
	// foto 12 MP HP jaman sekarang aman, gambar raksasa yang bikin RAM jebol ditolak
	pikselMaks = 40_000_000
)

// polaNama nama file foto yang disimpan: 32 huruf hex + .jpg
var polaNama = regexp.MustCompile(`^[0-9a-f]{32}\.jpg$`)

// Penyimpanan tempat naruh foto yang udah diproses
type Penyimpanan interface {
	// Taruh nyimpen [isi] (JPEG) dengan [nama], balikin URL / jalur buat aplikasi
	Taruh(ctx context.Context, nama string, isi []byte) (string, error)
	// Sah true kalau [url] foto yang disimpan lewat penyimpanan ini,
	// dipakai buat nolak URL foto sembarangan di isian paket
	Sah(url string) bool
}

var errBukanGambar = httpx.NewGalat(http.StatusUnprocessableEntity,
	"File bukan gambar. Pilih foto JPG, PNG, atau WebP.")

// Proses baca foto dari [r], kecilin, dan encode ulang jadi JPEG
func Proses(r io.Reader) ([]byte, error) {
	isi, err := io.ReadAll(io.LimitReader(r, BatasUnggah+1))
	if err != nil {
		return nil, err
	}
	if len(isi) > BatasUnggah {
		return nil, httpx.NewGalat(http.StatusRequestEntityTooLarge, "Foto paling besar 8 MB.")
	}
	cfg, _, err := image.DecodeConfig(bytes.NewReader(isi))
	if err != nil {
		return nil, errBukanGambar
	}
	if cfg.Width*cfg.Height > pikselMaks {
		return nil, httpx.NewGalat(http.StatusUnprocessableEntity, "Resolusi foto terlalu besar.")
	}
	asli, _, err := image.Decode(bytes.NewReader(isi))
	if err != nil {
		return nil, errBukanGambar
	}

	kotak := asli.Bounds()
	lebar, tinggi := kotak.Dx(), kotak.Dy()
	if lebar > lebarMaks {
		tinggi = tinggi * lebarMaks / lebar
		lebar = lebarMaks
	}
	hasil := image.NewRGBA(image.Rect(0, 0, lebar, tinggi))
	draw.CatmullRom.Scale(hasil, hasil.Bounds(), asli, kotak, draw.Src, nil)

	var b bytes.Buffer
	if err := jpeg.Encode(&b, hasil, &jpeg.Options{Quality: 82}); err != nil {
		return nil, err
	}
	return b.Bytes(), nil
}

func namaAcak() (string, error) {
	acak := make([]byte, 16)
	if _, err := rand.Read(acak); err != nil {
		return "", err
	}
	return hex.EncodeToString(acak) + ".jpg", nil
}

// Unggah POST /v1/mitra/foto (multipart, field "foto"), cuma buat mitra.
// jawabannya {"foto": "<url>"}, dipakai di isian paket
func Unggah(simpan Penyimpanan) httpx.Handler {
	return func(w http.ResponseWriter, r *http.Request) error {
		if akun.DariKonteks(r.Context()).Peran != "mitra" {
			return httpx.NewGalat(http.StatusForbidden, "Fitur ini khusus akun mitra.")
		}
		url, err := terima(w, r, simpan)
		if err != nil {
			return err
		}
		httpx.TulisJSON(w, http.StatusCreated, map[string]string{"foto": url})
		return nil
	}
}

// UnggahProfil POST /v1/akun/foto (multipart, field "foto"), semua peran.
// fotonya langsung dipasang jadi foto profil lewat [atur] (akun.Layanan.AturFoto),
// jawabannya {"akun": {...}}
func UnggahProfil(simpan Penyimpanan,
	atur func(context.Context, akun.Akun, string) (akun.Akun, error)) httpx.Handler {
	return func(w http.ResponseWriter, r *http.Request) error {
		url, err := terima(w, r, simpan)
		if err != nil {
			return err
		}
		a, err := atur(r.Context(), akun.DariKonteks(r.Context()), url)
		if err != nil {
			return err
		}
		httpx.TulisJSON(w, http.StatusOK, map[string]akun.Akun{"akun": a})
		return nil
	}
}

// terima baca field "foto" dari multipart, proses, simpan, balikin URL-nya
func terima(w http.ResponseWriter, r *http.Request, simpan Penyimpanan) (string, error) {
	r.Body = http.MaxBytesReader(w, r.Body, BatasUnggah+(1<<20))
	baca, err := r.MultipartReader()
	if err != nil {
		return "", httpx.NewGalat(http.StatusBadRequest, "Kirim foto sebagai multipart/form-data.")
	}
	for {
		bagian, err := baca.NextPart()
		if err != nil {
			return "", httpx.NewGalat(http.StatusBadRequest, "Field foto tidak ada.")
		}
		if bagian.FormName() != "foto" {
			continue
		}
		isi, err := Proses(bagian)
		if err != nil {
			return "", err
		}
		nama, err := namaAcak()
		if err != nil {
			return "", err
		}
		return simpan.Taruh(r.Context(), nama, isi)
	}
}
