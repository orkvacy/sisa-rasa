package config

import "testing"

func TestKunciMidtrans(t *testing.T) {
	kasus := []struct {
		nama, kunci, produksi string
		boleh                 bool
	}{
		{"akun baru sandbox (tanpa SB-)", "Mid-server-contoh", "", true},
		{"akun lama sandbox", "SB-Mid-server-contoh", "", true},
		{"produksi", "Mid-server-contoh", "1", true},
		{"kunci sandbox lama di produksi", "SB-Mid-server-contoh", "1", false},
		{"tanpa midtrans", "", "", true},
	}
	for _, k := range kasus {
		t.Run(k.nama, func(t *testing.T) {
			t.Setenv("DATABASE_URL", "postgres://tes")
			t.Setenv("LINGKUNGAN", "staging")
			t.Setenv("MIDTRANS_SERVER_KEY", k.kunci)
			t.Setenv("MIDTRANS_PRODUKSI", k.produksi)
			_, err := Baca()
			if (err == nil) != k.boleh {
				t.Fatalf("boleh %v, dapet galat %v", k.boleh, err)
			}
		})
	}
}
