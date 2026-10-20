package akun

import (
	"context"
	"crypto"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"slices"
	"strconv"
	"strings"
	"sync"
	"time"
)

// IdentitasGoogle isi ID token Google yang udah lolos pemeriksaan
type IdentitasGoogle struct {
	// Sub id akun Google, tetap walau emailnya diganti
	Sub   string
	Email string
	Nama  string
}

// Google pemeriksa ID token Google Sign-In. dipisah jadi interface biar tes
// ga perlu nyambung ke Google
type Google interface {
	Periksa(ctx context.Context, idToken string) (IdentitasGoogle, error)
}

// errTokenGoogle token palsu, kedaluwarsa, atau bukan buat aplikasi ini
var errTokenGoogle = errors.New("token google tidak berlaku")

// PemeriksaGoogle meriksa ID token pakai kunci publik Google (JWKS).
// ga ada secret di sini: client ID memang publik, tanda tangannya yang dicek
type PemeriksaGoogle struct {
	// ClientID web client ID dari Google Cloud, aud token harus salah satunya
	ClientID []string
	// URLKunci bawaannya https://www.googleapis.com/oauth2/v3/certs, diganti di tes
	URLKunci string
	Klien    *http.Client
	Jam      func() time.Time

	mu            sync.Mutex
	kunci         map[string]*rsa.PublicKey
	berlakuHabis  time.Time
	terakhirAmbil time.Time
}

// selisih jam HP / server Google yang masih dimaklumi
const kelonggaranJam = 5 * time.Minute

func (p *PemeriksaGoogle) sekarang() time.Time {
	if p.Jam != nil {
		return p.Jam()
	}
	return time.Now()
}

func (p *PemeriksaGoogle) Periksa(ctx context.Context, idToken string) (IdentitasGoogle, error) {
	bagian := strings.Split(idToken, ".")
	if len(bagian) != 3 {
		return IdentitasGoogle{}, errTokenGoogle
	}
	var kepala struct {
		Alg string `json:"alg"`
		Kid string `json:"kid"`
	}
	if err := bacaBagian(bagian[0], &kepala); err != nil || kepala.Alg != "RS256" {
		return IdentitasGoogle{}, errTokenGoogle
	}
	kunci, err := p.kunciUntuk(ctx, kepala.Kid)
	if err != nil {
		return IdentitasGoogle{}, err
	}
	tanda, err := base64.RawURLEncoding.DecodeString(bagian[2])
	if err != nil {
		return IdentitasGoogle{}, errTokenGoogle
	}
	ringkas := sha256.Sum256([]byte(bagian[0] + "." + bagian[1]))
	if rsa.VerifyPKCS1v15(kunci, crypto.SHA256, ringkas[:], tanda) != nil {
		return IdentitasGoogle{}, errTokenGoogle
	}

	var isi struct {
		Iss           string          `json:"iss"`
		Aud           string          `json:"aud"`
		Sub           string          `json:"sub"`
		Email         string          `json:"email"`
		EmailVerified json.RawMessage `json:"email_verified"`
		Name          string          `json:"name"`
		Exp           int64           `json:"exp"`
		Iat           int64           `json:"iat"`
	}
	if err := bacaBagian(bagian[1], &isi); err != nil {
		return IdentitasGoogle{}, errTokenGoogle
	}
	kini := p.sekarang()
	// email_verified kadang boolean, kadang string "true"
	terverifikasi := string(isi.EmailVerified) == "true" || string(isi.EmailVerified) == `"true"`
	switch {
	case isi.Iss != "accounts.google.com" && isi.Iss != "https://accounts.google.com",
		!slices.Contains(p.ClientID, isi.Aud),
		isi.Sub == "",
		!terverifikasi,
		kini.After(time.Unix(isi.Exp, 0).Add(kelonggaranJam)),
		time.Unix(isi.Iat, 0).After(kini.Add(kelonggaranJam)):
		return IdentitasGoogle{}, errTokenGoogle
	}
	return IdentitasGoogle{Sub: isi.Sub, Email: rapikanEmail(isi.Email), Nama: isi.Name}, nil
}

func bacaBagian(bagian string, ke any) error {
	b, err := base64.RawURLEncoding.DecodeString(bagian)
	if err != nil {
		return err
	}
	return json.Unmarshal(b, ke)
}

// kunciUntuk kunci publik dengan id [kid]. disimpan sesuai Cache-Control dari
// Google, diambil ulang kalau kid-nya belum dikenal (Google lagi ganti kunci),
// tapi paling sering semenit sekali biar token asal-asalan ga bikin banjir request
func (p *PemeriksaGoogle) kunciUntuk(ctx context.Context, kid string) (*rsa.PublicKey, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	kini := p.sekarang()
	if k, ada := p.kunci[kid]; ada && kini.Before(p.berlakuHabis) {
		return k, nil
	}
	if kini.Sub(p.terakhirAmbil) < time.Minute && kini.Before(p.berlakuHabis) {
		return nil, errTokenGoogle
	}
	if err := p.ambilKunci(ctx, kini); err != nil {
		return nil, err
	}
	if k, ada := p.kunci[kid]; ada {
		return k, nil
	}
	return nil, errTokenGoogle
}

func (p *PemeriksaGoogle) ambilKunci(ctx context.Context, kini time.Time) error {
	url := p.URLKunci
	if url == "" {
		url = "https://www.googleapis.com/oauth2/v3/certs"
	}
	klien := p.Klien
	if klien == nil {
		klien = &http.Client{Timeout: 10 * time.Second}
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	res, err := klien.Do(req)
	if err != nil {
		return fmt.Errorf("ambil kunci google: %w", err)
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return fmt.Errorf("ambil kunci google: status %d", res.StatusCode)
	}
	var jwks struct {
		Keys []struct {
			Kid string `json:"kid"`
			Kty string `json:"kty"`
			N   string `json:"n"`
			E   string `json:"e"`
		} `json:"keys"`
	}
	if err := json.NewDecoder(res.Body).Decode(&jwks); err != nil {
		return fmt.Errorf("baca kunci google: %w", err)
	}
	kunci := map[string]*rsa.PublicKey{}
	for _, k := range jwks.Keys {
		if k.Kty != "RSA" {
			continue
		}
		n, err1 := base64.RawURLEncoding.DecodeString(k.N)
		e, err2 := base64.RawURLEncoding.DecodeString(k.E)
		if err1 != nil || err2 != nil || len(e) > 4 {
			continue
		}
		kunci[k.Kid] = &rsa.PublicKey{
			N: new(big.Int).SetBytes(n),
			E: int(new(big.Int).SetBytes(e).Int64()),
		}
	}
	p.kunci = kunci
	p.terakhirAmbil = kini
	p.berlakuHabis = kini.Add(umurCache(res.Header.Get("Cache-Control")))
	return nil
}

// max-age dari Cache-Control, bawaannya sejam
func umurCache(nilai string) time.Duration {
	for _, bagian := range strings.Split(nilai, ",") {
		if detik, ok := strings.CutPrefix(strings.TrimSpace(bagian), "max-age="); ok {
			if n, err := strconv.Atoi(detik); err == nil && n > 0 {
				return time.Duration(n) * time.Second
			}
		}
	}
	return time.Hour
}
