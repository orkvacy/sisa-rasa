package db

import (
	"context"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
)

// BukaTes buka database khusus tes, kosongin semua tabelnya, lalu jalanin migrasi.
// cuma mau jalan kalau nama databasenya ada "tes" / "test", biar ga mungkin
// ngehapus database dev atau production gara-gara salah isi TEST_DATABASE_URL.
// tes Postgres harus dijalanin satu paket sekali jalan: go test -p 1 ./...
func BukaTes(ctx context.Context, url string) (*pgxpool.Pool, error) {
	pool, err := Buka(ctx, url)
	if err != nil {
		return nil, err
	}
	var nama string
	if err := pool.QueryRow(ctx, `SELECT current_database()`).Scan(&nama); err != nil {
		pool.Close()
		return nil, err
	}
	if !strings.Contains(nama, "tes") && !strings.Contains(nama, "test") {
		pool.Close()
		return nil, fmt.Errorf("database %q bukan database tes, ga jadi dikosongin", nama)
	}
	if _, err := pool.Exec(ctx, `DROP SCHEMA public CASCADE; CREATE SCHEMA public`); err != nil {
		pool.Close()
		return nil, err
	}
	if err := Migrasi(ctx, pool); err != nil {
		pool.Close()
		return nil, err
	}
	return pool, nil
}
