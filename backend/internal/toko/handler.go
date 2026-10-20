package toko

import (
	"net/http"
	"time"

	"github.com/orkvacy/sisa-rasa/backend/internal/akun"
	"github.com/orkvacy/sisa-rasa/backend/internal/httpx"
)

// Pasang daftarin rute paket dan pesanan. [wajib] nolak request tanpa sesi (akun.Layanan.Wajib),
// [opsional] masang akun kalau ada token yang berlaku tapi tetap lanjut kalau ga ada
func Pasang(mux *http.ServeMux, l *Layanan, wajib, opsional func(http.Handler) http.Handler) {
	h := func(f httpx.Handler) http.Handler { return wajib(f) }

	// daftar paket boleh dilihat tamu (F-65)
	mux.Handle("GET /v1/paket", opsional(httpx.Handler(l.handlePaket)))
	mux.Handle("GET /v1/mitra/status", h(l.handleStatusGerai))
	mux.Handle("GET /v1/admin/mitra", h(l.handleDaftarMitra))
	mux.Handle("POST /v1/admin/mitra/{id}/periksa", h(l.handlePeriksaMitra))

	mux.Handle("GET /v1/mitra/paket", h(l.handlePaketSaya))
	mux.Handle("POST /v1/mitra/paket", h(l.handleBuatPaket))
	mux.Handle("PUT /v1/mitra/paket/{id}", h(l.handleUbahPaket))
	mux.Handle("DELETE /v1/mitra/paket/{id}", h(l.handleHapusPaket))
	mux.Handle("PATCH /v1/mitra/paket/{id}/sisa", h(l.handleSisa))
	mux.Handle("PATCH /v1/mitra/paket/{id}/aktif", h(l.handleAktif))
	mux.Handle("PUT /v1/mitra/gerai/tutup", h(l.handleGerai))
	mux.Handle("POST /v1/mitra/ambil", h(l.handleAmbil))
	mux.Handle("GET /v1/mitra/saldo", h(l.handleSaldo))
	mux.Handle("PUT /v1/mitra/rekening", h(l.handleRekening))

	mux.Handle("GET /v1/pesanan", h(l.handleDaftar))
	mux.Handle("POST /v1/pesanan", h(l.handleBuat))
	mux.Handle("GET /v1/pesanan/{id}", h(l.handleSatu))
	mux.Handle("POST /v1/pesanan/{id}/cek-bayar", h(l.handleCekBayar))
	mux.Handle("POST /v1/pesanan/{id}/batal", h(l.handleBatal))
	mux.Handle("POST /v1/pesanan/{id}/metode", h(l.handleMetode))
	mux.Handle("POST /v1/pesanan/{id}/status", h(l.handleStatus))
	mux.Handle("POST /v1/pesanan/{id}/batal-mitra", h(l.handleBatalMitra))

	// percakapan per pesanan (F-67 s.d. F-70)
	mux.Handle("GET /v1/pesanan/{id}/pesan", h(l.handleRiwayatChat))
	mux.Handle("POST /v1/pesanan/{id}/pesan", h(l.handleKirimChat))
	mux.Handle("POST /v1/pesanan/{id}/pesan/dibaca", h(l.handleBacaChat))
	mux.Handle("GET /v1/pesan/baru", h(l.handleChatBaru))
}

func tulisPaket(w http.ResponseWriter, kode int, p Paket, err error) error {
	if err != nil {
		return err
	}
	httpx.TulisJSON(w, kode, map[string]Paket{"paket": p})
	return nil
}

func tulisPesanan(w http.ResponseWriter, p Pesanan, err error) error {
	if err != nil {
		return err
	}
	httpx.TulisJSON(w, http.StatusOK, map[string]Pesanan{"pesanan": p})
	return nil
}

// ---------- paket ----------

func (l *Layanan) handlePaket(w http.ResponseWriter, r *http.Request) error {
	daftar, err := l.DaftarPaket(r.Context(), akun.DariKonteks(r.Context()))
	if err != nil {
		return err
	}
	httpx.TulisJSON(w, http.StatusOK, map[string][]Paket{"paket": daftar})
	return nil
}

func (l *Layanan) handlePaketSaya(w http.ResponseWriter, r *http.Request) error {
	daftar, err := l.PaketSaya(r.Context(), akun.DariKonteks(r.Context()))
	if err != nil {
		return err
	}
	httpx.TulisJSON(w, http.StatusOK, map[string][]Paket{"paket": daftar})
	return nil
}

func (l *Layanan) handleBuatPaket(w http.ResponseWriter, r *http.Request) error {
	var isi IsianPaket
	if err := httpx.BacaJSON(w, r, &isi); err != nil {
		return err
	}
	p, err := l.BuatPaket(r.Context(), akun.DariKonteks(r.Context()), isi)
	return tulisPaket(w, http.StatusCreated, p, err)
}

