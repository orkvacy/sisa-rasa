package akun

import (
	"context"
	"net/http"
	"regexp"
	"sync"
	"testing"
	"time"
)

// pengirimTes nyatet email yang "dikirim"
type pengirimTes struct {
	mu    sync.Mutex
	surat []map[string]string
}

func (p *pengirimTes) Kirim(_ context.Context, ke, subjek, teks, _ string) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.surat = append(p.surat, map[string]string{"ke": ke, "subjek": subjek, "teks": teks})
	return nil
}

var polaKode = regexp.MustCompile(`\b\d{6}\b`)

func (p *pengirimTes) kodeTerakhir(t *testing.T) string {
	t.Helper()
	p.mu.Lock()
	defer p.mu.Unlock()
	if len(p.surat) == 0 {
		t.Fatal("belum ada email")
	}
	return polaKode.FindString(p.surat[len(p.surat)-1]["teks"])
}

func TestLupaSandi(t *testing.T) {
	ujiLupaSandi(t, &Layanan{Store: baruStoreMemori(), BiayaBcrypt: 4})
}

// ujiLupaSandi dipakai di memori dan Postgres (store_pg_test.go)
func ujiLupaSandi(t *testing.T, l *Layanan) {
	ctx := context.Background()
	jam := time.Date(2026, 10, 21, 9, 0, 0, 0, time.UTC)
	l.Jam = func() time.Time { return jam }

	// fitur mati kalau pengirim email belum diatur
	if err := l.MintaKodeReset(ctx, "rani@contoh.id"); kodeGalat(t, err) != http.StatusServiceUnavailable {
		t.Fatalf("tanpa pengirim: %v", err)
	}
	pos := &pengirimTes{}
	l.Pengirim, l.KirimLangsung = pos, true

	rani, err := l.Daftar(ctx, "Rani Amelia", "rani@contoh.id", "sandilama1", "pembeli")
	if err != nil {
		t.Fatal(err)
	}

	// email ga terdaftar: jawabannya sama, tapi ga ada email yang dikirim
	if err := l.MintaKodeReset(ctx, "orang.lain@contoh.id"); err != nil {
		t.Fatal(err)
	}
	if len(pos.surat) != 0 {
		t.Fatal("email ga terdaftar ga boleh dikirimi")
	}
	if err := l.MintaKodeReset(ctx, " RANI@contoh.id "); err != nil {
		t.Fatal(err)
	}
	if len(pos.surat) != 1 || pos.surat[0]["ke"] != "rani@contoh.id" {
		t.Fatalf("email kode: %v", pos.surat)
	}
	kode := pos.kodeTerakhir(t)
	// minta lagi sebelum 60 detik: ga dikirim ulang, kodenya tetap
	if err := l.MintaKodeReset(ctx, "rani@contoh.id"); err != nil || len(pos.surat) != 1 {
		t.Fatalf("kirim ulang terlalu cepat: %v %d", err, len(pos.surat))
	}

	// salah 4 kali masih boleh, ke-5 kodenya hangus
	salah := "000000"
	if kode == salah {
		salah = "111111"
	}
	for i := 1; i <= 4; i++ {
		if _, err := l.CekKodeReset(ctx, "rani@contoh.id", salah); kodeGalat(t, err) != http.StatusUnprocessableEntity {
			t.Fatalf("salah ke-%d: %v", i, err)
		}
	}
	if _, err := l.CekKodeReset(ctx, "rani@contoh.id", salah); err != errKodeHangus {
		t.Fatalf("salah ke-5 harus hangus: %v", err)
	}
	if _, err := l.CekKodeReset(ctx, "rani@contoh.id", kode); err != errKodeHangus {
		t.Fatalf("abis hangus kode benar pun ditolak: %v", err)
	}

	// minta kode baru (lewat jeda), kedaluwarsa setelah 10 menit
	jam = jam.Add(61 * time.Second)
	if err := l.MintaKodeReset(ctx, "rani@contoh.id"); err != nil {
		t.Fatal(err)
	}
	kode = pos.kodeTerakhir(t)
	jam = jam.Add(10 * time.Minute)
	if _, err := l.CekKodeReset(ctx, "rani@contoh.id", kode); err != errKodeSalah {
		t.Fatalf("kode kedaluwarsa: %v", err)
	}

	// kode baru lagi: cocok -> tiket. kode sekali pakai
	jam = jam.Add(time.Second)
	if err := l.MintaKodeReset(ctx, "rani@contoh.id"); err != nil {
		t.Fatal(err)
	}
	kode = pos.kodeTerakhir(t)
	tiket, err := l.CekKodeReset(ctx, "rani@contoh.id", kode)
	if err != nil || tiket == "" {
		t.Fatalf("kode benar: %q %v", tiket, err)
	}
	if _, err := l.CekKodeReset(ctx, "rani@contoh.id", kode); err != errKodeSalah {
		t.Fatalf("kode dipakai dua kali: %v", err)
	}

	// sandi baru: kependekan ditolak, tiket palsu ditolak
	if err := l.AturSandiBaru(ctx, tiket, "pendek"); kodeGalat(t, err) != http.StatusUnprocessableEntity {
		t.Fatalf("sandi pendek: %v", err)
	}
	if err := l.AturSandiBaru(ctx, "tiket-palsu", "sandibaru123"); err != errTiketHabis {
		t.Fatalf("tiket palsu: %v", err)
	}
	if err := l.AturSandiBaru(ctx, tiket, "sandibaru123"); err != nil {
		t.Fatal(err)
	}
	// sesi lama dicabut, sandi lama ga bisa, sandi baru bisa, tiket ga bisa dipakai lagi
	if _, err := l.Sesi(ctx, rani.Token); err != ErrSesiTidakBerlaku {
		t.Errorf("sesi lama harus dicabut: %v", err)
	}
	if _, err := l.Masuk(ctx, "rani@contoh.id", "sandilama1"); err == nil {
		t.Error("sandi lama masih bisa")
	}
	if _, err := l.Masuk(ctx, "rani@contoh.id", "sandibaru123"); err != nil {
		t.Errorf("sandi baru: %v", err)
	}
	if err := l.AturSandiBaru(ctx, tiket, "sandibaru456"); err != errTiketHabis {
		t.Errorf("tiket dipakai dua kali: %v", err)
	}

	// tiket kedaluwarsa setelah 15 menit
	jam = jam.Add(2 * time.Minute)
	if err := l.MintaKodeReset(ctx, "rani@contoh.id"); err != nil {
		t.Fatal(err)
	}
	tiket, err = l.CekKodeReset(ctx, "rani@contoh.id", pos.kodeTerakhir(t))
	if err != nil {
		t.Fatal(err)
	}
	jam = jam.Add(16 * time.Minute)
	if err := l.AturSandiBaru(ctx, tiket, "sandibaru789"); err != errTiketHabis {
		t.Errorf("tiket kedaluwarsa: %v", err)
	}
}

func TestIsiEmailAman(t *testing.T) {
	_, _, html := isiEmailKode(`<script>alert(1)</script>`, "123456")
	if regexp.MustCompile(`<script>`).MatchString(html) {
		t.Error("nama di email harus di-escape")
	}
}
