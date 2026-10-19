// Server Sisa Rasa: REST API buat aplikasi mobile.
//
// jalanin di laptop:
//
//	$env:DATABASE_URL = "postgres://postgres:SANDI@localhost:5432/sisarasa_dev?sslmode=disable"
//	go run ./cmd/server
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/orkvacy/sisa-rasa/backend/internal/akun"
	"github.com/orkvacy/sisa-rasa/backend/internal/config"
	"github.com/orkvacy/sisa-rasa/backend/internal/db"
	"github.com/orkvacy/sisa-rasa/backend/internal/httpx"
)

func main() {
	if err := jalan(); err != nil {
		slog.Error("server berhenti", "galat", err)
		os.Exit(1)
	}
}

func jalan() error {
	cfg, err := config.Baca()
	if err != nil {
		return err
	}
	ctx, berhenti := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer berhenti()

	pool, err := db.Buka(ctx, cfg.DatabaseURL)
	if err != nil {
		return err
	}
	defer pool.Close()
	if err := db.Migrasi(ctx, pool); err != nil {
		return err
	}

	layananAkun := &akun.Layanan{Store: akun.StorePG{Pool: pool}}
	if cfg.SemaiAkunContoh {
		if err := akun.SemaiContoh(ctx, layananAkun); err != nil {
			return err
		}
		slog.Info("akun contoh siap", "sandi", akun.SandiContoh)
	}

	mux := http.NewServeMux()
	mux.Handle("GET /healthz", httpx.Handler(func(w http.ResponseWriter, r *http.Request) error {
		if err := pool.Ping(r.Context()); err != nil {
			return err
		}
		httpx.TulisJSON(w, http.StatusOK, map[string]string{"status": "ok"})
		return nil
	}))
	// masuk / daftar: 10 kali per menit per IP (NF-13)
	batasAkun := httpx.NewPembatas(10, time.Minute, cfg.DiBelakangProxy)
	akun.Pasang(mux, layananAkun, batasAkun.Bungkus)

	var handler http.Handler = mux
	if len(cfg.AsalWeb) > 0 {
		// aplikasi versi web (flutter web) beda origin sama server
		handler = httpx.CORS(cfg.AsalWeb, handler)
	}
	server := &http.Server{
		Addr:              cfg.Alamat,
		Handler:           httpx.Pulihkan(httpx.Catat(handler)),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       2 * time.Minute,
	}

	galat := make(chan error, 1)
	go func() {
		slog.Info("server jalan", "alamat", cfg.Alamat, "lingkungan", cfg.Lingkungan)
		galat <- server.ListenAndServe()
	}()

	select {
	case err := <-galat:
		if !errors.Is(err, http.ErrServerClosed) {
			return err
		}
	case <-ctx.Done():
		slog.Info("mematikan server...")
	}
	// kasih waktu request yang lagi jalan buat selesai
	tutup, batal := context.WithTimeout(context.Background(), 10*time.Second)
	defer batal()
	return server.Shutdown(tutup)
}