func (l *Layanan) handleUbahPaket(w http.ResponseWriter, r *http.Request) error {
	var isi IsianPaket
	if err := httpx.BacaJSON(w, r, &isi); err != nil {
		return err
	}
	p, err := l.UbahPaket(r.Context(), akun.DariKonteks(r.Context()), r.PathValue("id"), isi)
	return tulisPaket(w, http.StatusOK, p, err)
}

func (l *Layanan) handleHapusPaket(w http.ResponseWriter, r *http.Request) error {
	if err := l.HapusPaket(r.Context(), akun.DariKonteks(r.Context()), r.PathValue("id")); err != nil {
		return err
	}
	w.WriteHeader(http.StatusNoContent)
	return nil
}

func (l *Layanan) handleSisa(w http.ResponseWriter, r *http.Request) error {
	var isi struct {
		Sisa int `json:"sisa"`
	}
	if err := httpx.BacaJSON(w, r, &isi); err != nil {
		return err
	}
	p, err := l.AturSisa(r.Context(), akun.DariKonteks(r.Context()), r.PathValue("id"), isi.Sisa)
	return tulisPaket(w, http.StatusOK, p, err)
}

func (l *Layanan) handleAktif(w http.ResponseWriter, r *http.Request) error {
	var isi struct {
		Aktif bool `json:"aktif"`
	}
	if err := httpx.BacaJSON(w, r, &isi); err != nil {
		return err
	}
	p, err := l.AturAktif(r.Context(), akun.DariKonteks(r.Context()), r.PathValue("id"), isi.Aktif)
	return tulisPaket(w, http.StatusOK, p, err)
}

func (l *Layanan) handleGerai(w http.ResponseWriter, r *http.Request) error {
	var isi struct {
		Tutup bool `json:"tutup"`
	}
	if err := httpx.BacaJSON(w, r, &isi); err != nil {
		return err
	}
	if err := l.AturGerai(r.Context(), akun.DariKonteks(r.Context()), isi.Tutup); err != nil {
		return err
	}
	w.WriteHeader(http.StatusNoContent)
	return nil
}

func (l *Layanan) handleAmbil(w http.ResponseWriter, r *http.Request) error {
	var isi struct {
		Kode string `json:"kode"`
	}
	if err := httpx.BacaJSON(w, r, &isi); err != nil {
		return err
	}
	p, err := l.AmbilDenganKode(r.Context(), akun.DariKonteks(r.Context()), isi.Kode)
	return tulisPesanan(w, p, err)
}

// ---------- pesanan ----------

func (l *Layanan) handleDaftar(w http.ResponseWriter, r *http.Request) error {
	daftar, err := l.Daftar(r.Context(), akun.DariKonteks(r.Context()))
	if err != nil {
		return err
	}
	httpx.TulisJSON(w, http.StatusOK, map[string][]Pesanan{"pesanan": daftar})
	return nil
}

func (l *Layanan) handleBuat(w http.ResponseWriter, r *http.Request) error {
	var isi struct {
		Isi    map[string]int `json:"isi"`
		Metode string         `json:"metode"`
	}
	if err := httpx.BacaJSON(w, r, &isi); err != nil {
		return err
	}
	p, dibuat, err := l.BuatPesanan(r.Context(), akun.DariKonteks(r.Context()),
		isi.Isi, isi.Metode, r.Header.Get("Idempotency-Key"))
	if err != nil {
		return err
	}
	kode := http.StatusOK // request ulang: pesanan lama dibalikin apa adanya
	if dibuat {
		kode = http.StatusCreated
	}
	httpx.TulisJSON(w, kode, map[string]Pesanan{"pesanan": p})
	return nil
}

func (l *Layanan) handleSatu(w http.ResponseWriter, r *http.Request) error {
	p, err := l.Satu(r.Context(), akun.DariKonteks(r.Context()), r.PathValue("id"))
	return tulisPesanan(w, p, err)
}

func (l *Layanan) handleCekBayar(w http.ResponseWriter, r *http.Request) error {
	p, err := l.CekBayar(r.Context(), akun.DariKonteks(r.Context()), r.PathValue("id"))
	return tulisPesanan(w, p, err)
}

func (l *Layanan) handleBatal(w http.ResponseWriter, r *http.Request) error {
	var isi struct {
		Alasan   string `json:"alasan"`
		Otomatis bool   `json:"otomatis"`
	}
	if err := httpx.BacaJSON(w, r, &isi); err != nil {
		return err
	}
	p, err := l.Batal(r.Context(), akun.DariKonteks(r.Context()), r.PathValue("id"), isi.Alasan, isi.Otomatis)
	return tulisPesanan(w, p, err)
}

func (l *Layanan) handleMetode(w http.ResponseWriter, r *http.Request) error {
	var isi struct {
		Metode string `json:"metode"`
	}
	if err := httpx.BacaJSON(w, r, &isi); err != nil {
		return err
	}
	p, err := l.GantiMetode(r.Context(), akun.DariKonteks(r.Context()), r.PathValue("id"), isi.Metode)
	return tulisPesanan(w, p, err)
}

