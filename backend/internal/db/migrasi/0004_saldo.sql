-- rekening pencairan dan pencairan saldo mitra (F-48 s.d. F-50, NF-11)

-- F-49: satu mitra satu rekening, yang baru menggantikan yang lama
CREATE TABLE rekening_mitra (
    id_akun UUID PRIMARY KEY REFERENCES akun (id) ON DELETE CASCADE,
    bank    TEXT NOT NULL,
    nomor   TEXT NOT NULL CHECK (nomor ~ '^[0-9]{6,20}$'),
    nama    TEXT NOT NULL,
    diubah  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE pencairan (
    id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_mitra UUID NOT NULL REFERENCES akun (id),
    jumlah   INTEGER NOT NULL CHECK (jumlah > 0),
    -- rekening tujuan disalin, biar riwayat ga berubah kalau rekening diganti
    bank     TEXT NOT NULL,
    nomor    TEXT NOT NULL,
    nama     TEXT NOT NULL,
    -- Diproses: menunggu transfer. Berhasil / Gagal: hasil transfer
    status   TEXT NOT NULL CHECK (status IN ('Diproses', 'Berhasil', 'Gagal')),
    dibuat   TIMESTAMPTZ NOT NULL,
    -- idempotency: pencairan harian pakai kunci "harian-YYYY-MM-DD", jadi walau
    -- job jalan dua kali (server restart, dua instance), saldo cuma cair sekali
    kunci    TEXT NOT NULL,
    UNIQUE (id_mitra, kunci)
);
CREATE INDEX pencairan_mitra ON pencairan (id_mitra, dibuat DESC);
