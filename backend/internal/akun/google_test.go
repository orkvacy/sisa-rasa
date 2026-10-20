package akun

import (
	"context"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"math/big"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

// googlePalsu: token -> identitas, token lain ditolak
type googlePalsu map[string]IdentitasGoogle

func (g googlePalsu) Periksa(_ context.Context, token string) (IdentitasGoogle, error) {
	id, ada := g[token]
	if !ada {
		return IdentitasGoogle{}, errTokenGoogle
	}
	return id, nil
}

// tandaTangani bikin JWT RS256 kayak buatan Google
func tandaTangani(t *testing.T, kunci *rsa.PrivateKey, kid string, isi map[string]any) string {
	t.Helper()
	b64 := func(v any) string {
		b, _ := json.Marshal(v)
		return base64.RawURLEncoding.EncodeToString(b)
	}
	awal := b64(map[string]string{"alg": "RS256", "kid": kid, "typ": "JWT"}) + "." + b64(isi)
	ringkas := sha256.Sum256([]byte(awal))
	tanda, err := rsa.SignPKCS1v15(rand.Reader, kunci, crypto.SHA256, ringkas[:])
	if err != nil {
		t.Fatal(err)
	}
	return awal + "." + base64.RawURLEncoding.EncodeToString(tanda)
}

func TestPemeriksaGoogle(t *testing.T) {
	kunci, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	lain, _ := rsa.GenerateKey(rand.Reader, 2048)
	var diambil atomic.Int32
	jwks := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		diambil.Add(1)
		w.Header().Set("Cache-Control", "public, max-age=3600")
		_ = json.NewEncoder(w).Encode(map[string]any{"keys": []map[string]string{{
			"kid": "k1", "kty": "RSA", "alg": "RS256",
			"n": base64.RawURLEncoding.EncodeToString(kunci.N.Bytes()),
			"e": base64.RawURLEncoding.EncodeToString(big.NewInt(int64(kunci.E)).Bytes()),
		}}})
	}))
	defer jwks.Close()

	kini := time.Date(2026, 10, 21, 8, 0, 0, 0, time.UTC)
	p := &PemeriksaGoogle{ClientID: []string{"web.apps.googleusercontent.com"}, URLKunci: jwks.URL,
		Jam: func() time.Time { return kini }}
	klaim := func(ubah func(map[string]any)) map[string]any {
		k := map[string]any{
			"iss": "https://accounts.google.com", "aud": "web.apps.googleusercontent.com",
			"sub": "1234567890", "email": "Rani@Gmail.com", "email_verified": true,
			"name": "Rani Amelia", "iat": kini.Unix() - 10, "exp": kini.Unix() + 3600,
		}
		if ubah != nil {
			ubah(k)
		}
		return k
	}
	ctx := context.Background()

	id, err := p.Periksa(ctx, tandaTangani(t, kunci, "k1", klaim(nil)))
	if err != nil || id.Sub != "1234567890" || id.Email != "rani@gmail.com" || id.Nama != "Rani Amelia" {
		t.Fatalf("token sah: %+v %v", id, err)
	}
	// email_verified versi string juga diterima
	if _, err := p.Periksa(ctx, tandaTangani(t, kunci, "k1", klaim(func(k map[string]any) { k["email_verified"] = "true" }))); err != nil {
		t.Errorf("email_verified string: %v", err)
	}

	ditolak := map[string]string{
		"aud lain":        tandaTangani(t, kunci, "k1", klaim(func(k map[string]any) { k["aud"] = "aplikasi-lain" })),
		"iss palsu":       tandaTangani(t, kunci, "k1", klaim(func(k map[string]any) { k["iss"] = "https://palsu.com" })),
		"kedaluwarsa":     tandaTangani(t, kunci, "k1", klaim(func(k map[string]any) { k["exp"] = kini.Unix() - 600 })),
		"email belum cek": tandaTangani(t, kunci, "k1", klaim(func(k map[string]any) { k["email_verified"] = false })),
		"tanpa sub":       tandaTangani(t, kunci, "k1", klaim(func(k map[string]any) { delete(k, "sub") })),
		"kunci lain":      tandaTangani(t, lain, "k1", klaim(nil)),
		"kid ga dikenal":  tandaTangani(t, kunci, "k9", klaim(nil)),
		"bukan jwt":       "abc.def",
		"alg none":        "eyJhbGciOiJub25lIn0." + strings.Split(tandaTangani(t, kunci, "k1", klaim(nil)), ".")[1] + ".",
	}
	for nama, token := range ditolak {
		if _, err := p.Periksa(ctx, token); err != errTokenGoogle {
			t.Errorf("%s: harus ditolak, dapet %v", nama, err)
		}
	}
	// kunci di-cache: kid ga dikenal ga bikin ngambil ulang tiap request
	if n := diambil.Load(); n != 1 {
		t.Errorf("kunci diambil %d kali, harusnya sekali", n)
	}
}

