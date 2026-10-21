package akun

import (
	"context"
	"testing"
)

func TestGantiSandiSaya(t *testing.T) {
	ctx := context.Background()
	l := layananTes()
	hasil, err := l.Daftar(ctx, "Rani", "rani@contoh.id", "sandiaman1", "pembeli")
	if err != nil {
		t.Fatal(err)
	}
	// HP lain yang masuk ke akun yang sama
	lain, err := l.Masuk(ctx, "rani@contoh.id", "sandiaman1")
	if err != nil {
		t.Fatal(err)
	}

	kasus := []struct {
		lama, baru string
		kode       int
	}{
		{"salah1234", "sandibaru1", 401},
		{"sandiaman1", "pendek", 422},
		{"sandiaman1", "sandiaman1", 422},
	}
	for _, k := range kasus {
		if _, err := l.GantiSandiSaya(ctx, hasil.Akun, k.lama, k.baru); kodeGalat(t, err) != k.kode {
			t.Errorf("%q -> %q: harus %d, dapet %v", k.lama, k.baru, k.kode, err)
		}
	}

	baru, err := l.GantiSandiSaya(ctx, hasil.Akun, "sandiaman1", "sandibaru1")
	if err != nil {
		t.Fatal(err)
	}
	// semua sesi lama dicabut, HP ini dapet sesi baru
	for _, token := range []string{hasil.Token, lain.Token} {
		if _, err := l.Sesi(ctx, token); err != ErrSesiTidakBerlaku {
			t.Errorf("sesi lama masih jalan: %v", err)
		}
	}
	if a, err := l.Sesi(ctx, baru.Token); err != nil || a.ID != hasil.Akun.ID {
		t.Fatalf("sesi baru: %v %+v", err, a)
	}
	if _, err := l.Masuk(ctx, "rani@contoh.id", "sandiaman1"); err == nil {
		t.Error("sandi lama masih bisa masuk")
	}
	if _, err := l.Masuk(ctx, "rani@contoh.id", "sandibaru1"); err != nil {
		t.Errorf("sandi baru: %v", err)
	}

	// akun Google ga punya sandi
	l.Google = googlePalsu{"tok-budi": {Sub: "g-budi", Email: "budi@gmail.com", Nama: "Budi"}}
	g, err := l.MasukGoogle(ctx, "tok-budi")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := l.GantiSandiSaya(ctx, g.Akun, "", "sandibaru1"); kodeGalat(t, err) != 409 {
		t.Errorf("akun Google ganti sandi: %v", err)
	}
}

func TestAturFoto(t *testing.T) {
	ctx := context.Background()
	l := layananTes()
	hasil, err := l.Daftar(ctx, "Ibis Hotel", "ibis@contoh.id", "sandiaman1", "mitra")
	if err != nil {
		t.Fatal(err)
	}
	const url = "https://cdn.sisarasa.web.id/paket/abc.jpg"
	if a, err := l.AturFoto(ctx, hasil.Akun, url); err != nil || a.Foto != url {
		t.Fatalf("atur foto: %v %+v", err, a)
	}
	if a, _ := l.Sesi(ctx, hasil.Token); a.Foto != url {
		t.Errorf("foto ga kebaca dari sesi: %+v", a)
	}
	if _, err := l.AturFoto(ctx, hasil.Akun, ""); err != nil {
		t.Fatal(err)
	}
	if a, _ := l.Sesi(ctx, hasil.Token); a.Foto != "" {
		t.Errorf("foto harus kehapus: %+v", a)
	}
}
