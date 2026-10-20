package toko

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

func (s StorePG) Rekening(ctx context.Context, idMitra string) (*Rekening, error) {
	var r Rekening
	err := s.Pool.QueryRow(ctx,
		`SELECT bank, nomor, nama FROM rekening_mitra WHERE id_akun = $1`, idMitra,
	).Scan(&r.Bank, &r.Nomor, &r.Nama)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, petakan(err)
	}
	return &r, nil
}

func (s StorePG) SimpanRekening(ctx context.Context, idMitra string, r Rekening, sekarang time.Time) error {
	_, err := s.Pool.Exec(ctx, `
		INSERT INTO rekening_mitra (id_akun, bank, nomor, nama, diubah) VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (id_akun) DO UPDATE SET bank = $2, nomor = $3, nama = $4, diubah = $5`,
		idMitra, r.Bank, r.Nomor, r.Nama, sekarang)
	return petakan(err)
}

func daftarPencairan(ctx context.Context, q interface {
	Query(context.Context, string, ...any) (pgx.Rows, error)
}, idMitra string) ([]Pencairan, error) {
	baris, err := q.Query(ctx, `
		SELECT id, jumlah, bank, nomor, nama, status, dibuat, kunci
		FROM pencairan WHERE id_mitra = $1 ORDER BY dibuat DESC`, idMitra)
	if err != nil {
		return nil, petakan(err)
	}
	hasil, err := pgx.CollectRows(baris, func(r pgx.CollectableRow) (Pencairan, error) {
		var p Pencairan
		err := r.Scan(&p.ID, &p.Jumlah, &p.Bank, &p.Nomor, &p.Nama, &p.Status, &p.Waktu, &p.kunci)
		return p, err
	})
	if hasil == nil {
		hasil = []Pencairan{}
	}
	return hasil, petakan(err)
}

func (s StorePG) DaftarPencairan(ctx context.Context, idMitra string) ([]Pencairan, error) {
	return daftarPencairan(ctx, s.Pool, idMitra)
}

func pendapatan(ctx context.Context, q interface {
	Query(context.Context, string, ...any) (pgx.Rows, error)
}, idMitra string) ([]int, error) {
	baris, err := q.Query(ctx, `
		SELECT subtotal FROM pesanan
		WHERE id_mitra = $1 AND status IN ('selesai', 'tidak_diambil')`, idMitra)
	if err != nil {
		return nil, petakan(err)
	}
	hasil, err := pgx.CollectRows(baris, pgx.RowTo[int])
	return hasil, petakan(err)
}

func (s StorePG) Pendapatan(ctx context.Context, idMitra string) ([]int, error) {
	return pendapatan(ctx, s.Pool, idMitra)
}

func (s StorePG) MitraBerekening(ctx context.Context) ([]string, error) {
	baris, err := s.Pool.Query(ctx, `SELECT id_akun FROM rekening_mitra`)
	if err != nil {
		return nil, petakan(err)
	}
	return pgx.CollectRows(baris, pgx.RowTo[string])
}

func (s StorePG) Cairkan(ctx context.Context, idMitra, kunci string,
	hitung func(pendapatan []int, lama []Pencairan, r *Rekening) *Pencairan) (*Pencairan, error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	// kunci per mitra selama transaksi: dua pencairan barengan buat mitra yang sama
	// antre, jadi saldo yang dibaca pasti udah ngitung pencairan yang lain
	if _, err := tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtext('pencairan:' || $1))`, idMitra); err != nil {
		return nil, petakan(err)
	}
	var sudah bool
	if err := tx.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM pencairan WHERE id_mitra = $1 AND kunci = $2)`,
		idMitra, kunci).Scan(&sudah); err != nil {
		return nil, petakan(err)
	}
	if sudah {
		return nil, nil
	}
	lama, err := daftarPencairan(ctx, tx, idMitra)
	if err != nil {
		return nil, err
	}
	masuk, err := pendapatan(ctx, tx, idMitra)
	if err != nil {
		return nil, err
	}
	var r *Rekening
	var rek Rekening
	err = tx.QueryRow(ctx, `SELECT bank, nomor, nama FROM rekening_mitra WHERE id_akun = $1`, idMitra).
		Scan(&rek.Bank, &rek.Nomor, &rek.Nama)
	if err == nil {
		r = &rek
	} else if !errors.Is(err, pgx.ErrNoRows) {
		return nil, petakan(err)
	}

	p := hitung(masuk, lama, r)
	if p == nil {
		return nil, nil
	}
	if err := tx.QueryRow(ctx, `
		INSERT INTO pencairan (id_mitra, jumlah, bank, nomor, nama, status, dibuat, kunci)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id`,
		idMitra, p.Jumlah, p.Bank, p.Nomor, p.Nama, p.Status, p.Waktu, kunci).Scan(&p.ID); err != nil {
		return nil, petakan(err)
	}
	return p, petakan(tx.Commit(ctx))
}
