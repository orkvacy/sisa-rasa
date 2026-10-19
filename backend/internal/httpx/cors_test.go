package httpx

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestCORS(t *testing.T) {
	ok := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	h := CORS([]string{"https://app.sisarasa.id"}, ok)

	panggil := func(metode, origin string) *httptest.ResponseRecorder {
		r := httptest.NewRequest(metode, "/v1/akun/saya", nil)
		if origin != "" {
			r.Header.Set("Origin", origin)
		}
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)
		return w
	}

	// origin yang terdaftar dapet header, preflight dijawab 204
	w := panggil(http.MethodOptions, "https://app.sisarasa.id")
	if w.Code != http.StatusNoContent || w.Header().Get("Access-Control-Allow-Origin") != "https://app.sisarasa.id" {
		t.Fatalf("preflight origin terdaftar: kode %d, header %q", w.Code, w.Header().Get("Access-Control-Allow-Origin"))
	}

	// origin lain ga dapet header CORS, request tetap diterusin
	w = panggil(http.MethodGet, "https://jahat.example")
	if w.Header().Get("Access-Control-Allow-Origin") != "" || w.Code != http.StatusOK {
		t.Fatalf("origin asing: kode %d, header %q", w.Code, w.Header().Get("Access-Control-Allow-Origin"))
	}

	// aplikasi HP ga ngirim Origin sama sekali
	if w = panggil(http.MethodGet, ""); w.Code != http.StatusOK {
		t.Fatalf("tanpa origin: kode %d", w.Code)
	}
}
