-- akun pembeli, mitra, dan admin (F-26, F-29, F-31, F-36)
CREATE TABLE akun (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nama       TEXT NOT NULL CHECK (length(nama) BETWEEN 2 AND 100),
    -- selalu disimpan huruf kecil, jadi unik tanpa peduli kapital
    email      TEXT NOT NULL UNIQUE CHECK (email = lower(email)),
    -- F-31: cuma hash bcrypt, kata sandi asli ga pernah disimpan
    hash_sandi TEXT NOT NULL,
    peran      TEXT NOT NULL CHECK (peran IN ('pembeli', 'mitra', 'admin')),
    dibuat     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- token sesi. yang disimpan hash SHA-256 token-nya, token asli cuma ada di HP (NF-14)
CREATE TABLE sesi (
    token_hash  TEXT PRIMARY KEY,
    id_akun     UUID NOT NULL REFERENCES akun (id) ON DELETE CASCADE,
    dibuat      TIMESTAMPTZ NOT NULL DEFAULT now(),
    kedaluwarsa TIMESTAMPTZ NOT NULL,
    -- F-33: keluar = diisi, bukan dihapus, biar ada jejaknya
    dicabut     TIMESTAMPTZ
);

CREATE INDEX sesi_id_akun ON sesi (id_akun);
