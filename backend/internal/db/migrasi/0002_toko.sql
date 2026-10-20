-- gerai mitra, paket yang dijual, dan pesanan pembeli (F-07 s.d. F-28, F-40 s.d. F-46)

-- satu akun mitra = satu gerai. nama gerai = akun.nama
CREATE TABLE gerai (
    id_akun UUID PRIMARY KEY REFERENCES akun (id) ON DELETE CASCADE,
    jenis   TEXT NOT NULL DEFAULT 'Mitra',
    alamat  TEXT NOT NULL DEFAULT '',
    -- sementara teks tetap, nanti dihitung dari lokasi pembeli (F-66)
    jarak   TEXT NOT NULL DEFAULT '',
    -- F-51: mitra tutup sementara, paketnya ga tampil ke pembeli
    tutup   BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE paket (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_mitra     UUID NOT NULL REFERENCES akun (id) ON DELETE CASCADE,
    nama         TEXT NOT NULL CHECK (length(nama) BETWEEN 1 AND 80),
    deskripsi    TEXT NOT NULL DEFAULT '',
    kategori     TEXT NOT NULL,
    foto         TEXT NOT NULL DEFAULT '',
    halal        BOOLEAN NOT NULL DEFAULT false,
    meja_berbagi BOOLEAN NOT NULL DEFAULT false,
    harga_asli   INTEGER NOT NULL CHECK (harga_asli > 0),
    -- F-16: harga diskon harus lebih murah dari harga asli
    harga_diskon INTEGER NOT NULL CHECK (harga_diskon >= 0 AND harga_diskon < harga_asli),
    total_porsi  INTEGER NOT NULL CHECK (total_porsi > 0),
    -- F-23: berkurang pas pesanan dibuat, ga boleh minus
    sisa_porsi   INTEGER NOT NULL CHECK (sisa_porsi >= 0 AND sisa_porsi <= total_porsi),
    -- jam ambil dalam menit dari tengah malam WITA (17 * 60 = 17.00)
    mulai        INTEGER NOT NULL CHECK (mulai BETWEEN 0 AND 1439),
    tutup        INTEGER NOT NULL CHECK (tutup BETWEEN 1 AND 1440 AND tutup > mulai),
    nonaktif     BOOLEAN NOT NULL DEFAULT false,
    -- dihapus = disembunyikan, baris tetap ada karena dirujuk isi pesanan lama
    dihapus      BOOLEAN NOT NULL DEFAULT false,
    dibuat       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX paket_mitra ON paket (id_mitra) WHERE NOT dihapus;

CREATE TABLE pesanan (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- nomor yang ditampilkan, misal SR-2610201234
    nomor            TEXT NOT NULL UNIQUE,
    id_pembeli       UUID NOT NULL REFERENCES akun (id),
    id_mitra         UUID NOT NULL REFERENCES akun (id),
    -- disalin pas dibuat, biar riwayat ga berubah kalau mitra / pembeli ganti nama
    nama_pembeli     TEXT NOT NULL,
    nama_mitra       TEXT NOT NULL,
    alamat           TEXT NOT NULL,
    foto             TEXT NOT NULL,
    mulai            INTEGER NOT NULL,
    tutup            INTEGER NOT NULL,
    status           TEXT NOT NULL CHECK (status IN
        ('menunggu_bayar', 'disiapkan', 'siap_diambil', 'selesai', 'dibatalkan', 'tidak_diambil')),
    metode           TEXT NOT NULL,
    -- kode ambil, baru dibuat setelah lunas (F-11)
    kode             TEXT,
    subtotal         INTEGER NOT NULL,
    harga_normal     INTEGER NOT NULL,
    biaya_layanan    INTEGER NOT NULL,
    total            INTEGER NOT NULL,
    -- menit pas dipesan, dipakai layar buat "dipesan 16.20"
    dipesan_menit    INTEGER NOT NULL,
    batas_bayar      TIMESTAMPTZ NOT NULL,
    batas_menit      INTEGER NOT NULL,
    dibuat           TIMESTAMPTZ NOT NULL DEFAULT now(),
    dibayar_pada     TIMESTAMPTZ,
    dibayar_menit    INTEGER,
    diambil_pada     TIMESTAMPTZ,
    dibatalkan_pada  TIMESTAMPTZ,
    alasan           TEXT,
    otomatis         BOOLEAN NOT NULL DEFAULT false,
    oleh_mitra       BOOLEAN NOT NULL DEFAULT false,
    -- isi QR / nomor VA dari penyedia pembayaran
    tagihan          JSONB NOT NULL DEFAULT '{}',
    -- idempotency: request buat pesanan yang dikirim ulang dengan kunci sama
    -- dapet pesanan yang sama, bukan pesanan kedua
    kunci_idempotensi TEXT NOT NULL,
    sidik_isi         TEXT NOT NULL,
    UNIQUE (id_pembeli, kunci_idempotensi)
);
CREATE INDEX pesanan_pembeli ON pesanan (id_pembeli, dibuat DESC);
CREATE INDEX pesanan_mitra ON pesanan (id_mitra, dibuat DESC);
-- dipakai pembersih batas bayar (F-40)
CREATE INDEX pesanan_menunggu ON pesanan (batas_bayar) WHERE status = 'menunggu_bayar';
-- kode ambil unik selama pesanannya masih bisa diambil
CREATE UNIQUE INDEX pesanan_kode_aktif ON pesanan (kode)
    WHERE status IN ('disiapkan', 'siap_diambil');

CREATE TABLE pesanan_isi (
    id_pesanan UUID NOT NULL REFERENCES pesanan (id) ON DELETE CASCADE,
    id_paket   UUID NOT NULL REFERENCES paket (id),
    nama       TEXT NOT NULL,
    deskripsi  TEXT NOT NULL,
    foto       TEXT NOT NULL,
    harga      INTEGER NOT NULL,
    harga_asli INTEGER NOT NULL,
    jumlah     INTEGER NOT NULL CHECK (jumlah > 0),
    PRIMARY KEY (id_pesanan, id_paket)
);
