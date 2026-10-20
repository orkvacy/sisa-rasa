package foto

import (
	"bytes"
	"encoding/json"
	"image"
	"image/color"
	"image/jpeg"
	"image/png"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/orkvacy/sisa-rasa/backend/internal/akun"
)

func pngContoh(lebar, tinggi int) []byte {
	img := image.NewRGBA(image.Rect(0, 0, lebar, tinggi))
	for x := range lebar {
		img.Set(x, tinggi/2, color.RGBA{200, 80, 40, 255})
	}
	var b bytes.Buffer
	_ = png.Encode(&b, img)
	return b.Bytes()
}

// unggah kirim [isi] sebagai multipart field "foto" lewat handler Unggah
func unggah(t *testing.T, simpan Penyimpanan, peran string, isi []byte) (int, string) {
	t.Helper()
	var badan bytes.Buffer
	m := multipart.NewWriter(&badan)
	f, _ := m.CreateFormFile("foto", "makanan.png")
	_, _ = f.Write(isi)
	_ = m.Close()
	r := httptest.NewRequest("POST", "/v1/mitra/foto", &badan)
	r.Header.Set("Content-Type", m.FormDataContentType())
	r = r.WithContext(akun.KeKonteks(r.Context(), akun.Akun{ID: "m1", Nama: "Ibis Hotel", Peran: peran}))
	w := httptest.NewRecorder()
	Unggah(simpan).ServeHTTP(w, r)
	var hasil map[string]string
	_ = json.Unmarshal(w.Body.Bytes(), &hasil)
	return w.Code, hasil["foto"]
}

func TestUnggahDanSajikanDisk(t *testing.T) {
	disk := Disk{Folder: t.TempDir()}
	kode, jalur := unggah(t, disk, "mitra", pngContoh(2400, 1600))
	if kode != 201 || !disk.Sah(jalur) {
		t.Fatalf("unggah: %d %q", kode, jalur)
	}

	mux := http.NewServeMux()
	mux.Handle("GET /v1/foto/{nama}", disk.Sajikan())
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, httptest.NewRequest("GET", jalur, nil))
	if w.Code != 200 || w.Header().Get("Content-Type") != "image/jpeg" {
		t.Fatalf("sajikan: %d %s", w.Code, w.Header().Get("Content-Type"))
	}
	// diubah jadi JPEG lebar 1200, tinggi ikut proporsional
	cfg, err := jpeg.DecodeConfig(w.Body)
	if err != nil || cfg.Width != 1200 || cfg.Height != 800 {
		t.Fatalf("hasil: %+v %v", cfg, err)
	}

	// nama ngawur / coba keluar folder: 404
	for _, jalur := range []string{"/v1/foto/..%2F..%2Fetc%2Fpasswd", "/v1/foto/abc.jpg", "/v1/foto/" + strings.Repeat("0", 32) + ".jpg"} {
		w := httptest.NewRecorder()
		mux.ServeHTTP(w, httptest.NewRequest("GET", jalur, nil))
		if w.Code != 404 {
			t.Errorf("%s: %d", jalur, w.Code)
		}
	}
}

func TestUnggahDitolak(t *testing.T) {
	disk := Disk{Folder: t.TempDir()}
	if kode, _ := unggah(t, disk, "pembeli", pngContoh(10, 10)); kode != http.StatusForbidden {
		t.Fatalf("pembeli unggah: %d", kode)
	}
	if kode, _ := unggah(t, disk, "mitra", []byte("<?php echo 'bukan foto'; ?>")); kode != http.StatusUnprocessableEntity {
		t.Fatalf("file teks: %d", kode)
	}
	if _, err := Proses(bytes.NewReader(make([]byte, BatasUnggah+10))); err == nil {
		t.Fatal("file kebesaran harus ditolak")
	}
}

func TestSah(t *testing.T) {
	disk := Disk{Folder: "x"}
	r2 := &R2{publik: "https://cdn.sisarasa.web.id"}
	nama := strings.Repeat("a", 32) + ".jpg"
	for url, sah := range map[string][2]bool{
		"/v1/foto/" + nama:                             {true, false},
		"https://cdn.sisarasa.web.id/paket/" + nama:    {false, true},
		"assets/images/paket/sushi.jpg":                {false, false},
		"https://jahat.example/paket/" + nama:          {false, false},
		"https://cdn.sisarasa.web.id/paket/../rahasia": {false, false},
	} {
		if disk.Sah(url) != sah[0] || r2.Sah(url) != sah[1] {
			t.Errorf("%s: disk %v r2 %v", url, disk.Sah(url), r2.Sah(url))
		}
	}
}
