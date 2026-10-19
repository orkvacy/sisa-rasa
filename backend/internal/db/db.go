// Package db buka koneksi PostgreSQL dan jalanin migrasi skema.
package db

import (
	"context"
	"embed"
	"fmt"
	"io/fs"
	"sort"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
)

//go:embed migrasi/*.sql
var berkasMigrasi embed.FS

// Buka bikin pool koneksi dan mastiin database-nya bisa dihubungi.
func Buka(ctx context.Context, url string) (*pgxpool.Pool, error) {
	pool, err := pgxpool.New(ctx, url)
	if err != nil {
		return nil, fmt.Errorf("buka database: %w", err)
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("hubungi database: %w", err)
	}
	return pool, nil
}

// Migrasi jalanin berkas migrasi/*.sql yang belum pernah dijalanin, urut nama.
// tiap berkas dijalanin dalam satu transaksi, jadi gagal di tengah = ga ada yg berubah.
// berkas yang udah dijalanin ga boleh diubah, bikin berkas baru aja
func Migrasi(ctx context.Context, pool *pgxpool.Pool) error {
	if _, err := pool.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS schema_migrasi (
			nama       TEXT PRIMARY KEY,
			dijalankan TIMESTAMPTZ NOT NULL DEFAULT now()
		)`); err != nil {
		return fmt.Errorf("bikin tabel schema_migrasi: %w", err)
	}

	nama, err := fs.Glob(berkasMigrasi, "migrasi/*.sql")
	if err != nil {
		return err
	}
	sort.Strings(nama)

	for _, berkas := range nama {
		id := strings.TrimPrefix(berkas, "migrasi/")
		var sudah bool
		if err := pool.QueryRow(ctx,
			`SELECT EXISTS (SELECT 1 FROM schema_migrasi WHERE nama = $1)`, id,
		).Scan(&sudah); err != nil {
			return err
		}
		if sudah {
			continue
		}

		isi, err := berkasMigrasi.ReadFile(berkas)
		if err != nil {
			return err
		}
		tx, err := pool.Begin(ctx)
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, string(isi)); err != nil {
			_ = tx.Rollback(ctx)
			return fmt.Errorf("migrasi %s: %w", id, err)
		}
		if _, err := tx.Exec(ctx, `INSERT INTO schema_migrasi (nama) VALUES ($1)`, id); err != nil {
			_ = tx.Rollback(ctx)
			return err
		}
		if err := tx.Commit(ctx); err != nil {
			return err
		}
	}
	return nil
}