func TestMasukGoogle(t *testing.T) {
	ctx := context.Background()
	l := layananTes()
	if _, err := l.MasukGoogle(ctx, "apa"); kodeGalat(t, err) != http.StatusServiceUnavailable {
		t.Errorf("tanpa GOOGLE_CLIENT_ID harus 503")
	}
	l.Google = googlePalsu{
		"tok-budi":  {Sub: "g-budi", Email: "budi@gmail.com", Nama: "  Budi   Santoso "},
		"tok-rani":  {Sub: "g-rani", Email: "rani@contoh.id", Nama: "Rani"},
		"tok-tanpa": {Sub: "g-x", Email: "xy@gmail.com", Nama: ""},
		"tok-lain":  {Sub: "g-lain", Email: "lain@gmail.com", Nama: "Lain"},
	}

	// akun baru: pembeli, tanpa sandi, nama dari Google
	budi, err := l.MasukGoogle(ctx, "tok-budi")
	if err != nil || budi.Akun.Nama != "Budi Santoso" || budi.Akun.Peran != "pembeli" || budi.Akun.PunyaSandi {
		t.Fatalf("akun baru: %+v %v", budi.Akun, err)
	}
	lagi, err := l.MasukGoogle(ctx, "tok-budi")
	if err != nil || lagi.Akun.ID != budi.Akun.ID || lagi.Token == budi.Token {
		t.Fatalf("masuk kedua harus akun yang sama, sesi baru: %+v %v", lagi.Akun, err)
	}
	if x, _ := l.MasukGoogle(ctx, "tok-tanpa"); x.Akun.Nama != "xy" {
		t.Errorf("nama kosong pakai depan email, dapet %q", x.Akun.Nama)
	}
	if _, err := l.MasukGoogle(ctx, "palsu"); kodeGalat(t, err) != http.StatusUnauthorized {
		t.Errorf("token palsu harus 401")
	}
	// akun Google ga bisa masuk pakai sandi kosong
	if _, err := l.Masuk(ctx, "budi@gmail.com", ""); kodeGalat(t, err) != http.StatusUnauthorized {
		t.Errorf("masuk sandi kosong harus 401")
	}

	// email yang udah daftar pakai sandi ga disambung otomatis
	if _, err := l.Daftar(ctx, "Rani", "rani@contoh.id", "sandiaman1", "pembeli"); err != nil {
		t.Fatal(err)
	}
	if _, err := l.MasukGoogle(ctx, "tok-rani"); kodeGalat(t, err) != http.StatusConflict {
		t.Errorf("email bersandi harus 409")
	}

	// hapus akun Google: konfirmasinya token Google akun yang sama
	if err := l.HapusAkun(ctx, budi.Akun, "", "tok-lain"); kodeGalat(t, err) != http.StatusUnauthorized {
		t.Errorf("token Google akun lain harus 401")
	}
	if err := l.HapusAkun(ctx, budi.Akun, "", ""); kodeGalat(t, err) != http.StatusUnauthorized {
		t.Errorf("tanpa token harus 401")
	}
	if err := l.HapusAkun(ctx, budi.Akun, "", "tok-budi"); err != nil {
		t.Fatal(err)
	}
	if _, err := l.Sesi(ctx, lagi.Token); err != ErrSesiTidakBerlaku {
		t.Errorf("sesi setelah hapus: %v", err)
	}
	baru, err := l.MasukGoogle(ctx, "tok-budi")
	if err != nil || baru.Akun.ID == budi.Akun.ID {
		t.Fatalf("abis dihapus masuk Google lagi = akun baru: %+v %v", baru.Akun, err)
	}
}
