package toko

import (
	"context"
	"net/http"
	"slices"
	"testing"

	"github.com/orkvacy/sisa-rasa/backend/internal/akun"
)

func ujiFavorit(t *testing.T, siapkan func(*testing.T) siap) {
	x := siapkan(t)
	ctx := context.Background()
	// id mitra favorit, nama mitranya dicek sekali di bawah
	daftar := func(a akun.Akun) []string {
		t.Helper()
		d, err := x.l.DaftarFavorit(ctx, a)
		if err != nil {
			t.Fatal(err)
		}
		id := []string{}
		for _, m := range d {
			id = append(id, m.ID)
		}
		return id
	}
	if d := daftar(rani); len(d) != 0 {
		t.Fatalf("awalnya kosong: %v", d)
	}
	// simpan dua mitra, simpan ulang = tetap satu
	for _, m := range []akun.Akun{ibis, prime, ibis} {
		if err := x.l.AturFavorit(ctx, rani, m.ID, true); err != nil {
			t.Fatal(err)
		}
	}
	if d := daftar(rani); len(d) != 2 || !slices.Contains(d, ibis.ID) || !slices.Contains(d, prime.ID) {
		t.Fatalf("dua favorit tanpa dobel: %v", d)
	}
	// favorit tiap pembeli terpisah
	if d := daftar(dimas); len(d) != 0 {
		t.Fatalf("favorit rani bocor ke dimas: %v", d)
	}
	// lepas, lepas lagi (idempoten)
	for range 2 {
		if err := x.l.AturFavorit(ctx, rani, prime.ID, false); err != nil {
			t.Fatal(err)
		}
	}
	if d := daftar(rani); len(d) != 1 || d[0] != ibis.ID {
		t.Fatalf("setelah lepas: %v", d)
	}
	if d, _ := x.l.DaftarFavorit(ctx, rani); d[0].Nama != ibis.Nama || d[0].Jenis == "" {
		t.Fatalf("nama + jenis mitra ikut: %+v", d[0])
	}
	// bukan mitra / id ngawur / bukan pembeli
	if err := x.l.AturFavorit(ctx, rani, dimas.ID, true); kodeGalat(err) != http.StatusNotFound {
		t.Fatalf("favoritin akun pembeli: %v", err)
	}
	if err := x.l.AturFavorit(ctx, rani, "bukan-uuid", true); kodeGalat(err) != http.StatusNotFound {
		t.Fatalf("id ngawur: %v", err)
	}
	if _, err := x.l.DaftarFavorit(ctx, ibis); kodeGalat(err) != http.StatusForbidden {
		t.Fatalf("mitra buka favorit: %v", err)
	}
}
