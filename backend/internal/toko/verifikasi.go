package toko

import (
	"context"
	"net/http"
	"slices"
	"strings"
	"time"

	"github.com/orkvacy/sisa-rasa/backend/internal/akun"
)

// status verifikasi gerai mitra (F-37)
const (
	GeraiMenunggu      = "menunggu"
	GeraiTerverifikasi = "terverifikasi"
	GeraiDitolak       = "ditolak"
	GeraiNonaktif      = "nonaktif"
)

// StatusGerai status verifikasi yang ditampilkan ke mitra
type StatusGerai struct {
	Status string  `json:"status"`
	Alasan *string `json:"alasan"`
}

// MitraAdmin satu baris di daftar mitra halaman admin
type MitraAdmin struct {
	ID          string    `json:"id"`
	Nama        string    `json:"nama"`
	Email       string    `json:"email"`
	Jenis       string    `json:"jenis"`
	Alamat      string    `json:"alamat"`
	Status      string    `json:"status"`
	Alasan      *string   `json:"alasan"`
	JumlahPaket int       `json:"jumlahPaket"`
	Daftar      time.Time `json:"daftar"`
}

// StoreVerifikasi bagian Store buat verifikasi mitra
type StoreVerifikasi interface {
	StatusGerai(ctx context.Context, idMitra string) (StatusGerai, error)
	// DaftarMitra semua akun mitra, [status] kosong = semua status
	DaftarMitra(ctx context.Context, status string) ([]MitraAdmin, error)
	// PeriksaMitra ngubah status gerai. ErrTidakAda kalau [idMitra] bukan akun mitra
	PeriksaMitra(ctx context.Context, idMitra, status string, alasan *string, sekarang time.Time) error
}

var errBukanAdmin = galat(http.StatusForbidden, "Fitur ini khusus admin Sisa Rasa.")

// StatusSaya status verifikasi gerai mitra yang lagi masuk
func (l *Layanan) StatusSaya(ctx context.Context, a akun.Akun) (StatusGerai, error) {
	if a.Peran != "mitra" {
		return StatusGerai{}, errBukanMitra
	}
	return l.Store.StatusGerai(ctx, a.ID)
}

// DaftarMitra F-37: admin liat mitra, misal yang lagi nunggu verifikasi
func (l *Layanan) DaftarMitra(ctx context.Context, a akun.Akun, status string) ([]MitraAdmin, error) {
	if a.Peran != "admin" {
		return nil, errBukanAdmin
	}
	if status != "" && !slices.Contains([]string{GeraiMenunggu, GeraiTerverifikasi, GeraiDitolak, GeraiNonaktif}, status) {
		return nil, galat(http.StatusBadRequest, "Status tidak dikenal.")
	}
	return l.Store.DaftarMitra(ctx, status)
}

// PeriksaMitra F-37, F-38: setujui, tolak, atau nonaktifkan mitra.
// ditolak / nonaktif wajib pakai alasan, biar mitranya tau harus benerin apa
func (l *Layanan) PeriksaMitra(ctx context.Context, a akun.Akun, idMitra, status, alasan string) (StatusGerai, error) {
	if a.Peran != "admin" {
		return StatusGerai{}, errBukanAdmin
	}
	if !idSah(idMitra) {
		return StatusGerai{}, errTidakAda
	}
	var catatan *string
	switch status {
	case GeraiTerverifikasi:
	case GeraiDitolak, GeraiNonaktif:
		alasan = strings.TrimSpace(alasan)
		if alasan == "" || len([]rune(alasan)) > 300 {
			return StatusGerai{}, galat(http.StatusUnprocessableEntity, "Tulis alasannya (paling panjang 300 huruf).")
		}
		catatan = &alasan
	default:
		return StatusGerai{}, galat(http.StatusUnprocessableEntity, "Status harus terverifikasi, ditolak, atau nonaktif.")
	}
	if _, err := tanganiTidakAda(StatusGerai{}, l.Store.PeriksaMitra(ctx, idMitra, status, catatan, l.sekarang())); err != nil {
		return StatusGerai{}, err
	}
	return StatusGerai{Status: status, Alasan: catatan}, nil
}
