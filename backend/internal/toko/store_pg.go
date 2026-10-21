package toko

import (
	"context"
	"errors"
	"sort"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

// StorePG nyimpen gerai, paket, dan pesanan di PostgreSQL
type StorePG struct{ Pool *pgxpool.Pool }

const (
	kodeUnik      = "23505" // unique_violation
	kodeTeksSalah = "22P02" // invalid_text_representation, misal id bukan UUID
)

// petakan galat Postgres yang bisa dimengerti Layanan
func petakan(err error) error {
	var pgErr *pgconn.PgError
	switch {
	case errors.Is(err, pgx.ErrNoRows):
		return ErrTidakAda
	case errors.As(err, &pgErr) && pgErr.Code == kodeTeksSalah:
		return ErrTidakAda
	case errors.As(err, &pgErr) && pgErr.Code == kodeUnik:
		return ErrBentrok
	}
	return err
}

// ---------- paket ----------

const kolomPaket = `
	p.id, p.id_mitra, a.nama, COALESCE(g.jenis, 'Mitra'), COALESCE(g.alamat, ''),
	COALESCE(g.jarak, ''), COALESCE(g.tutup, false), COALESCE(g.status, 'menunggu'), g.lat, g.lng,
	p.nama, p.deskripsi, p.kategori,
	p.foto, p.halal, p.meja_berbagi, p.harga_asli, p.harga_diskon, p.total_porsi,
	p.sisa_porsi, p.mulai, p.tutup, p.nonaktif, p.dihapus`

const dariPaket = `
	FROM paket p
	JOIN akun a ON a.id = p.id_mitra
	LEFT JOIN gerai g ON g.id_akun = p.id_mitra`

func pindaiPaket(baris pgx.Row) (Paket, error) {
	var p Paket
	err := baris.Scan(&p.ID, &p.IDMitra, &p.Mitra, &p.JenisMitra, &p.Alamat,
		&p.Jarak, &p.GeraiTutup, &p.StatusGerai, &p.Lat, &p.Lng, &p.Nama, &p.Deskripsi, &p.Kategori,
		&p.Foto, &p.Halal, &p.MejaBerbagi, &p.HargaAsli, &p.HargaDiskon, &p.TotalPorsi,
		&p.SisaPorsi, &p.Mulai, &p.Tutup, &p.Nonaktif, &p.dihapus)
	return p, err
}

func (s StorePG) daftarPaket(ctx context.Context, sql string, arg ...any) ([]Paket, error) {
	baris, err := s.Pool.Query(ctx, sql, arg...)
	if err != nil {
		return nil, err
	}
	hasil, err := pgx.CollectRows(baris, func(r pgx.CollectableRow) (Paket, error) { return pindaiPaket(r) })
	if hasil == nil {
		hasil = []Paket{}
	}
	return hasil, err
}

func (s StorePG) SemuaPaket(ctx context.Context, idMitra string) ([]Paket, error) {
	return s.daftarPaket(ctx, `SELECT`+kolomPaket+dariPaket+`
		WHERE NOT p.dihapus
		  AND (COALESCE(g.status, 'menunggu') = 'terverifikasi' OR p.id_mitra::text = $1)
		ORDER BY p.tutup, a.nama, p.dibuat`, idMitra)
}

func (s StorePG) PaketMitra(ctx context.Context, idMitra string) ([]Paket, error) {
	hasil, err := s.daftarPaket(ctx, `SELECT`+kolomPaket+dariPaket+`
		WHERE NOT p.dihapus AND p.id_mitra = $1 ORDER BY p.dibuat`, idMitra)
	return hasil, petakan(err)
}

func (s StorePG) satuPaket(ctx context.Context, idMitra, id string) (Paket, error) {
	p, err := pindaiPaket(s.Pool.QueryRow(ctx, `SELECT`+kolomPaket+dariPaket+`
		WHERE p.id = $1 AND p.id_mitra = $2 AND NOT p.dihapus`, id, idMitra))
	return p, petakan(err)
}

func (s StorePG) SimpanGerai(ctx context.Context, idMitra string, g Gerai) error {
	var lat, lng *float64
	if g.Titik != nil {
		lat, lng = &g.Titik.Lat, &g.Titik.Lng
	}
	_, err := s.Pool.Exec(ctx, `
		INSERT INTO gerai (id_akun, jenis, alamat, jarak, status, lat, lng)
		VALUES ($1, $2, $3, $4, 'terverifikasi', $5, $6)
		ON CONFLICT (id_akun) DO UPDATE SET jenis = $2, alamat = $3, jarak = $4,
			status = 'terverifikasi', lat = COALESCE($5, gerai.lat), lng = COALESCE($6, gerai.lng)`,
		idMitra, g.Jenis, g.Alamat, g.Jarak, lat, lng)
	return petakan(err)
}

func (s StorePG) AturLokasi(ctx context.Context, idMitra string, t Titik) error {
	_, err := s.Pool.Exec(ctx, `
		INSERT INTO gerai (id_akun, lat, lng) VALUES ($1, $2, $3)
		ON CONFLICT (id_akun) DO UPDATE SET lat = $2, lng = $3`, idMitra, t.Lat, t.Lng)
	return petakan(err)
}

func (s StorePG) AturGerai(ctx context.Context, idMitra string, tutup bool) error {
	_, err := s.Pool.Exec(ctx, `
		INSERT INTO gerai (id_akun, tutup) VALUES ($1, $2)
		ON CONFLICT (id_akun) DO UPDATE SET tutup = $2`, idMitra, tutup)
	return petakan(err)
}

func (s StorePG) BuatPaket(ctx context.Context, idMitra string, isi IsianPaket) (Paket, error) {
	// mitra baru belum punya baris gerai, dibikin dengan isian bawaan
	if _, err := s.Pool.Exec(ctx,
		`INSERT INTO gerai (id_akun) VALUES ($1) ON CONFLICT (id_akun) DO NOTHING`, idMitra); err != nil {
		return Paket{}, petakan(err)
	}
	var id string
	err := s.Pool.QueryRow(ctx, `
		INSERT INTO paket (id_mitra, nama, deskripsi, kategori, foto, halal, meja_berbagi,
			harga_asli, harga_diskon, total_porsi, sisa_porsi, mulai, tutup)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $10, $11, $12)
		RETURNING id`,
		idMitra, isi.Nama, isi.Deskripsi, isi.Kategori, isi.Foto, isi.Halal, isi.MejaBerbagi,
		isi.HargaAsli, isi.HargaDiskon, isi.TotalPorsi, isi.Mulai, isi.Tutup,
	).Scan(&id)
	if err != nil {
		return Paket{}, petakan(err)
	}
	return s.satuPaket(ctx, idMitra, id)
}

func (s StorePG) ubahSatu(ctx context.Context, idMitra, id, sql string, arg ...any) (Paket, error) {
	tag, err := s.Pool.Exec(ctx, sql, append([]any{id, idMitra}, arg...)...)
	if err != nil {
		return Paket{}, petakan(err)
	}
	if tag.RowsAffected() == 0 {
		return Paket{}, ErrTidakAda
	}
	return s.satuPaket(ctx, idMitra, id)
}

func (s StorePG) UbahPaket(ctx context.Context, idMitra, id string, isi IsianPaket) (Paket, error) {
	// ekspresi di SET baca nilai lama, jadi sisa digeser sebanyak selisih total porsi
	return s.ubahSatu(ctx, idMitra, id, `
		UPDATE paket SET nama = $3, deskripsi = $4, kategori = $5, foto = $6, halal = $7,
			meja_berbagi = $8, harga_asli = $9, harga_diskon = $10, mulai = $12, tutup = $13,
			sisa_porsi = LEAST($11, GREATEST(0, sisa_porsi + $11 - total_porsi)),
			total_porsi = $11
		WHERE id = $1 AND id_mitra = $2 AND NOT dihapus`,
		isi.Nama, isi.Deskripsi, isi.Kategori, isi.Foto, isi.Halal, isi.MejaBerbagi,
		isi.HargaAsli, isi.HargaDiskon, isi.TotalPorsi, isi.Mulai, isi.Tutup)
}

func (s StorePG) AturSisa(ctx context.Context, idMitra, id string, sisa int) (Paket, error) {
	return s.ubahSatu(ctx, idMitra, id, `
		UPDATE paket SET sisa_porsi = LEAST($3, total_porsi)
		WHERE id = $1 AND id_mitra = $2 AND NOT dihapus`, sisa)
}

func (s StorePG) AturAktif(ctx context.Context, idMitra, id string, aktif bool) (Paket, error) {
	return s.ubahSatu(ctx, idMitra, id, `
		UPDATE paket SET nonaktif = NOT $3::boolean
		WHERE id = $1 AND id_mitra = $2 AND NOT dihapus`, aktif)
}

func (s StorePG) HapusPaket(ctx context.Context, idMitra, id string) error {
	tag, err := s.Pool.Exec(ctx, `
		UPDATE paket SET dihapus = true WHERE id = $1 AND id_mitra = $2 AND NOT dihapus`, id, idMitra)
	if err != nil {
		return petakan(err)
	}
	if tag.RowsAffected() == 0 {
		return ErrTidakAda
	}
	return nil
}

// ---------- pesanan ----------

const kolomPesanan = `
	id, nomor, id_pembeli, id_mitra, nama_pembeli, nama_mitra, alamat, foto, mulai, tutup,
	status, metode, kode, subtotal, harga_normal, biaya_layanan, total, dipesan_menit,
	dibuat, batas_bayar, batas_menit, dibayar_pada, dibayar_menit, diambil_pada,
	dibatalkan_pada, alasan, otomatis, oleh_mitra, tagihan, kunci_idempotensi, sidik_isi`

func pindaiPesanan(baris pgx.Row) (Pesanan, error) {
	var p Pesanan
	err := baris.Scan(&p.ID, &p.Nomor, &p.IDAkun, &p.IDMitra, &p.NamaPembeli, &p.Mitra,
		&p.Alamat, &p.Foto, &p.Mulai, &p.Tutup, &p.Status, &p.Metode, &p.Kode,
		&p.Subtotal, &p.HargaNormal, &p.BiayaLayanan, &p.Total, &p.Dipesan,
		&p.Dibuat, &p.BatasBayar, &p.BatasMenit, &p.DibayarPada, &p.Dibayar, &p.DiambilPada,
		&p.DibatalkanPada, &p.Alasan, &p.Otomatis, &p.OlehMitra, &p.Tagihan, &p.kunci, &p.sidik)
	p.Hemat = p.HargaNormal - p.Subtotal
	return p, err
}

// isiPesanan nempelin baris pesanan_isi ke tiap pesanan
func isiPesanan(ctx context.Context, q interface {
	Query(context.Context, string, ...any) (pgx.Rows, error)
}, daftar []Pesanan) error {
	if len(daftar) == 0 {
		return nil
	}
	id := make([]string, len(daftar))
	posisi := make(map[string]int, len(daftar))
	for i, p := range daftar {
		id[i] = p.ID
		posisi[p.ID] = i
	}
	baris, err := q.Query(ctx, `
		SELECT id_pesanan, id_paket, nama, deskripsi, foto, harga, harga_asli, jumlah
		FROM pesanan_isi WHERE id_pesanan = ANY($1::uuid[]) ORDER BY nama`, id)
	if err != nil {
		return err
	}
	defer baris.Close()
	for baris.Next() {
		var idPesanan string
		var isi IsiPesanan
		if err := baris.Scan(&idPesanan, &isi.IDPaket, &isi.Nama, &isi.Deskripsi, &isi.Foto,
			&isi.Harga, &isi.HargaAsli, &isi.Jumlah); err != nil {
			return err
		}
		p := &daftar[posisi[idPesanan]]
		p.Isi = append(p.Isi, isi)
		p.Porsi += isi.Jumlah
	}
	return baris.Err()
}

func (s StorePG) daftarPesanan(ctx context.Context, sql string, arg ...any) ([]Pesanan, error) {
	baris, err := s.Pool.Query(ctx, sql, arg...)
	if err != nil {
		return nil, petakan(err)
	}
	hasil, err := pgx.CollectRows(baris, func(r pgx.CollectableRow) (Pesanan, error) { return pindaiPesanan(r) })
	if err != nil {
		return nil, petakan(err)
	}
	if hasil == nil {
		hasil = []Pesanan{}
	}
	return hasil, isiPesanan(ctx, s.Pool, hasil)
}

func (s StorePG) Pesanan(ctx context.Context, id string) (Pesanan, error) {
	hasil, err := s.daftarPesanan(ctx, `SELECT`+kolomPesanan+` FROM pesanan WHERE id = $1`, id)
	if err != nil {
		return Pesanan{}, err
	}
	if len(hasil) == 0 {
		return Pesanan{}, ErrTidakAda
	}
	return hasil[0], nil
}

func (s StorePG) PesananPembeli(ctx context.Context, idPembeli string) ([]Pesanan, error) {
	return s.daftarPesanan(ctx, `SELECT`+kolomPesanan+`
		FROM pesanan WHERE id_pembeli = $1 ORDER BY dibuat DESC LIMIT 200`, idPembeli)
}

func (s StorePG) PesananMitra(ctx context.Context, idMitra string) ([]Pesanan, error) {
	return s.daftarPesanan(ctx, `SELECT`+kolomPesanan+`
		FROM pesanan WHERE id_mitra = $1 ORDER BY dibuat DESC LIMIT 500`, idMitra)
}

func (s StorePG) BuatPesanan(ctx context.Context, baru PesananBaru,
	susun func(paket []Paket) (Pesanan, error)) (Pesanan, bool, error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return Pesanan{}, false, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	// 1. idempotency: kunci yang sama udah pernah dipakai pembeli ini?
	var lama string
	err = tx.QueryRow(ctx, `
		SELECT id FROM pesanan WHERE id_pembeli = $1 AND kunci_idempotensi = $2`,
		baru.IDPembeli, baru.Kunci).Scan(&lama)
	if err == nil {
		p, err := s.Pesanan(ctx, lama)
		return p, false, err
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return Pesanan{}, false, petakan(err)
	}

	// 2. kunci baris paket yang dipesan. urut id biar dua pesanan barengan
	//    ga saling nunggu (deadlock). pesanan lain buat paket yg sama antre di sini
	id := make([]string, 0, len(baru.Isi))
	for k := range baru.Isi {
		id = append(id, k)
	}
	sort.Strings(id)
	baris, err := tx.Query(ctx, `SELECT`+kolomPaket+dariPaket+`
		WHERE p.id = ANY($1::uuid[]) ORDER BY p.id FOR UPDATE OF p`, id)
	if err != nil {
		return Pesanan{}, false, petakan(err)
	}
	paket, err := pgx.CollectRows(baris, func(r pgx.CollectableRow) (Paket, error) { return pindaiPaket(r) })
	if err != nil {
		return Pesanan{}, false, petakan(err)
	}

	// 3. cek stok + hitung harga (aturan bisnisnya di Layanan.susun)
	p, err := susun(paket)
	if err != nil {
		return Pesanan{}, false, err
	}

	// 4. simpan pesanan + isinya, lalu kurangi stok (F-23)
	_, err = tx.Exec(ctx, `
		INSERT INTO pesanan (id, nomor, id_pembeli, id_mitra, nama_pembeli, nama_mitra, alamat,
			foto, mulai, tutup, status, metode, subtotal, harga_normal, biaya_layanan, total,
			dipesan_menit, dibuat, batas_bayar, batas_menit, tagihan, kunci_idempotensi, sidik_isi)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16,
			$17, $18, $19, $20, $21, $22, $23)`,
		p.ID, p.Nomor, p.IDAkun, p.IDMitra, p.NamaPembeli, p.Mitra, p.Alamat,
		p.Foto, p.Mulai, p.Tutup, p.Status, p.Metode, p.Subtotal, p.HargaNormal, p.BiayaLayanan, p.Total,
		p.Dipesan, p.Dibuat, p.BatasBayar, p.BatasMenit, p.Tagihan, p.kunci, p.sidik)
	if err != nil {
		// nomor kembar, atau request kembar dengan kunci sama selesai duluan:
		// Layanan ngulang, dan percobaan berikutnya ketemu pesanan lama di langkah 1
		return Pesanan{}, false, petakan(err)
	}
	for _, isi := range p.Isi {
		if _, err := tx.Exec(ctx, `
			INSERT INTO pesanan_isi (id_pesanan, id_paket, nama, deskripsi, foto, harga, harga_asli, jumlah)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
			p.ID, isi.IDPaket, isi.Nama, isi.Deskripsi, isi.Foto, isi.Harga, isi.HargaAsli, isi.Jumlah); err != nil {
			return Pesanan{}, false, petakan(err)
		}
		if _, err := tx.Exec(ctx, `
			UPDATE paket SET sisa_porsi = sisa_porsi - $2 WHERE id = $1`, isi.IDPaket, isi.Jumlah); err != nil {
			return Pesanan{}, false, petakan(err)
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return Pesanan{}, false, petakan(err)
	}
	return p, true, nil
}

func (s StorePG) UbahPesanan(ctx context.Context, id string,
	ubah func(p *Pesanan) (Perubahan, error)) (Pesanan, error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return Pesanan{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	p, err := pindaiPesanan(tx.QueryRow(ctx, `SELECT`+kolomPesanan+`
		FROM pesanan WHERE id = $1 FOR UPDATE`, id))
	if err != nil {
		return Pesanan{}, petakan(err)
	}
	daftar := []Pesanan{p}
	if err := isiPesanan(ctx, tx, daftar); err != nil {
		return Pesanan{}, err
	}
	p = daftar[0]

	perubahan, err := ubah(&p)
	if err != nil {
		return Pesanan{}, err
	}
	_, err = tx.Exec(ctx, `
		UPDATE pesanan SET status = $2, metode = $3, kode = $4, dibayar_pada = $5,
			dibayar_menit = $6, diambil_pada = $7, dibatalkan_pada = $8, alasan = $9,
			otomatis = $10, oleh_mitra = $11, tagihan = $12
		WHERE id = $1`,
		p.ID, p.Status, p.Metode, p.Kode, p.DibayarPada, p.Dibayar, p.DiambilPada,
		p.DibatalkanPada, p.Alasan, p.Otomatis, p.OlehMitra, p.Tagihan)
	if err != nil {
		return Pesanan{}, petakan(err)
	}
	if perubahan.KembalikanStok {
		for _, isi := range p.Isi {
			if _, err := tx.Exec(ctx, `
				UPDATE paket SET sisa_porsi = LEAST(total_porsi, sisa_porsi + $2) WHERE id = $1`,
				isi.IDPaket, isi.Jumlah); err != nil {
				return Pesanan{}, petakan(err)
			}
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return Pesanan{}, petakan(err)
	}
	return p, nil
}

func (s StorePG) MenungguLewat(ctx context.Context, sekarang time.Time) ([]string, error) {
	baris, err := s.Pool.Query(ctx, `
		SELECT id FROM pesanan WHERE status = 'menunggu_bayar' AND batas_bayar <= $1 LIMIT 200`,
		sekarang)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(baris, pgx.RowTo[string])
}
