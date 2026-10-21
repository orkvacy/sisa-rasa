-- F-61 atur ulang kata sandi lewat kode di email. yang disimpan cuma hash kode
-- dan hash tiket, kode aslinya cuma ada di email pengguna
CREATE TABLE reset_sandi (
    id_akun           UUID PRIMARY KEY REFERENCES akun (id) ON DELETE CASCADE,
    -- '' = kodenya udah dipakai (ditukar jadi tiket)
    kode_hash         TEXT NOT NULL,
    kedaluwarsa       TIMESTAMPTZ NOT NULL,
    salah             INT NOT NULL DEFAULT 0,
    dibuat            TIMESTAMPTZ NOT NULL,
    tiket_hash        TEXT UNIQUE,
    tiket_kedaluwarsa TIMESTAMPTZ
);
