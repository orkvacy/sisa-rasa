package toko

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

const kolomVoucher = `id::text, kode, judul, persen, maks_potongan, min_belanja, mulai, berakhir,
	kuota, terpakai, khusus_baru, publik, aktif, dibuat`

func pindaiVoucher(baris pgx.Row) (Voucher, error) {
	var v Voucher
	err := baris.Scan(&v.ID, &v.Kode, &v.Judul, &v.Persen, &v.MaksPotongan, &v.MinBelanja,
		&v.Mulai, &v.Berakhir, &v.Kuota, &v.Terpakai, &v.KhususBaru, &v.Publik, &v.Aktif, &v.Dibuat)
	return v, petakan(err)
}

func (s StorePG) BuatVoucher(ctx context.Context, v Voucher) (Voucher, error) {
	hasil, err := pindaiVoucher(s.Pool.QueryRow(ctx, `
		INSERT INTO voucher (kode, judul, persen, maks_potongan, min_belanja, mulai, berakhir,
			kuota, khusus_baru, publik, aktif, dibuat)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
		RETURNING `+kolomVoucher,
		v.Kode, v.Judul, v.Persen, v.MaksPotongan, v.MinBelanja, v.Mulai, v.Berakhir,
		v.Kuota, v.KhususBaru, v.Publik, v.Aktif, v.Dibuat))
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == "23505" {
		return Voucher{}, ErrBentrok
	}
	return hasil, err
}

func (s StorePG) SemuaVoucher(ctx context.Context) ([]Voucher, error) {
	baris, err := s.Pool.Query(ctx, `SELECT `+kolomVoucher+` FROM voucher ORDER BY dibuat DESC`)
	if err != nil {
		return nil, petakan(err)
	}
	hasil, err := pgx.CollectRows(baris, func(r pgx.CollectableRow) (Voucher, error) { return pindaiVoucher(r) })
	if hasil == nil {
		hasil = []Voucher{}
	}
	return hasil, petakan(err)
}

func (s StorePG) AturVoucherAktif(ctx context.Context, id string, aktif bool) (Voucher, error) {
	return pindaiVoucher(s.Pool.QueryRow(ctx, `
		UPDATE voucher SET aktif = $2 WHERE id = $1 RETURNING `+kolomVoucher, id, aktif))
}

func (s StorePG) VoucherDariKode(ctx context.Context, kode string) (Voucher, error) {
	return pindaiVoucher(s.Pool.QueryRow(ctx, `SELECT `+kolomVoucher+` FROM voucher WHERE kode = $1`, kode))
}

func (s StorePG) PernahPesan(ctx context.Context, idPembeli string) (bool, error) {
	var ada bool
	err := s.Pool.QueryRow(ctx, `
		SELECT EXISTS (SELECT 1 FROM pesanan WHERE id_pembeli = $1 AND status <> 'dibatalkan')`,
		idPembeli).Scan(&ada)
	return ada, petakan(err)
}
