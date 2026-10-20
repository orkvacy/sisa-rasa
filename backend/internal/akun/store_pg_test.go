package akun

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/orkvacy/sisa-rasa/backend/internal/db"
)

// tes ke PostgreSQL beneran. dilewati kalau TEST_DATABASE_URL kosong.
// pake database khusus tes, isinya dihapus tiap jalan:
//
//	$env:TEST_DATABASE_URL = "postgres://postgres:SANDI@localhost:5432/sisarasa_tes?sslmode=disable"
func TestStorePG(t *testing.T) {
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("TEST_DATABASE_URL kosong, tes Postgres dilewati")
	}
	ctx := context.Background()
	pool, err := db.BukaTes(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	defer pool.Close()
	// migrasi kedua kali ga boleh error / ngulang
	if err := db.Migrasi(ctx, pool); err != nil {
		t.Fatal(err)
	}

	sekarang := time.Now()
	l := &Layanan{Store: StorePG{Pool: pool}, BiayaBcrypt: 4, Jam: func() time.Time { return sekarang }}
	hasil, err := l.Daftar(ctx, "Rani Amelia", "rani@contoh.id", "sandiaman1", "pembeli")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := l.Daftar(ctx, "Rani Lain", "RANI@contoh.id", "sandiaman1", "pembeli"); kodeGalat(t, err) != 409 {
		t.Errorf("email kembar harus 409")
	}
	if a, err := l.Sesi(ctx, hasil.Token); err != nil || a.ID != hasil.Akun.ID {
		t.Fatalf("sesi: %v %+v", err, a)
	}
	if err := l.Keluar(ctx, hasil.Token); err != nil {
		t.Fatal(err)
	}
	if _, err := l.Sesi(ctx, hasil.Token); err != ErrSesiTidakBerlaku {
		t.Errorf("abis keluar harus ditolak, dapet %v", err)
	}

	// ubah nama + hapus akun lewat SQL beneran
	masuk, err := l.Masuk(ctx, "rani@contoh.id", "sandiaman1")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := l.UbahNama(ctx, masuk.Akun, "Rani Putri"); err != nil {
		t.Fatal(err)
	}
	if a, _ := l.Sesi(ctx, masuk.Token); a.Nama != "Rani Putri" {
		t.Errorf("nama baru: %q", a.Nama)
	}
	if err := l.HapusAkun(ctx, masuk.Akun, "sandiaman1"); err != nil {
		t.Fatal(err)
	}
	if _, err := l.Sesi(ctx, masuk.Token); err != ErrSesiTidakBerlaku {
		t.Errorf("sesi setelah hapus: %v", err)
	}
	if _, err := l.Daftar(ctx, "Rani Lagi", "rani@contoh.id", "sandiaman1", "pembeli"); err != nil {
		t.Errorf("email bisa didaftarin lagi: %v", err)
	}
}
