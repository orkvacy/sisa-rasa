package httpx

import (
	"net/http"
	"slices"
)

// CORS ngizinin aplikasi versi web (flutter web, beda domain) manggil server.
// asal berisi origin yang boleh, misal "https://app.sisarasa.id"; "*" = semua
// (cuma buat dev). aplikasi Android/iOS ga butuh CORS sama sekali
func CORS(asal []string, berikut http.Handler) http.Handler {
	semua := slices.Contains(asal, "*")
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h := w.Header()
		origin := r.Header.Get("Origin")
		switch {
		case semua:
			h.Set("Access-Control-Allow-Origin", "*")
		case origin != "" && slices.Contains(asal, origin):
			h.Set("Access-Control-Allow-Origin", origin)
			h.Add("Vary", "Origin")
		default:
			// origin lain ga dikasih header CORS, browser yg nolak
			berikut.ServeHTTP(w, r)
			return
		}
		h.Set("Access-Control-Allow-Headers", "Authorization, Content-Type, Idempotency-Key")
		h.Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		berikut.ServeHTTP(w, r)
	})
}
