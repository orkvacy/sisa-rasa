package toko

import (
	"context"
	"os"
	"testing"

	"github.com/orkvacy/sisa-rasa/backend/internal/akun"
	"github.com/orkvacy/sisa-rasa/backend/internal/db"
)

// skenario yang sama kayak di memori, tapi ke PostgreSQL beneran: ngetes SQL,
// penguncian baris paket (FOR UPDATE), indeks unik, dan pengembalian stok.
// dilewati kalau TEST_DATABASE_URL kosong. jalanin dengan go test -p 1 ./...
func TestSkenarioPostgres(t *testing.T) {
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("TEST_DATABASE_URL kosong, tes Postgres dilewati")
	}
	for nama, uji := range skenario {
		t.Run(nama, func(t *testing.T) { uji(t, siapkanPG(url)) })
	}
}

func siapkanPG(url string) func(*testing.T) siap {
	return func(t *testing.T) siap {
		t.Helper()
		ctx := context.Background()
		pool, err := db.BukaTes(ctx, url)
		if err != nil {
			t.Fatal(err)
		}
		t.Cleanup(pool.Close)
		semua := append([]akun.Akun{rani, dimas, ibis, prime}, pembeliBarengan()...)
		for i, a := range semua {
			if _, err := pool.Exec(ctx, `
				INSERT INTO akun (id, nama, email, hash_sandi, peran) VALUES ($1, $2, $3, 'x', $4)`,
				a.ID, a.Nama, a.ID+"@contoh.id", a.Peran); err != nil {
				t.Fatalf("akun %d: %v", i, err)
			}
		}
		return siapkanDengan(t, StorePG{Pool: pool})
	}
}
