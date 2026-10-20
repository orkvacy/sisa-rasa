-- percakapan pembeli - mitra per pesanan (F-67 s.d. F-70)
CREATE TABLE pesan_chat (
    id_pesanan  UUID NOT NULL REFERENCES pesanan (id) ON DELETE CASCADE,
    -- id dibuat aplikasi, jadi kiriman ulang dengan id sama ga dicatat dua kali (NF-18)
    id          TEXT NOT NULL CHECK (length(id) BETWEEN 8 AND 64),
    peran       TEXT NOT NULL CHECK (peran IN ('pembeli', 'mitra')),
    teks        TEXT NOT NULL CHECK (length(teks) BETWEEN 1 AND 500),
    waktu       TIMESTAMPTZ NOT NULL DEFAULT now(),
    dibaca_pada TIMESTAMPTZ,
    -- kapan baris ini terakhir berubah (dikirim / dibaca), dipakai aplikasi
    -- buat narik yang baru aja: GET /v1/pesan/baru?setelah=...
    diubah      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (id_pesanan, id)
);
CREATE INDEX pesan_chat_diubah ON pesan_chat (diubah);
