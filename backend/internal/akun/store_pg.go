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
	a := Akun{Nama: nama, Email: email, Peran: peran, PunyaSandi: true}
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
	return s.satuAkun(ctx, `email = $1`, email)
}

func (s StorePG) AkunDariGoogle(ctx context.Context, sub string) (akunTersimpan, error) {
	return s.satuAkun(ctx, `google_sub = $1 AND dihapus_pada IS NULL`, sub)
}

func (s StorePG) satuAkun(ctx context.Context, syarat string, arg any) (akunTersimpan, error) {
	var a akunTersimpan
	err := s.Pool.QueryRow(ctx, `
		SELECT id, nama, email, peran, hash_sandi, COALESCE(google_sub, '')
		FROM akun WHERE `+syarat, arg,
	).Scan(&a.ID, &a.Nama, &a.Email, &a.Peran, &a.HashSandi, &a.GoogleSub)
	if errors.Is(err, pgx.ErrNoRows) {
		return a, ErrTidakAda
	}
	a.PunyaSandi = a.HashSandi != ""
	return a, err
}

// hash sandi ” = ga punya sandi, bcrypt ga bakal cocok sama sandi apa pun
func (s StorePG) BuatAkunGoogle(ctx context.Context, nama, email, sub string) (Akun, error) {
	a := Akun{Nama: nama, Email: email, Peran: "pembeli"}
	err := s.Pool.QueryRow(ctx, `
		INSERT INTO akun (nama, email, hash_sandi, peran, google_sub)
		VALUES ($1, $2, '', 'pembeli', $3) RETURNING id`,
		nama, email, sub,
	).Scan(&a.ID)
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == kodeUnik {
		return Akun{}, ErrEmailDipakai
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
		SELECT a.id, a.nama, a.email, a.peran, a.hash_sandi <> ''
		FROM sesi s JOIN akun a ON a.id = s.id_akun
		WHERE s.token_hash = $1 AND s.dicabut IS NULL AND s.kedaluwarsa > $2`,
		tokenHash, sekarang,
	).Scan(&a.ID, &a.Nama, &a.Email, &a.Peran, &a.PunyaSandi)
	if errors.Is(err, pgx.ErrNoRows) {
		return a, ErrTidakAda
	}
	return a, err
}

func (s StorePG) UbahNama(ctx context.Context, idAkun, nama string) error {
	_, err := s.Pool.Exec(ctx,
		`UPDATE akun SET nama = $2 WHERE id = $1 AND dihapus_pada IS NULL`, idAkun, nama)
	return err
}

func (s StorePG) HapusAkun(ctx context.Context, idAkun string, sekarang time.Time) error {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	// kunci baris akun dulu biar pesanan baru ga nyelip di tengah penghapusan
	if _, err := tx.Exec(ctx, `SELECT 1 FROM akun WHERE id = $1 FOR UPDATE`, idAkun); err != nil {
		return err
	}
	var aktif bool
	if err := tx.QueryRow(ctx, `
		SELECT EXISTS (SELECT 1 FROM pesanan
		WHERE (id_pembeli = $1 OR id_mitra = $1)
		  AND status IN ('menunggu_bayar', 'disiapkan', 'siap_diambil'))`, idAkun,
	).Scan(&aktif); err != nil {
		return err
	}
	if aktif {
		return ErrPesananAktif
	}
	// email diganti alamat yang ga mungkin dipakai, jadi email aslinya bisa
	// didaftarin lagi. hash '!' ga cocok sama sandi apa pun
	if _, err := tx.Exec(ctx, `
		UPDATE akun SET nama = 'Akun dihapus', email = 'dihapus-' || id || '@sisarasa.invalid',
			hash_sandi = '!', google_sub = NULL, dihapus_pada = $2
		WHERE id = $1 AND dihapus_pada IS NULL`, idAkun, sekarang); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `
		UPDATE sesi SET dicabut = $2 WHERE id_akun = $1 AND dicabut IS NULL`, idAkun, sekarang); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `
		UPDATE pesanan SET nama_pembeli = 'Akun dihapus' WHERE id_pembeli = $1`, idAkun); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (s StorePG) CabutSesi(ctx context.Context, tokenHash string, sekarang time.Time) error {
	_, err := s.Pool.Exec(ctx,
		`UPDATE sesi SET dicabut = $2 WHERE token_hash = $1 AND dicabut IS NULL`,
		tokenHash, sekarang)
	return err
}
