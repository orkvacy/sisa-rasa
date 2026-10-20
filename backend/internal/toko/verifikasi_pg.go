package toko

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5"
)

func (s StorePG) StatusGerai(ctx context.Context, idMitra string) (StatusGerai, error) {
	// mitra yang belum punya baris gerai (baru daftar, belum bikin paket) = menunggu
	var st StatusGerai
	err := s.Pool.QueryRow(ctx, `
		SELECT COALESCE(g.status, 'menunggu'), g.alasan
		FROM akun a LEFT JOIN gerai g ON g.id_akun = a.id
		WHERE a.id = $1 AND a.peran = 'mitra'`, idMitra).Scan(&st.Status, &st.Alasan)
	return st, petakan(err)
}

func (s StorePG) DaftarMitra(ctx context.Context, status string) ([]MitraAdmin, error) {
	baris, err := s.Pool.Query(ctx, `
		SELECT a.id, a.nama, a.email, COALESCE(g.jenis, 'Mitra'), COALESCE(g.alamat, ''),
			COALESCE(g.status, 'menunggu'), g.alasan,
			(SELECT count(*) FROM paket p WHERE p.id_mitra = a.id AND NOT p.dihapus),
			a.dibuat
		FROM akun a LEFT JOIN gerai g ON g.id_akun = a.id
		WHERE a.peran = 'mitra' AND a.dihapus_pada IS NULL
		  AND ($1 = '' OR COALESCE(g.status, 'menunggu') = $1)
		ORDER BY a.dibuat DESC`, status)
	if err != nil {
		return nil, petakan(err)
	}
	hasil, err := pgx.CollectRows(baris, func(r pgx.CollectableRow) (MitraAdmin, error) {
		var m MitraAdmin
		err := r.Scan(&m.ID, &m.Nama, &m.Email, &m.Jenis, &m.Alamat, &m.Status, &m.Alasan,
			&m.JumlahPaket, &m.Daftar)
		return m, err
	})
	if hasil == nil {
		hasil = []MitraAdmin{}
	}
	return hasil, petakan(err)
}

func (s StorePG) PeriksaMitra(ctx context.Context, idMitra, status string, alasan *string, sekarang time.Time) error {
	var mitra bool
	if err := s.Pool.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM akun WHERE id = $1 AND peran = 'mitra')`, idMitra,
	).Scan(&mitra); err != nil {
		return petakan(err)
	}
	if !mitra {
		return ErrTidakAda
	}
	_, err := s.Pool.Exec(ctx, `
		INSERT INTO gerai (id_akun, status, alasan, diperiksa_pada) VALUES ($1, $2, $3, $4)
		ON CONFLICT (id_akun) DO UPDATE SET status = $2, alasan = $3, diperiksa_pada = $4`,
		idMitra, status, alasan, sekarang)
	return petakan(err)
}
