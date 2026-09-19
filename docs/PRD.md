# PRD Sisa Rasa

> Dokumen terkait: [RENCANA-INCREMENT.md](RENCANA-INCREMENT.md) (metode dan rencana kerja per minggu) · [MILESTONE.md](MILESTONE.md) (buat track progress)

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
- **Ada ketentuan yang dibuat.** Porsi terbatas, menu tidak bisa dipilih bebas, dan pengambilan dilakukan sendiri pada slot jam yang sempit.

Ketiganya memisahkan dua kelompok pembeli. Yang mementingkan kepastian dan
kenyamanan tetap membeli pada harga penuh, sementara yang benar-benar sensitif
harga mengisi porsi yang tadinya berakhir di tempat sampah. Artinya yang
diambil bukan pendapatan penuh mitra, melainkan pendapatan yang selama ini
bernilai nol.

Cara kerjanya tiga langkah:

1. **Mitra mengunggah paket.** Makanan berlebih hari itu ditawarkan dengan harga
   diskon, lengkap dengan jumlah porsi dan slot jam pengambilan.
2. **Pembeli memesan.** Pembeli memilih paket, memesan lewat aplikasi, dan
   menerima kode ambil.
3. **Pengambilan di tempat.** Pembeli datang pada slot jam yang ditentukan,
   menunjukkan kode, dan membayar di tempat.

Dokumen ini adalah PRD untuk **aplikasi mobile-nya saja**, Isinya menjawab satu hal: apa yang dibangun dan mengapa. Jadi ini bukan PRD Bisnis nya

---

## 2. Ruang lingkup

Dua peran (sementara), dalam satu aplikasi.

| Peran | Lingkup di aplikasi ini |
| --- | --- |
| **Pembeli** | Lengkap: telusuri paket, lihat detail, keranjang, pesan, dapat kode ambil, riwayat pesanan |
| **Mitra usaha** | Hanya sisi jual: unggah paket makanan berlebih, kelola paket miliknya, lihat pesanan masuk, tandai sudah diambil |

Perpindahan peran dilakukan lewat pemilih di menu samping, bukan lewat login.
Ini keputusan sadar: autentikasi tidak diajarkan di pertemuan mana pun sebelum
UTS, dan rute ganda justru jadi bahan bagus untuk GoRouter.

### Di luar lingkup

Bagian ini bersifat mengikat. Menambah salah satunya butuh keputusan sadar, bukan spontan.

- Meja Berbagi, yaitu jalur donasi ke panti atau food bank
- Pembayaran dalam aplikasi. Memakai bayar di tempat saat pengambilan
- Pendaftaran mitra, verifikasi, dan skor higienis
- Chat pembeli–mitra, notifikasi, rating dan ulasan

---
