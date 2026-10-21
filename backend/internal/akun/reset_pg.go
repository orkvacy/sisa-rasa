package akun

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

const kolomReset = `id_akun, kode_hash, kedaluwarsa, salah, dibuat, tiket_hash, tiket_kedaluwarsa`

func pindaiReset(baris pgx.Row) (ResetSandi, error) {
	var r ResetSandi
	var tiket *string
	var tiketHabis *time.Time
	err := baris.Scan(&r.IDAkun, &r.KodeHash, &r.Kedaluwarsa, &r.Salah, &r.Dibuat, &tiket, &tiketHabis)
	if errors.Is(err, pgx.ErrNoRows) {
		return r, ErrTidakAda
	}
	if tiket != nil {
		r.TiketHash = *tiket
	}
	if tiketHabis != nil {
		r.TiketKedaluwarsa = *tiketHabis
	}
	return r, err
}

func (s StorePG) SimpanReset(ctx context.Context, r ResetSandi) error {
	var tiket *string
	var tiketHabis *time.Time
	if r.TiketHash != "" {
		tiket, tiketHabis = &r.TiketHash, &r.TiketKedaluwarsa
	}
	_, err := s.Pool.Exec(ctx, `
		INSERT INTO reset_sandi (`+kolomReset+`) VALUES ($1, $2, $3, $4, $5, $6, $7)
		ON CONFLICT (id_akun) DO UPDATE SET kode_hash = $2, kedaluwarsa = $3, salah = $4,
			dibuat = $5, tiket_hash = $6, tiket_kedaluwarsa = $7`,
		r.IDAkun, r.KodeHash, r.Kedaluwarsa, r.Salah, r.Dibuat, tiket, tiketHabis)
	return err
}

func (s StorePG) ResetAkun(ctx context.Context, idAkun string) (ResetSandi, error) {
	return pindaiReset(s.Pool.QueryRow(ctx,
		`SELECT `+kolomReset+` FROM reset_sandi WHERE id_akun = $1`, idAkun))
}

func (s StorePG) ResetDariTiket(ctx context.Context, tiketHash string) (ResetSandi, error) {
	return pindaiReset(s.Pool.QueryRow(ctx,
		`SELECT `+kolomReset+` FROM reset_sandi WHERE tiket_hash = $1`, tiketHash))
}

func (s StorePG) CatatSalah(ctx context.Context, idAkun string) (int, error) {
	var n int
	err := s.Pool.QueryRow(ctx,
		`UPDATE reset_sandi SET salah = salah + 1 WHERE id_akun = $1 RETURNING salah`, idAkun).Scan(&n)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, ErrTidakAda
	}
	return n, err
}

func (s StorePG) GantiSandi(ctx context.Context, idAkun, hashSandi string, sekarang time.Time) error {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	if _, err := tx.Exec(ctx,
		`UPDATE akun SET hash_sandi = $2 WHERE id = $1 AND dihapus_pada IS NULL`, idAkun, hashSandi); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx,
		`UPDATE sesi SET dicabut = $2 WHERE id_akun = $1 AND dicabut IS NULL`, idAkun, sekarang); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `DELETE FROM reset_sandi WHERE id_akun = $1`, idAkun); err != nil {
		return err
	}
	return tx.Commit(ctx)
}
