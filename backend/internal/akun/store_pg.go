package akun

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

// StorePG nyimpen akun sama sesi di PostgreSQL
type StorePG struct{ Pool *pgxpool.Pool }

// kode galat Postgres buat unique_violation
const kodeUnik = "23505"

func (s StorePG) BuatAkun(ctx context.Context, nama, email, hashSandi, peran string) (Akun, error) {
	a := Akun{Nama: nama, Email: email, Peran: peran}
	err := s.Pool.QueryRow(ctx,
		`INSERT INTO akun (nama, email, hash_sandi, peran) VALUES ($1, $2, $3, $4) RETURNING id`,
		nama, email, hashSandi, peran,
	).Scan(&a.ID)
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == kodeUnik {
		return Akun{}, ErrEmailDipakai
	}
	return a, err
}

func (s StorePG) AkunDariEmail(ctx context.Context, email string) (akunTersimpan, error) {
	var a akunTersimpan
	err := s.Pool.QueryRow(ctx,
		`SELECT id, nama, email, peran, hash_sandi FROM akun WHERE email = $1`, email,
	).Scan(&a.ID, &a.Nama, &a.Email, &a.Peran, &a.HashSandi)
	if errors.Is(err, pgx.ErrNoRows) {
		return a, ErrTidakAda
	}
	return a, err
}

func (s StorePG) BuatSesi(ctx context.Context, tokenHash, idAkun string, kedaluwarsa time.Time) error {
	_, err := s.Pool.Exec(ctx,
		`INSERT INTO sesi (token_hash, id_akun, kedaluwarsa) VALUES ($1, $2, $3)`,
		tokenHash, idAkun, kedaluwarsa)
	return err
}

func (s StorePG) AkunDariSesi(ctx context.Context, tokenHash string, sekarang time.Time) (Akun, error) {
	var a Akun
	err := s.Pool.QueryRow(ctx, `
		SELECT a.id, a.nama, a.email, a.peran
		FROM sesi s JOIN akun a ON a.id = s.id_akun
		WHERE s.token_hash = $1 AND s.dicabut IS NULL AND s.kedaluwarsa > $2`,
		tokenHash, sekarang,
	).Scan(&a.ID, &a.Nama, &a.Email, &a.Peran)
	if errors.Is(err, pgx.ErrNoRows) {
		return a, ErrTidakAda
	}
	return a, err
}

func (s StorePG) CabutSesi(ctx context.Context, tokenHash string, sekarang time.Time) error {
	_, err := s.Pool.Exec(ctx,
		`UPDATE sesi SET dicabut = $2 WHERE token_hash = $1 AND dicabut IS NULL`,
		tokenHash, sekarang)
	return err
}
