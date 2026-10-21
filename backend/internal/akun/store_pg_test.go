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
	if err := l.HapusAkun(ctx, masuk.Akun, "sandiaman1", ""); err != nil {
		t.Fatal(err)
	}
	if _, err := l.Sesi(ctx, masuk.Token); err != ErrSesiTidakBerlaku {
		t.Errorf("sesi setelah hapus: %v", err)
	}
	if _, err := l.Daftar(ctx, "Rani Lagi", "rani@contoh.id", "sandiaman1", "pembeli"); err != nil {
		t.Errorf("email bisa didaftarin lagi: %v", err)
	}

	// masuk dengan Google lewat SQL beneran
	l.Google = googlePalsu{"tok-budi": {Sub: "g-budi", Email: "budi@gmail.com", Nama: "Budi"}}
	g, err := l.MasukGoogle(ctx, "tok-budi")
	if err != nil || g.Akun.PunyaSandi || g.Akun.Peran != "pembeli" {
		t.Fatalf("google baru: %+v %v", g.Akun, err)
	}
	if lagi, err := l.MasukGoogle(ctx, "tok-budi"); err != nil || lagi.Akun.ID != g.Akun.ID {
		t.Fatalf("google kedua: %+v %v", lagi.Akun, err)
	}
	if a, _ := l.Sesi(ctx, g.Token); a.PunyaSandi {
		t.Error("sesi akun google harus punyaSandi false")
	}
	if err := l.HapusAkun(ctx, g.Akun, "", "tok-budi"); err != nil {
		t.Fatal(err)
	}
	if baru, err := l.MasukGoogle(ctx, "tok-budi"); err != nil || baru.Akun.ID == g.Akun.ID {
		t.Fatalf("abis dihapus harus jadi akun baru: %+v %v", baru.Akun, err)
	}

	// F-61 lupa sandi lewat SQL beneran. email beda biar ga bentrok sama di atas
	lr := &Layanan{Store: StorePG{Pool: pool}, BiayaBcrypt: 4}
	if _, err := pool.Exec(ctx, `DELETE FROM akun WHERE email = 'rani@contoh.id'`); err != nil {
		t.Fatal(err)
	}
	ujiLupaSandi(t, lr)
}
