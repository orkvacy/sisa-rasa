package akun

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/orkvacy/sisa-rasa/backend/internal/httpx"
)

// storeMemori pengganti Postgres di tes
type storeMemori struct {
	mu    sync.Mutex
	akun  map[string]akunTersimpan // email -> akun
	sesi  map[string]sesiMemori    // token hash -> sesi
	nomor int
}

type sesiMemori struct {
	idAkun      string
	kedaluwarsa time.Time
	dicabut     bool
}

func baruStoreMemori() *storeMemori {
	return &storeMemori{akun: map[string]akunTersimpan{}, sesi: map[string]sesiMemori{}}
}

func (s *storeMemori) BuatAkun(_ context.Context, nama, email, hash, peran string) (Akun, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ada := s.akun[email]; ada {
		return Akun{}, ErrEmailDipakai
	}
	s.nomor++
	a := Akun{ID: fmt.Sprintf("a%d", s.nomor), Nama: nama, Email: email, Peran: peran, PunyaSandi: hash != ""}
	s.akun[email] = akunTersimpan{Akun: a, HashSandi: hash}
	return a, nil
}

func (s *storeMemori) BuatAkunGoogle(ctx context.Context, nama, email, sub string) (Akun, error) {
	a, err := s.BuatAkun(ctx, nama, email, "", "pembeli")
	if err != nil {
		return a, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	t := s.akun[email]
	t.GoogleSub = sub
	s.akun[email] = t
	return a, nil
}

func (s *storeMemori) AkunDariGoogle(_ context.Context, sub string) (akunTersimpan, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, a := range s.akun {
		if a.GoogleSub == sub {
			return a, nil
		}
	}
	return akunTersimpan{}, ErrTidakAda
}

func (s *storeMemori) UbahNama(_ context.Context, id, nama string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for email, a := range s.akun {
		if a.ID == id {
			a.Nama = nama
			s.akun[email] = a
		}
	}
	return nil
}

// pesananAktif id akun yang pura-puranya masih punya pesanan berjalan
var pesananAktif = map[string]bool{}

func (s *storeMemori) HapusAkun(_ context.Context, id string, sekarang time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if pesananAktif[id] {
		return ErrPesananAktif
	}
	for email, a := range s.akun {
		if a.ID == id {
			delete(s.akun, email)
			a.Nama, a.Email, a.HashSandi = "Akun dihapus", "dihapus-"+id+"@sisarasa.invalid", "!"
			a.GoogleSub = ""
			s.akun[a.Email] = a
		}
	}
	for h, ss := range s.sesi {
		if ss.idAkun == id {
			ss.dicabut = true
			s.sesi[h] = ss
		}
	}
	return nil
}

func (s *storeMemori) AkunDariEmail(_ context.Context, email string) (akunTersimpan, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	a, ada := s.akun[email]
	if !ada {
		return a, ErrTidakAda
	}
	return a, nil
}

func (s *storeMemori) BuatSesi(_ context.Context, hash, idAkun string, kedaluwarsa time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.sesi[hash] = sesiMemori{idAkun: idAkun, kedaluwarsa: kedaluwarsa}
	return nil
}

func (s *storeMemori) AkunDariSesi(_ context.Context, hash string, sekarang time.Time) (Akun, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	ses, ada := s.sesi[hash]
	if !ada || ses.dicabut || !sekarang.Before(ses.kedaluwarsa) {
		return Akun{}, ErrTidakAda
	}
	for _, a := range s.akun {
		if a.ID == ses.idAkun {
			return a.Akun, nil
		}
	}
	return Akun{}, ErrTidakAda
}

func (s *storeMemori) CabutSesi(_ context.Context, hash string, _ time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if ses, ada := s.sesi[hash]; ada {
		ses.dicabut = true
		s.sesi[hash] = ses
	}
	return nil
}

func layananTes() *Layanan {
	return &Layanan{Store: baruStoreMemori(), BiayaBcrypt: 4}
}

func kodeGalat(t *testing.T, err error) int {
	t.Helper()
	g, ok := err.(*httpx.Galat)
	if !ok {
		t.Fatalf("galat %v bukan *httpx.Galat", err)
	}
	return g.Kode
}

func TestDaftarLaluMasuk(t *testing.T) {
	ctx := context.Background()
	l := layananTes()

	hasil, err := l.Daftar(ctx, "  Rani   Amelia ", " Rani.Amelia@Gmail.com ", "sandiaman1", "pembeli")
	if err != nil {
		t.Fatal(err)
	}
	if hasil.Akun.Nama != "Rani Amelia" || hasil.Akun.Email != "rani.amelia@gmail.com" {
		t.Errorf("nama/email ga dirapikan: %+v", hasil.Akun)
	}
	if hasil.Token == "" {
		t.Fatal("token kosong")
	}

	masuk, err := l.Masuk(ctx, "RANI.AMELIA@gmail.com", "sandiaman1")
	if err != nil {
		t.Fatal(err)
	}
	if masuk.Akun.ID != hasil.Akun.ID || masuk.Token == hasil.Token {
		t.Errorf("masuk harus akun yg sama dengan token baru")
	}
}

func TestDaftarDitolak(t *testing.T) {
	ctx := context.Background()
	l := layananTes()
	if _, err := l.Daftar(ctx, "Rani", "rani@contoh.id", "sandiaman1", "pembeli"); err != nil {
		t.Fatal(err)
	}

	kasus := []struct {
		nama, email, sandi, peran string
		kode                      int
	}{
		{"Rani", "rani@contoh.id", "sandiaman1", "pembeli", http.StatusConflict},
		{"R", "r@contoh.id", "sandiaman1", "pembeli", http.StatusUnprocessableEntity},
		{"Rani", "bukan-email", "sandiaman1", "pembeli", http.StatusUnprocessableEntity},
		{"Rani", "a@tanpatitik", "sandiaman1", "pembeli", http.StatusUnprocessableEntity},
		{"Rani", "b@contoh.id", "pendek", "pembeli", http.StatusUnprocessableEntity},
		{"Rani", "c@contoh.id", strings.Repeat("x", 73), "pembeli", http.StatusUnprocessableEntity},
		// F-36: admin ga bisa daftar lewat aplikasi
		{"Rani", "d@contoh.id", "sandiaman1", "admin", http.StatusUnprocessableEntity},
	}
	for _, k := range kasus {
		_, err := l.Daftar(ctx, k.nama, k.email, k.sandi, k.peran)
		if got := kodeGalat(t, err); got != k.kode {
			t.Errorf("%+v: kode %d, harusnya %d", k, got, k.kode)
		}
	}
}

func TestMasukGagalPesannyaSama(t *testing.T) {
	ctx := context.Background()
	l := layananTes()
	if _, err := l.Daftar(ctx, "Rani", "rani@contoh.id", "sandiaman1", "pembeli"); err != nil {
		t.Fatal(err)
	}
	_, salahSandi := l.Masuk(ctx, "rani@contoh.id", "salahsalah")
	_, tidakAda := l.Masuk(ctx, "siapa@contoh.id", "salahsalah")
	if salahSandi.Error() != tidakAda.Error() || kodeGalat(t, salahSandi) != http.StatusUnauthorized {
		t.Errorf("pesan beda: %q vs %q", salahSandi, tidakAda)
	}
}

func TestSesiKeluarDanKedaluwarsa(t *testing.T) {
	ctx := context.Background()
	sekarang := time.Date(2026, 10, 14, 16, 0, 0, 0, time.UTC)
	l := &Layanan{Store: baruStoreMemori(), BiayaBcrypt: 4, Jam: func() time.Time { return sekarang }}

	hasil, err := l.Daftar(ctx, "Ibis Hotel", "dapur@contoh.id", "sandiaman1", "mitra")
	if err != nil {
		t.Fatal(err)
	}
	if a, err := l.Sesi(ctx, hasil.Token); err != nil || a.Peran != "mitra" {
		t.Fatalf("sesi harus berlaku: %v %+v", err, a)
	}
	if _, err := l.Sesi(ctx, "token-ngasal"); err != ErrSesiTidakBerlaku {
		t.Errorf("token ngasal harus ditolak, dapet %v", err)
	}

	// kedaluwarsa setelah 30 hari
	sekarang = sekarang.Add(umurSesi)
	if _, err := l.Sesi(ctx, hasil.Token); err != ErrSesiTidakBerlaku {
		t.Errorf("sesi kedaluwarsa harus ditolak, dapet %v", err)
	}

	// F-33: keluar nyabut token
	masuk, _ := l.Masuk(ctx, "dapur@contoh.id", "sandiaman1")
	if err := l.Keluar(ctx, masuk.Token); err != nil {
		t.Fatal(err)
	}
	if _, err := l.Sesi(ctx, masuk.Token); err != ErrSesiTidakBerlaku {
		t.Errorf("token yg udah keluar harus ditolak, dapet %v", err)
	}
}

// alur lewat HTTP: daftar -> saya -> keluar -> saya ditolak
func TestHTTP(t *testing.T) {
	l := layananTes()
	mux := http.NewServeMux()
	Pasang(mux, l, func(h http.Handler) http.Handler { return h })
	srv := httptest.NewServer(mux)
	defer srv.Close()

	kirim := func(metode, jalur, token, isi string) (*http.Response, map[string]any) {
		t.Helper()
		req, _ := http.NewRequest(metode, srv.URL+jalur, strings.NewReader(isi))
		req.Header.Set("Content-Type", "application/json")
		if token != "" {
			req.Header.Set("Authorization", "Bearer "+token)
		}
		res, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		defer res.Body.Close()
		var badan map[string]any
		_ = json.NewDecoder(res.Body).Decode(&badan)
		return res, badan
	}

	res, badan := kirim("POST", "/v1/akun/daftar", "",
		`{"nama":"Dimas","email":"dimas@contoh.id","sandi":"sandiaman1","peran":"pembeli"}`)
	if res.StatusCode != http.StatusCreated {
		t.Fatalf("daftar: %d %v", res.StatusCode, badan)
	}
	token := badan["token"].(string)

	res, badan = kirim("GET", "/v1/akun/saya", token, "")
	if res.StatusCode != http.StatusOK || badan["akun"].(map[string]any)["email"] != "dimas@contoh.id" {
		t.Fatalf("saya: %d %v", res.StatusCode, badan)
	}

	// field asing ditolak
	res, _ = kirim("POST", "/v1/akun/masuk", "", `{"email":"dimas@contoh.id","sandi":"x","peran":"admin"}`)
	if res.StatusCode != http.StatusBadRequest {
		t.Errorf("field asing harus 400, dapet %d", res.StatusCode)
	}

	if res, _ = kirim("POST", "/v1/akun/keluar", token, ""); res.StatusCode != http.StatusNoContent {
		t.Fatalf("keluar: %d", res.StatusCode)
	}
	res, badan = kirim("GET", "/v1/akun/saya", token, "")
	if res.StatusCode != http.StatusUnauthorized || badan["pesan"] == "" {
		t.Errorf("abis keluar harus 401 + pesan, dapet %d %v", res.StatusCode, badan)
	}
}

func TestPembatas(t *testing.T) {
	p := httpx.NewPembatas(3, time.Minute, false)
	h := p.Bungkus(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	var kode []int
	for range 5 {
		rec := httptest.NewRecorder()
		req := httptest.NewRequest("POST", "/v1/akun/masuk", nil)
		req.RemoteAddr = "10.0.0.1:5555"
		h.ServeHTTP(rec, req)
		kode = append(kode, rec.Code)
	}
	if kode[2] != http.StatusOK || kode[3] != http.StatusTooManyRequests {
		t.Errorf("3 boleh, ke-4 harus 429, dapet %v", kode)
	}
}

func TestUbahNamaDanHapusAkun(t *testing.T) {
	ctx := context.Background()
	l := layananTes()
	rani, err := l.Daftar(ctx, "Rani Amelia", "rani@contoh.id", "sandiaman1", "pembeli")
	if err != nil {
		t.Fatal(err)
	}
	mitra, _ := l.Daftar(ctx, "Ibis Hotel", "ibis@contoh.id", "sandiaman1", "mitra")

	// F-63 nama dirapikan, mitra ga bisa ganti sendiri
	a, err := l.UbahNama(ctx, rani.Akun, "  Rani   Amelia Putri ")
	if err != nil || a.Nama != "Rani Amelia Putri" {
		t.Fatalf("ubah nama: %+v %v", a, err)
	}
	if sesi, _ := l.Sesi(ctx, rani.Token); sesi.Nama != "Rani Amelia Putri" {
		t.Fatalf("nama di sesi: %q", sesi.Nama)
	}
	if _, err := l.UbahNama(ctx, rani.Akun, "R"); kodeGalat(t, err) != 422 {
		t.Errorf("nama 1 huruf harus 422")
	}
	if _, err := l.UbahNama(ctx, mitra.Akun, "Ibis Baru"); kodeGalat(t, err) != 403 {
		t.Errorf("mitra ganti nama harus 403")
	}

	// F-62 sandi salah, masih ada pesanan, lalu berhasil
	if err := l.HapusAkun(ctx, rani.Akun, "salah", ""); kodeGalat(t, err) != 401 {
		t.Errorf("sandi salah harus 401")
	}
	pesananAktif[rani.Akun.ID] = true
	if err := l.HapusAkun(ctx, rani.Akun, "sandiaman1", ""); kodeGalat(t, err) != 409 {
		t.Errorf("pesanan aktif harus 409")
	}
	delete(pesananAktif, rani.Akun.ID)
	if err := l.HapusAkun(ctx, rani.Akun, "sandiaman1", ""); err != nil {
		t.Fatal(err)
	}
	// sesi dicabut, ga bisa masuk lagi, emailnya bisa didaftarin ulang
	if _, err := l.Sesi(ctx, rani.Token); err != ErrSesiTidakBerlaku {
		t.Errorf("sesi setelah hapus: %v", err)
	}
	if _, err := l.Masuk(ctx, "rani@contoh.id", "sandiaman1"); kodeGalat(t, err) != 401 {
		t.Errorf("masuk setelah hapus harus ditolak")
	}
	if _, err := l.Daftar(ctx, "Rani Baru", "rani@contoh.id", "sandiaman2", "pembeli"); err != nil {
		t.Errorf("email bisa dipakai lagi: %v", err)
	}
	if err := l.HapusAkun(ctx, mitra.Akun, "sandiaman1", ""); kodeGalat(t, err) != 403 {
		t.Errorf("mitra hapus sendiri harus 403")
	}
}
