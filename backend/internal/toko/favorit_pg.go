package toko

import (
	"context"

	"github.com/jackc/pgx/v5"
)

func (s StorePG) Favorit(ctx context.Context, idPembeli string) ([]MitraFavorit, error) {
	// mitra yang udah hapus akun ga ditampilin lagi
	baris, err := s.Pool.Query(ctx, `
		SELECT a.id::text, a.nama, COALESCE(g.jenis, 'Mitra')
		FROM favorit f
		JOIN akun a ON a.id = f.id_mitra
		LEFT JOIN gerai g ON g.id_akun = f.id_mitra
		WHERE f.id_pembeli = $1 AND a.dihapus_pada IS NULL
		ORDER BY f.dibuat DESC`, idPembeli)
	if err != nil {
		return nil, petakan(err)
	}
	hasil, err := pgx.CollectRows(baris, pgx.RowToStructByPos[MitraFavorit])
	if hasil == nil {
		hasil = []MitraFavorit{}
	}
	return hasil, petakan(err)
}

func (s StorePG) AturFavorit(ctx context.Context, idPembeli, idMitra string, suka bool) error {
	if !suka {
		_, err := s.Pool.Exec(ctx,
			`DELETE FROM favorit WHERE id_pembeli = $1 AND id_mitra = $2`, idPembeli, idMitra)
		return petakan(err)
	}
	// cuma mitra yang masih aktif yang bisa difavoritin
	tag, err := s.Pool.Exec(ctx, `
		INSERT INTO favorit (id_pembeli, id_mitra)
		SELECT $1, a.id FROM akun a
		WHERE a.id = $2 AND a.peran = 'mitra' AND a.dihapus_pada IS NULL
		ON CONFLICT DO NOTHING`, idPembeli, idMitra)
	if err != nil {
		return petakan(err)
	}
	if tag.RowsAffected() == 0 {
		// 0 baris: udah difavoritin sebelumnya (ga apa-apa), atau mitranya ga ada
		var ada bool
		if err := s.Pool.QueryRow(ctx,
			`SELECT EXISTS (SELECT 1 FROM akun WHERE id = $1 AND peran = 'mitra' AND dihapus_pada IS NULL)`,
			idMitra).Scan(&ada); err != nil {
			return petakan(err)
		}
		if !ada {
			return ErrTidakAda
		}
	}
	return nil
}
