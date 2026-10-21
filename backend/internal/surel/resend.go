// Package surel kirim email lewat Resend (resend.com). dipakai buat kode
// atur ulang kata sandi (F-61). kunci API-nya rahasia, cuma ada di env server
package surel

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"time"
)

// Resend pengirim email. Dari harus alamat di domain yang udah diverifikasi
// di dashboard Resend, misal "Sisa Rasa <noreply@sisarasa.web.id>"
type Resend struct {
	Kunci string
	Dari  string
	// URL buat tes, kosong = https://api.resend.com/emails
	URL  string
	HTTP *http.Client
}

func (r *Resend) Kirim(ctx context.Context, ke, subjek, teks, html string) error {
	b, err := json.Marshal(map[string]any{
		"from": r.Dari, "to": []string{ke}, "subject": subjek, "text": teks, "html": html,
	})
	if err != nil {
		return err
	}
	url := r.URL
	if url == "" {
		url = "https://api.resend.com/emails"
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(b))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+r.Kunci)
	req.Header.Set("Content-Type", "application/json")
	klien := r.HTTP
	if klien == nil {
		klien = &http.Client{Timeout: 15 * time.Second}
	}
	res, err := klien.Do(req)
	if err != nil {
		return fmt.Errorf("resend: %w", err)
	}
	defer res.Body.Close()
	if res.StatusCode >= 300 {
		isi, _ := io.ReadAll(io.LimitReader(res.Body, 2048))
		return fmt.Errorf("resend: HTTP %d: %s", res.StatusCode, isi)
	}
	return nil
}

// Log ga ngirim email beneran, cuma nulis ke log server. khusus dev di laptop
type Log struct{}

func (Log) Kirim(_ context.Context, ke, subjek, _, _ string) error {
	slog.Info("email (dev, ga dikirim)", "ke", ke, "subjek", subjek)
	return nil
}
