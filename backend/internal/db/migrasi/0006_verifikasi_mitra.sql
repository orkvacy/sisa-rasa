-- F-37: mitra baru diverifikasi admin dulu sebelum paketnya tampil ke pembeli.
-- gerai yang udah ada (mitra contoh) dianggap sudah terverifikasi,
-- gerai baru mulai dari 'menunggu'
ALTER TABLE gerai ADD COLUMN status TEXT NOT NULL DEFAULT 'terverifikasi'
    CHECK (status IN ('menunggu', 'terverifikasi', 'ditolak', 'nonaktif'));
ALTER TABLE gerai ALTER COLUMN status SET DEFAULT 'menunggu';
-- alasan ditolak / dinonaktifkan, ditampilkan ke mitra
ALTER TABLE gerai ADD COLUMN alasan TEXT;
ALTER TABLE gerai ADD COLUMN diperiksa_pada TIMESTAMPTZ;
