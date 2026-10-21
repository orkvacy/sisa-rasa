package toko

import (
	"context"
	"net/http"
	"testing"
)

func ujiLokasi(t *testing.T, siapkan func(*testing.T) siap) {
	x := siapkan(t)
	ctx := context.Background()

	// belum masang titik: paket tanpa lat/lng, status tanpa titik
	if st, _ := x.l.StatusSaya(ctx, ibis); st.Titik != nil {
		t.Fatalf("awalnya belum ada titik: %+v", st.Titik)
	}
	titikIbis := func() (*float64, *float64) {
		t.Helper()
		for _, p := range mustDaftar(t, x.l, ctx) {
			if p.ID == x.sarapan.ID {
				return p.Lat, p.Lng
			}
		}
		t.Fatal("paket sarapan ga ketemu")
		return nil, nil
	}
	if lat, _ := titikIbis(); lat != nil {
		t.Fatalf("paket belum boleh punya titik: %v", *lat)
	}

	// mitra masang titik dari GPS
	if err := x.l.AturLokasi(ctx, ibis, Titik{Lat: -0.4989, Lng: 117.1497}); err != nil {
		t.Fatal(err)
	}
	if lat, lng := titikIbis(); lat == nil || *lat != -0.4989 || *lng != 117.1497 {
		t.Fatalf("titik di paket: %v %v", lat, lng)
	}
	if st, _ := x.l.StatusSaya(ctx, ibis); st.Titik == nil || st.Titik.Lng != 117.1497 {
		t.Fatalf("titik di status: %+v", st.Titik)
	}
	// diganti lagi
	if err := x.l.AturLokasi(ctx, ibis, Titik{Lat: -0.5, Lng: 117.15}); err != nil {
		t.Fatal(err)
	}
	if lat, _ := titikIbis(); *lat != -0.5 {
		t.Fatalf("titik baru: %v", *lat)
	}

	// mitra baru (belum ada baris gerai) juga bisa masang
	if err := x.l.AturLokasi(ctx, mitraBaru, Titik{Lat: -0.47, Lng: 117.14}); err != nil {
		t.Fatal(err)
	}

	// ditolak: titik ngawur, GPS belum dapet sinyal, bukan mitra
	for _, salah := range []Titik{{Lat: 91, Lng: 117}, {Lat: -0.5, Lng: 181}, {}} {
		if err := x.l.AturLokasi(ctx, ibis, salah); kodeGalat(err) != http.StatusUnprocessableEntity {
			t.Errorf("titik %+v harus 422, dapet %v", salah, err)
		}
	}
	if err := x.l.AturLokasi(ctx, rani, Titik{Lat: -0.5, Lng: 117.15}); kodeGalat(err) != http.StatusForbidden {
		t.Errorf("pembeli masang titik: %v", err)
	}
}
