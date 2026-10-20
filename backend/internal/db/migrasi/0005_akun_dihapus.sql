-- F-62 hapus akun: barisnya ga dihapus (dirujuk pesanan, catatan transaksi wajib
-- disimpan), tapi data pribadinya dikosongkan dan akunnya ga bisa dipakai lagi
ALTER TABLE akun ADD COLUMN dihapus_pada TIMESTAMPTZ;
