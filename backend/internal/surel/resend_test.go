package surel

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestKirim(t *testing.T) {
	var isi map[string]any
	var auth string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		auth = r.Header.Get("Authorization")
		_ = json.NewDecoder(r.Body).Decode(&isi)
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"id":"abc"}`))
	}))
	defer srv.Close()
	r := &Resend{Kunci: "re_rahasia", Dari: "Sisa Rasa <noreply@sisarasa.web.id>", URL: srv.URL}
	if err := r.Kirim(context.Background(), "rani@gmail.com", "Kode", "teks", "<p>html</p>"); err != nil {
		t.Fatal(err)
	}
	if auth != "Bearer re_rahasia" {
		t.Errorf("auth: %q", auth)
	}
	if isi["from"] != "Sisa Rasa <noreply@sisarasa.web.id>" || isi["subject"] != "Kode" {
		t.Errorf("isi: %v", isi)
	}
	if to := isi["to"].([]any); len(to) != 1 || to[0] != "rani@gmail.com" {
		t.Errorf("to: %v", isi["to"])
	}

	// ditolak Resend (domain belum diverifikasi, dll) -> galat
	gagal := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		http.Error(w, `{"message":"domain belum diverifikasi"}`, http.StatusForbidden)
	}))
	defer gagal.Close()
	r.URL = gagal.URL
	if err := r.Kirim(context.Background(), "rani@gmail.com", "Kode", "t", "h"); err == nil {
		t.Error("ditolak Resend harus galat")
	}
}
