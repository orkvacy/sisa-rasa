-- mitra favorit pembeli (ikon hati di halaman mitra)
CREATE TABLE favorit (
    id_pembeli UUID NOT NULL REFERENCES akun (id) ON DELETE CASCADE,
    id_mitra   UUID NOT NULL REFERENCES akun (id) ON DELETE CASCADE,
    dibuat     TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (id_pembeli, id_mitra)
);

-- buat ngitung berapa pembeli yang nyimpen satu mitra (nanti di dasbor mitra)
CREATE INDEX favorit_id_mitra ON favorit (id_mitra);
