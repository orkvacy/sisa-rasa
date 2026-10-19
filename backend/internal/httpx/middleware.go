package httpx

import (
	"log/slog"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"

	"golang.org/x/time/rate"
)

// Catat nulis satu baris log per request
func Catat(berikut http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mulai := time.Now()
		rek := &perekam{ResponseWriter: w, kode: http.StatusOK}
		berikut.ServeHTTP(rek, r)
		slog.Info("request", "metode", r.Method, "jalur", r.URL.Path,
			"kode", rek.kode, "durasi", time.Since(mulai).Round(time.Millisecond))
	})
}

type perekam struct {
	http.ResponseWriter
	kode int
}

func (p *perekam) WriteHeader(kode int) {
	p.kode = kode
	p.ResponseWriter.WriteHeader(kode)
}

// Pulihkan nangkep panic di handler, biar satu request rusak ga matiin server
func Pulihkan(berikut http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if p := recover(); p != nil {
				slog.Error("panic", "jalur", r.URL.Path, "isi", p)
				TulisJSON(w, http.StatusInternalServerError,
					map[string]string{"pesan": "Terjadi gangguan di server. Coba lagi sebentar."})
			}
		}()
		berikut.ServeHTTP(w, r)
	})
}

// IPKlien alamat IP pengirim. kalau server di belakang proxy (Coolify/Traefik),
// IP aslinya ada di X-Forwarded-For paling kiri
func IPKlien(r *http.Request, diBelakangProxy bool) string {
	if diBelakangProxy {
		if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
			return strings.TrimSpace(strings.Split(xff, ",")[0])
		}
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

// Pembatas batasin jumlah request per IP (NF-13). lewat batas dibales 429
type Pembatas struct {
	per             rate.Limit
	ledakan         int
	diBelakangProxy bool

	mu     sync.Mutex
	daftar map[string]*catatanIP
}

type catatanIP struct {
	limiter  *rate.Limiter
	terakhir time.Time
}

// NewPembatas: [jumlah] request per [selang], boleh numpuk sampai [jumlah] sekaligus
func NewPembatas(jumlah int, selang time.Duration, diBelakangProxy bool) *Pembatas {
	return &Pembatas{
		per:             rate.Every(selang / time.Duration(jumlah)),
		ledakan:         jumlah,
		diBelakangProxy: diBelakangProxy,
		daftar:          map[string]*catatanIP{},
	}
}

func (p *Pembatas) izinkan(ip string) bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	sekarang := time.Now()
	c, ada := p.daftar[ip]
	if !ada {
		c = &catatanIP{limiter: rate.NewLimiter(p.per, p.ledakan)}
		p.daftar[ip] = c
		// bersihin IP yg udah lama ga muncul, biar map-nya ga gede terus
		if len(p.daftar) > 10_000 {
			for k, v := range p.daftar {
				if sekarang.Sub(v.terakhir) > time.Hour {
					delete(p.daftar, k)
				}
			}
		}
	}
	c.terakhir = sekarang
	return c.limiter.Allow()
}

func (p *Pembatas) Bungkus(berikut http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !p.izinkan(IPKlien(r, p.diBelakangProxy)) {
			w.Header().Set("Retry-After", "60")
			TulisJSON(w, http.StatusTooManyRequests,
				map[string]string{"pesan": "Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi."})
			return
		}
		berikut.ServeHTTP(w, r)
	})
}
