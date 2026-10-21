-- voucher platform: dibuat admin, potongannya ditanggung platform. penerimaan
-- mitra tetap dihitung dari subtotal (harga paket), jadi mitra ga dirugikan
CREATE TABLE voucher (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kode          TEXT NOT NULL UNIQUE CHECK (kode ~ '^[A-Z0-9]{4,20}$'),
    judul         TEXT NOT NULL,
    persen        INT NOT NULL CHECK (persen BETWEEN 1 AND 100),
    maks_potongan INT NOT NULL CHECK (maks_potongan > 0),
    min_belanja   INT NOT NULL DEFAULT 0 CHECK (min_belanja >= 0),
    mulai         TIMESTAMPTZ NOT NULL,
    berakhir      TIMESTAMPTZ NOT NULL CHECK (berakhir > mulai),
    -- NULL = kuota ga dibatasi
    kuota         INT CHECK (kuota > 0),
    terpakai      INT NOT NULL DEFAULT 0 CHECK (terpakai >= 0),
    khusus_baru   BOOLEAN NOT NULL DEFAULT false,
    -- false = kode rahasia, ga tampil di daftar voucher aplikasi
    publik        BOOLEAN NOT NULL DEFAULT true,
    aktif         BOOLEAN NOT NULL DEFAULT true,
    dibuat        TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE pesanan ADD COLUMN potongan INT NOT NULL DEFAULT 0 CHECK (potongan >= 0);
ALTER TABLE pesanan ADD COLUMN kode_voucher TEXT;
ALTER TABLE pesanan ADD COLUMN id_voucher UUID REFERENCES voucher (id);
