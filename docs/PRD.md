# PRD Sisa Rasa

> Dokumen terkait: [SRS](srs.md) (daftar kebutuhan yang bisa dicek satu per satu)

## 1. Tentang Sisa Rasa

Setiap hari hotel, restoran, dan bakery membuang makanan yang sebenarnya masih layak, bukan karena rusak, tapi karena tidak habis terjual sebelum toko tutup. Di kota yang sama, mahasiswa dan keluarga justru sedang mencari makanan berkualitas dengan harga terjangkau.

Kalau begitu, mengapa pelaku usaha tidak menjual murah saja menjelang tutup? Karena bagi mereka itu pedang bermata dua. Begitu pembeli tahu harga selalu turun menjelang tutup, sebagian akan sengaja menunggu, dan pendapatan harga
penuh berpindah menjadi pendapatan harga diskon. Banyak usaha akhirnya memilih membuang: rugi sekali buang lebih mudah dihitung daripada kebiasaan pembeli
yang terlanjur berubah.

Sisa Rasa menutup celah itu dengan membuat menunggu menjadi pilihan yang tidak
menarik, lewat tiga batasan yang melekat pada produknya:

- **Kendali ada di mitra.** Mitra sendiri yang menentukan menu apa, berapa
  porsi, dan jam berapa dilepas. Menu yang lakunya bagus tidak perlu ditawarkan
  sama sekali.
- **Stock sengaja tidak pasti.** Tidak ada jaminan hari ini ada paket, atau paket yang diincar masih tersisa. Pembeli yang picky eater sudah pasti tidak bisa berharap lebih.
- **Ada ketentuan yang dibuat.** Porsi terbatas, pembeli hanya memilih di antara paket yang dilepas mitra (bukan menu bebas), dan pengambilan dilakukan sendiri sebelum jam tutup yang sempit.

Ketiganya memisahkan dua kelompok pembeli. Yang mementingkan kepastian dan
kenyamanan tetap membeli pada harga penuh, sementara yang benar-benar sensitif
harga mengisi porsi yang tadinya berakhir di tempat sampah. Artinya yang
diambil bukan pendapatan penuh mitra, melainkan pendapatan yang selama ini
bernilai nol.

Cara kerjanya tiga langkah:

1. **Mitra mengunggah paket.** Makanan berlebih hari itu ditawarkan dengan harga
   diskon, lengkap dengan jumlah porsi dan jam tutup pengambilan.
2. **Pembeli memesan.** Pembeli memilih paket, membayar lewat aplikasi (QRIS,
   GoPay, atau Virtual Account), dan menerima kode ambil.
3. **Pengambilan di tempat.** Pembeli datang sebelum jam tutup ambil
   dan menunjukkan kode.

Dokumen ini adalah PRD untuk **aplikasi mobile-nya saja**, Isinya menjawab satu hal: apa yang dibangun dan mengapa. Jadi ini bukan PRD Bisnis nya

---

## 2. Ruang lingkup

Tiga peran dalam satu aplikasi.

| Peran | Lingkup di aplikasi ini |
| --- | --- |
| **Pembeli** | Telusuri mitra yang masih punya paket (urut jam tutup terdekat, Flash sale untuk yang segera tutup), buka halaman mitra untuk memilih paket atau beli satuan, lihat detail, keranjang, checkout, bayar (QRIS, GoPay, VA), status pesanan bertahap dengan kode QR, riwayat pesanan (berlangsung, selesai, dibatalkan) beserta petunjuk arah dan hubungi mitra |
| **Mitra usaha** | Dasbor hari ini, kelola paket (stok cepat, aktif/nonaktif), pesanan masuk (tandai siap, serahkan), scan kode ambil atau ketik manual, saldo dengan pencairan otomatis ke rekening |
| **Admin** | Verifikasi mitra, nonaktifkan mitra atau paket yang melanggar, angka keseluruhan platform |

Peran ditentukan oleh akun yang masuk (SRS F-26). Selama tahap awal pengembangan,
sebelum login dibuat, peran boleh dipilih lewat pemilih sementara di layar
Sambutan supaya navigasi dan tampilan tiap peran bisa dikerjakan lebih dulu.
Pemilih ini dihapus begitu login jalan.

Navigasi memakai pil melayang di bawah layar: pembeli dan admin tiga tab, mitra
lima slot dengan tombol Scan QR di tengah.

### Di luar lingkup

Bagian ini bersifat mengikat. Menambah salah satunya butuh keputusan sadar, bukan spontan.

- Metode bayar selain QRIS, GoPay, dan Virtual Account (termasuk bayar di tempat), saldo pembeli, poin, dan voucher
- Skor higienis mitra
- Chat di dalam aplikasi, rating dan ulasan. Menghubungi mitra cukup lewat telepon atau WhatsApp di luar aplikasi
- Pelacakan lokasi pembeli secara langsung. Petunjuk arah cukup membuka aplikasi peta

Notifikasi masuk lingkup, tapi khusus untuk status pesanan dan pengingat
(batas bayar dan jam tutup ambil), karena alurnya bergantung pada waktu.

Pesanan yang tidak diambil sampai jam tutup ambil bukan lagi tanggung jawab
mitra: dana tidak dikembalikan dan tetap diteruskan ke mitra. Aturan ini
ditampilkan ke pembeli sebelum membayar (SRS F-56).

Meja Berbagi (donasi paket yang tidak terjual) dan verifikasi mitra oleh admin
sudah masuk SRS sebagai kebutuhan opsional (F-22, F-37).

---
