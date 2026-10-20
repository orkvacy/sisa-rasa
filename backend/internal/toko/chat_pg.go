package toko

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5"
)

const kolomChat = `id, id_pesanan, peran, teks, waktu, dibaca_pada, diubah`

func pindaiChat(baris pgx.Row) (PesanChat, error) {
	var p PesanChat
	err := baris.Scan(&p.ID, &p.IDPesanan, &p.Peran, &p.Teks, &p.Waktu, &p.DibacaPada, &p.Diubah)
	return p, err
}

func (s StorePG) daftarChat(ctx context.Context, sql string, arg ...any) ([]PesanChat, error) {
	baris, err := s.Pool.Query(ctx, sql, arg...)
	if err != nil {
		return nil, petakan(err)
	}
	hasil, err := pgx.CollectRows(baris, func(r pgx.CollectableRow) (PesanChat, error) { return pindaiChat(r) })
	if hasil == nil {
		hasil = []PesanChat{}
	}
	return hasil, petakan(err)
}

func (s StorePG) SimpanPesan(ctx context.Context, p PesanChat) (PesanChat, error) {
	// ON CONFLICT DO NOTHING: kiriman ulang dengan id sama ga nimpa / dobel,
	// lalu baris yang tersimpan (lama atau baru) dibaca lagi
	if _, err := s.Pool.Exec(ctx, `
		INSERT INTO pesan_chat (id_pesanan, id, peran, teks, waktu, diubah)
		VALUES ($1, $2, $3, $4, $5, $5)
		ON CONFLICT (id_pesanan, id) DO NOTHING`,
		p.IDPesanan, p.ID, p.Peran, p.Teks, p.Waktu); err != nil {
		return PesanChat{}, petakan(err)
	}
	hasil, err := pindaiChat(s.Pool.QueryRow(ctx, `SELECT `+kolomChat+`
		FROM pesan_chat WHERE id_pesanan = $1 AND id = $2`, p.IDPesanan, p.ID))
	return hasil, petakan(err)
}

func (s StorePG) DaftarPesan(ctx context.Context, idPesanan string) ([]PesanChat, error) {
	return s.daftarChat(ctx, `SELECT `+kolomChat+`
		FROM pesan_chat WHERE id_pesanan = $1 ORDER BY waktu, id`, idPesanan)
}

func (s StorePG) TandaiDibaca(ctx context.Context, idPesanan, oleh string, sekarang time.Time) error {
	_, err := s.Pool.Exec(ctx, `
		UPDATE pesan_chat SET dibaca_pada = $3, diubah = $3
		WHERE id_pesanan = $1 AND peran <> $2 AND dibaca_pada IS NULL`,
		idPesanan, oleh, sekarang)
	return petakan(err)
}

func (s StorePG) PesanBaru(ctx context.Context, idAkun, peran string, setelah time.Time) ([]PesanChat, error) {
	kolom := "p.id_pembeli = $1"
	if peran == "mitra" {
		kolom = "p.id_mitra = $1 AND p.dibayar_pada IS NOT NULL"
	}
	return s.daftarChat(ctx, `
		SELECT c.id, c.id_pesanan, c.peran, c.teks, c.waktu, c.dibaca_pada, c.diubah
		FROM pesan_chat c JOIN pesanan p ON p.id = c.id_pesanan
		WHERE `+kolom+` AND c.diubah > $2
		ORDER BY c.diubah LIMIT 500`, idAkun, setelah)
}