func (l *Layanan) handleStatus(w http.ResponseWriter, r *http.Request) error {
	var isi struct {
		Status string `json:"status"`
	}
	if err := httpx.BacaJSON(w, r, &isi); err != nil {
		return err
	}
	p, err := l.UbahStatus(r.Context(), akun.DariKonteks(r.Context()), r.PathValue("id"), isi.Status)
	return tulisPesanan(w, p, err)
}

func (l *Layanan) handleBatalMitra(w http.ResponseWriter, r *http.Request) error {
	var isi struct {
		Alasan string `json:"alasan"`
	}
	if err := httpx.BacaJSON(w, r, &isi); err != nil {
		return err
	}
	p, err := l.BatalMitra(r.Context(), akun.DariKonteks(r.Context()), r.PathValue("id"), isi.Alasan)
	return tulisPesanan(w, p, err)
}

// ---------- percakapan ----------

func (l *Layanan) handleRiwayatChat(w http.ResponseWriter, r *http.Request) error {
	daftar, err := l.RiwayatChat(r.Context(), akun.DariKonteks(r.Context()), r.PathValue("id"))
	if err != nil {
		return err
	}
	httpx.TulisJSON(w, http.StatusOK, map[string][]PesanChat{"pesan": daftar})
	return nil
}

func (l *Layanan) handleKirimChat(w http.ResponseWriter, r *http.Request) error {
	var isi struct {
		ID   string `json:"id"`
		Teks string `json:"teks"`
	}
	if err := httpx.BacaJSON(w, r, &isi); err != nil {
		return err
	}
	p, err := l.KirimChat(r.Context(), akun.DariKonteks(r.Context()), r.PathValue("id"), isi.ID, isi.Teks)
	if err != nil {
		return err
	}
	httpx.TulisJSON(w, http.StatusOK, map[string]PesanChat{"pesan": p})
	return nil
}

func (l *Layanan) handleBacaChat(w http.ResponseWriter, r *http.Request) error {
	if err := l.BacaChat(r.Context(), akun.DariKonteks(r.Context()), r.PathValue("id")); err != nil {
		return err
	}
	w.WriteHeader(http.StatusNoContent)
	return nil
}

// GET /v1/pesan/baru?setelah=2026-10-20T08:20:00Z. tanpa setelah = semua
func (l *Layanan) handleChatBaru(w http.ResponseWriter, r *http.Request) error {
	var setelah time.Time
	if v := r.URL.Query().Get("setelah"); v != "" {
		t, err := time.Parse(time.RFC3339Nano, v)
		if err != nil {
			return httpx.NewGalat(http.StatusBadRequest, "Format waktu tidak valid.")
		}
		setelah = t
	}
	daftar, sekarang, err := l.ChatBaru(r.Context(), akun.DariKonteks(r.Context()), setelah)
	if err != nil {
		return err
	}
	httpx.TulisJSON(w, http.StatusOK, map[string]any{"pesan": daftar, "sekarang": sekarang})
	return nil
}

// ---------- saldo ----------

func (l *Layanan) handleSaldo(w http.ResponseWriter, r *http.Request) error {
	saldo, err := l.SaldoSaya(r.Context(), akun.DariKonteks(r.Context()))
	if err != nil {
		return err
	}
	httpx.TulisJSON(w, http.StatusOK, saldo)
	return nil
}

func (l *Layanan) handleRekening(w http.ResponseWriter, r *http.Request) error {
	var isi Rekening
	if err := httpx.BacaJSON(w, r, &isi); err != nil {
		return err
	}
	rek, err := l.SimpanRekening(r.Context(), akun.DariKonteks(r.Context()), isi)
	if err != nil {
		return err
	}
	httpx.TulisJSON(w, http.StatusOK, map[string]Rekening{"rekening": rek})
	return nil
}

// ---------- verifikasi mitra ----------

func (l *Layanan) handleStatusGerai(w http.ResponseWriter, r *http.Request) error {
	st, err := l.StatusSaya(r.Context(), akun.DariKonteks(r.Context()))
	if err != nil {
		return err
	}
	httpx.TulisJSON(w, http.StatusOK, st)
	return nil
}

func (l *Layanan) handleDaftarMitra(w http.ResponseWriter, r *http.Request) error {
	daftar, err := l.DaftarMitra(r.Context(), akun.DariKonteks(r.Context()), r.URL.Query().Get("status"))
	if err != nil {
		return err
	}
	httpx.TulisJSON(w, http.StatusOK, map[string][]MitraAdmin{"mitra": daftar})
	return nil
}

func (l *Layanan) handlePeriksaMitra(w http.ResponseWriter, r *http.Request) error {
	var isi struct {
		Status string `json:"status"`
		Alasan string `json:"alasan"`
	}
	if err := httpx.BacaJSON(w, r, &isi); err != nil {
		return err
	}
	st, err := l.PeriksaMitra(r.Context(), akun.DariKonteks(r.Context()), r.PathValue("id"), isi.Status, isi.Alasan)
	if err != nil {
		return err
	}
	httpx.TulisJSON(w, http.StatusOK, st)
	return nil
}
