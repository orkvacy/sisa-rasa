# SRS — Sisa Rasa Mobile

**Spesifikasi Kebutuhan Perangkat Lunak**

**Versi:** 1.5 - 2 Oktober 2026

> Dokumen terkait: [PRD.md](PRD.md) (latar belakang produk dan alasannya) · [RENCANA-INCREMENT.md](RENCANA-INCREMENT.md) (metode dan urutan kerja) · [MILESTONE.md](MILESTONE.md) (track progress)

---

## 1. Pendahuluan

### 1.1 Tujuan dokumen

Dokumen ini menetapkan kebutuhan perangkat lunak aplikasi mobile Sisa Rasa
secara terperinci dan dapat diperiksa satu per satu terhadap aplikasi yang
jadi. Pertanyaan "mengapa produk ini dibuat" dijawab di PRD, dokumen ini
menjawab "apa saja yang harus bisa dilakukan sistem".

### 1.2 Ruang lingkup perangkat lunak

Aplikasi mobile berbasis Flutter yang mempertemukan mitra usaha yang memiliki
makanan berlebih dengan pembeli yang mencari makanan murah. Mitra menawarkan
paket makanan hari itu dengan harga diskon, pembeli memesan dan membayar lewat
aplikasi (QRIS, GoPay, atau Virtual Account), menerima kode ambil, lalu
mengambil sendiri sebelum jam tutup ambil yang ditentukan mitra.

Aplikasi berkomunikasi dengan server sendiri, sehingga mitra dan pembeli dapat
memakai perangkat yang berbeda dan datanya menetap.

Dibangun bertahap sebagai posttest praktikum sekaligus bahan portofolio.

### 1.3 Dokumen terkait

- `PRD.md` — latar belakang produk dan alasan perancangan
- `RENCANA-INCREMENT.md` - metode pengembangan dan urutan pengerjaan(utamain MVP)
- `MILESTONE.md` - buat track progress
- `API.md` - rancangan backend

---

## 2. Deskripsi umum


### 2.1 Karakteristik pengguna

| Pengguna | Ciri | Yang dibutuhkan |
| --- | --- | --- |
| **Pembeli** | Mahasiswa dan keluarga, sensitif harga, terbiasa aplikasi belanja | Menemukan paket murah dengan cepat, tahu berapa hematnya, tahu kapan harus mengambil |
| **Mitra usaha** | Pegawai hotel, restoran, bakery. Waktunya sempit menjelang tutup | Mengunggah paket dalam hitungan menit, melihat pesanan masuk, menandai sudah diambil |
| **Admin** | Pengelola platform | Memverifikasi mitra, menonaktifkan yang melanggar, melihat angka keseluruhan |

### 2.2 Batasan perangkat lunak

| Kode | Batasan |
| --- | --- |
| B-01 | Dibangun dengan Flutter dan Dart, null safety aktif |
| B-02 | Navigasi memakai GoRouter |
| B-03 | State management memakai Cubit/BLoC dengan `flutter_bloc` |
| B-04 | Arsitektur mengikuti Clean Architecture dengan GetIt sebagai dependency injection |
| B-05 | Backend menggunakan Go |
| B-06 | Seluruh gambar berupa aset lokal, tidak diambil dari jaringan |
| B-07 | Target platform Android |

## 3. Kebutuhan fungsional

Prioritas: **W** wajib, **S** sebaiknya, **O** opsional. Kebutuhan berprioritas
W tidak boleh dikorbankan dengan alasan apa pun. Kebutuhan berprioritas O
dikerjakan paling akhir, setelah seluruh W dan S tuntas.

### 3.1 Pembeli

| ID | Kebutuhan | Prioritas |
| --- | --- | --- |
| F-01 | Sistem menampilkan daftar mitra yang punya paket tersedia, diurutkan dari jam tutup ambil terdekat, beserta foto, nama, jenis, jarak, jam tutup ambil, jumlah paket, dan harga paket termurah. Jam tutup yang kurang dari 1 jam lagi diberi tanda mendesak | W |
| F-02 | Sistem menampilkan detail satu paket beserta deskripsi, info mitra, alamat, dan jumlah rupiah yang dihemat | W |
| F-03 | Pengguna dapat menyaring daftar paket berdasarkan kategori | W |
| F-04 | Pengguna dapat mencari paket berdasarkan nama paket atau nama mitra | S |
| F-05 | Pengguna dapat memilih jumlah porsi, dan sistem membatasinya pada sisa porsi yang tersedia | W |
| F-06 | Pengguna dapat menambahkan paket ke keranjang | W |
| F-07 | Keranjang hanya berisi paket dari satu mitra. Sistem meminta konfirmasi pengosongan keranjang bila pengguna menambahkan paket dari mitra lain, baik dari halaman mitra, detail paket, maupun tombol tambah cepat | W |
| F-08 | Pengguna dapat mengubah jumlah dan menghapus item di keranjang | W |
| F-09 | Sistem menampilkan subtotal dan total penghematan pada keranjang dan ringkasan pesanan | W |
| F-10 | Pengguna dapat membuat pesanan dan membayarnya di aplikasi dengan QRIS, GoPay, atau Virtual Account bank | W |
| F-11 | Sistem menerbitkan kode ambil acak berawalan `SR-` untuk setiap pesanan yang sudah dibayar | W |
| F-12 | Sistem menampilkan riwayat pesanan yang dapat disaring menjadi Berlangsung (menunggu bayar, disiapkan, siap diambil), Selesai, dan Dibatalkan, dan pesanan batal menampilkan alasan serta status pengembalian dana | W |
| F-13 | Pengguna dapat menandai paket sebagai favorit | O |
| F-40 | Sistem menahan porsi pesanan selama batas waktu bayar 15 menit (tidak melewati jam tutup ambil), lalu membatalkan pesanan dan mengembalikan porsinya bila belum dibayar | W |
| F-41 | Sistem menampilkan status pesanan bertahap (Menunggu pembayaran → Diproses → Siap diambil → Selesai, atau Dibatalkan) beserta isi pesanan, rincian pembayaran, metode bayar, dan ID pesanan | W |
| F-42 | Sistem mengembalikan dana pembeli bila pesanan yang sudah dibayar dibatalkan mitra atau paketnya tidak tersedia | S |
| F-52 | Kartu pesanan berlangsung punya pintasan untuk menampilkan kode QR, membuka petunjuk arah ke titik mitra di aplikasi peta, dan menghubungi mitra lewat telepon atau WhatsApp di luar aplikasi | S |
| F-53 | Beranda menampilkan bagian Flash sale di atas daftar, berisi mitra yang jam tutup ambilnya kurang dari 1 jam lagi dalam bentuk kartu yang dapat digeser mendatar. Mitra yang tampil di Flash sale tidak muncul lagi di daftar di bawahnya, dan bagian ini disembunyikan bila tidak ada mitra yang memenuhi | S |
| F-54 | Sistem menampilkan halaman mitra berisi nama, jenis, alamat, jarak, jam tutup ambil, sisa waktu, tombol petunjuk arah, dan seluruh paket aktif mitra. Tiap paket punya tombol tambah, pengatur jumlah bila sudah ada di keranjang, atau penanda Habis, sehingga pembeli dapat mengambil lebih dari satu paket atau satuan dari mitra yang sama | W |

### 3.2 Mitra usaha

| ID | Kebutuhan | Prioritas |
| --- | --- | --- |
| F-14 | Sistem menampilkan daftar paket milik mitra beserta statusnya | W |
| F-15 | Mitra dapat menambah paket baru lewat formulir berisi nama, kategori, deskripsi, harga asli, harga diskon, jumlah porsi, jam tutup ambil, dan foto. Paket yang disimpan langsung tersedia sampai jam tutup ambil | W |
| F-16 | Sistem menolak harga diskon yang lebih besar atau sama dengan harga asli, dengan pesan galat di bawah kolom yang bersangkutan | W |
| F-17 | Sistem menolak jumlah porsi yang bukan bilangan bulat positif | W |
| F-18 | Mitra dapat mengubah dan menghapus paket miliknya, dengan dialog konfirmasi sebelum penghapusan | S |
| F-19 | Sistem menampilkan pesanan masuk untuk paket milik mitra beserta kode ambilnya | S |
| F-20 | Mitra dapat menandai pesanan sebagai sudah diambil | S |
| F-43 | Mitra dapat menandai pesanan sebagai siap diambil, dan status pada pembeli ikut berubah | S |
| F-21 | Sistem menampilkan ringkasan hari ini: porsi terselamatkan, paket aktif, dan pendapatan | O |
| F-22 | Mitra dapat menandai paket untuk didonasikan bila tidak terjual, dan sistem menampilkan badge Meja Berbagi pada kartunya | O |
| F-44 | Mitra dapat mengubah sisa porsi langsung dari daftar paket (tambah, kurang, atau tandai habis) tanpa membuka formulir | W |
| F-45 | Mitra dapat menonaktifkan dan mengaktifkan kembali paket, dan paket nonaktif tidak tampil pada daftar pembeli | W |
| F-46 | Mitra dapat memasukkan kode ambil secara manual bila kode QR tidak terbaca | W |
| F-47 | Sistem menampilkan riwayat pindai hari ini dan rekap hari ini (jumlah pesanan selesai dan penerimaan bersih) | S |
| F-48 | Sistem menambahkan penerimaan bersih ke saldo mitra setiap kali pesanan selesai diambil, yaitu harga jual dikurangi komisi platform | W |
| F-49 | Mitra dapat mendaftarkan satu rekening bank pencairan, dan sistem memeriksa kecocokan nama pemilik rekening sebelum dipakai | W |
| F-50 | Sistem mencairkan saldo mitra secara otomatis ke rekening pencairan setiap hari, dan mitra dapat melihat riwayat dana masuk, potongan, dan pencairan beserta statusnya | W |
| F-51 | Mitra dapat menutup sementara gerainya, dan selama tutup paketnya tidak tampil pada daftar pembeli | O |

### 3.3 Berlaku umum

| ID | Kebutuhan | Prioritas |
| --- | --- | --- |
| F-23 | Sistem mengurangi sisa porsi paket saat pesanan dibuat | W |
| F-24 | Sistem menandai paket yang porsinya habis sebagai "Habis" dan menonaktifkan tombol pesannya | W |
| F-25 | Sistem menyembunyikan paket yang jam tutup ambilnya sudah lewat dari daftar pembeli, dan menyembunyikan mitra yang tidak punya paket tersisa, tetapi tetap menampilkannya pada daftar mitra dengan status kedaluwarsa | W |
| F-26 | Peran pengguna ditentukan oleh akun yang sedang masuk, bukan oleh pemilihan manual di dalam aplikasi | W |
| F-27 | Pengguna dapat mengubah tema antara terang, gelap, dan mengikuti sistem | S |
| F-28 | Paket yang ditambahkan mitra langsung muncul pada daftar pembeli tanpa memuat ulang | W |

### 3.4 Akun dan data terpusat

| ID | Kebutuhan | Prioritas |
| --- | --- | --- |
| F-29 | Pengguna dapat mendaftar akun dengan email, kata sandi, nama, dan peran | W |
| F-30 | Pengguna dapat masuk dengan email dan kata sandi | W |
| F-31 | Sistem menyimpan kata sandi hanya di server dalam bentuk hash bcrypt, tidak pernah dalam bentuk asli dan tidak pernah di sisi aplikasi | W |
| F-32 | Sistem menolak akses halaman mitra oleh akun yang berperan pembeli | W |
| F-33 | Pengguna dapat keluar, dan sistem mencabut token sesinya | S |
| F-34 | Data bertahan setelah aplikasi ditutup | W |
| F-35 | Paket yang diunggah mitra pada satu perangkat terlihat oleh pembeli pada perangkat lain | W |

F-35 adalah alasan sebenarnya keberadaan server. Tanpa itu, dua peran pada
aplikasi ini hanya dapat diperagakan oleh satu orang pada satu perangkat.

Saat login gagal, sistem tidak membedakan pesan antara email yang tidak
terdaftar dan kata sandi yang salah, supaya email yang terdaftar tidak dapat
ditebak.

### 3.5 Admin

Dikerjakan paling akhir, setelah seluruh kebutuhan W dan S tuntas.

| ID | Kebutuhan | Prioritas |
| --- | --- | --- |
| F-36 | Sistem mengenali peran ketiga, yaitu admin, yang tidak dapat didaftarkan lewat aplikasi dan hanya disemai langsung di database | O |
| F-37 | Admin dapat memverifikasi atau menolak pendaftaran mitra, dan mitra yang belum terverifikasi tidak dapat menawarkan paket | O |
| F-38 | Admin dapat menonaktifkan mitra atau paket yang melanggar aturan keamanan pangan | O |
| F-39 | Admin dapat melihat angka keseluruhan platform: jumlah mitra, paket aktif, pesanan, dan total porsi terselamatkan | O |

F-37 menegakkan janji keamanan pangan yang menjadi keunggulan produk. Tanpa
verifikasi, siapa pun dapat mendaftar sebagai mitra dan langsung menjual
makanan, sehingga janji tersebut tidak memiliki penegak. Peran admin sengaja
tidak dibuka lewat pendaftaran (F-36) karena admin tidak seharusnya bisa
diciptakan oleh pengguna mana pun.

Selama F-37 belum dikerjakan, mitra dapat mendaftar dan langsung menawarkan
paket tanpa diverifikasi siapa pun. Ini diterima secara sadar karena pada tahap
tersebut seluruh akun masih berupa data uji, bukan mitra sungguhan.

---

## 4. Kebutuhan non-fungsional

| ID | Kebutuhan | Cara memeriksa |
| --- | --- | --- |
| NF-01 | Tidak ada `RenderFlex overflow` pada layar selebar 360 px | Jalankan di emulator 360×640, periksa konsol |
| NF-02 | Mendukung mode terang dan gelap, dan seluruh warna diambil dari `ThemeData` terpusat | `grep -r "Color(0x" lib/presentation/` tidak menghasilkan apa pun |
| NF-03 | Menampilkan tata letak dua kolom pada lebar 600 px ke atas | Jalankan di emulator tablet |
| NF-04 | Mengganti sumber data cukup dengan mengubah satu pendaftaran di `injection.dart`, tanpa menyentuh berkas mana pun di `presentation/` | Tukar repository API dengan repository lokal, aplikasi tetap jalan |
| NF-05 | Seluruh rute terdaftar terpusat dalam satu konfigurasi `GoRouter` | Tidak ada `MaterialPageRoute` yang tersebar |
| NF-06 | Seluruh komunikasi aplikasi dengan server memakai HTTPS | Periksa alamat dasar di klien HTTP |
| NF-07 | Pengurangan stok pada F-23 dijalankan dalam satu transaksi basis data, sehingga dua pesanan bersamaan atas porsi terakhir tidak membuat stok minus | Kirim dua permintaan bersamaan atas porsi terakhir, salah satunya harus ditolak |
| NF-08 | Setiap layar yang memanggil server memiliki tampilan sedang memuat dan tampilan gagal beserta tombol coba lagi | Matikan server, buka tiap layar |
| NF-09 | Kebutuhan F-16, F-17, F-23, dan F-25 divalidasi ulang di server, tidak hanya di aplikasi | Panggil endpoint langsung dengan data yang tidak sah |
| NF-10 | Status lunas hanya ditetapkan server berdasarkan notifikasi penyedia pembayaran yang tanda tangannya sudah diverifikasi, bukan berdasarkan laporan aplikasi. Selama pengembangan dipakai mode sandbox penyedia | Kirim notifikasi palsu tanpa tanda tangan yang sah, status pesanan tidak berubah |
| NF-11 | Pencairan otomatis (F-50) memakai API disbursement penyedia pembayaran, tiap pencairan punya kunci unik sehingga tidak pernah terkirim dua kali, dan saldo baru berkurang setelah penyedia mengonfirmasi berhasil | Jalankan proses pencairan dua kali untuk saldo yang sama, hanya satu transfer yang tercatat |

---

## 5. Pemetaan kebutuhan ke layar

Delapan belas layar utama.

| # | Layar | Peran | Kebutuhan |
| --- | --- | --- | --- |
| 1 | Beranda (daftar mitra dan Flash sale) | Pembeli | F-01, F-03, F-04, F-25, F-28, F-53 |
| 1a | Halaman Mitra | Pembeli | F-06, F-07, F-24, F-54 |
| 2 | Detail Paket | Pembeli | F-02, F-05, F-06, F-07, F-13 |
| 3 | Keranjang | Pembeli | F-08, F-09 |
| 4 | Checkout | Pembeli | F-09, F-10 |
| 5 | Pembayaran (QRIS / GoPay / VA) | Pembeli | F-10, F-40 |
| 6 | Status Pesanan (berisi kode ambil) | Pembeli | F-11, F-41, F-42 |
| 7 | Pesanan Saya | Pembeli | F-12, F-52 |
| 8 | Setelan | Umum | F-27, F-33 |
| 9 | Dasbor Mitra | Mitra | F-21, F-51 |
| 10 | Kelola Paket | Mitra | F-14, F-44, F-45 |
| 10a | Form Paket | Mitra | F-15, F-16, F-17, F-18, F-22 |
| 11 | Pesanan Masuk | Mitra | F-19, F-20, F-43, F-47 |
| 11a | Scan QR (kamera layar penuh, tombol "Ketik kode" untuk input manual) | Mitra | F-20, F-46 |
| 11b | Saldo dan Rekening Pencairan | Mitra | F-48, F-49, F-50 |
| 12 | Login | Umum | F-30 |
| 13 | Daftar Akun | Umum | F-29 |
| 14 | Panel Admin | Admin | F-37, F-38, F-39 |

Tab bar bawah dipakai untuk berpindah antar layar, isinya menyesuaikan peran
akun yang sedang masuk sesuai F-26 dan F-32. Pembeli: Beranda, Pesanan, Akun.
Mitra: Dasbor, Paket, Scan QR (tombol tengah), Pesanan, Saldo. Admin:
Ringkasan, Mitra, Akun.

---

## 6. Di luar lingkup

Bersifat mengikat. Menambahkan salah satunya butuh keputusan sadar dan
pembaruan dokumen ini.

- Metode pembayaran selain QRIS, GoPay, dan Virtual Account (kartu kredit, paylater, bayar di tempat)
- Saldo, poin, dan voucher
- Peta dan lokasi akurat. Jarak ditampilkan sebagai data dummy
- Skor higienis mitra
- Percakapan antara pembeli dan mitra, notifikasi, rating, dan ulasan

---

## 7. Riwayat revisi

| Versi | Tanggal | Perubahan |
| --- | --- | --- |
| 1.0 | 19 Sep 2026 | Versi awal, dipisahkan dari PRD |
| 1.5 | 2 Okt 2026 | Beranda berpusat pada mitra: daftar mitra diurutkan dari jam tutup ambil terdekat (F-01 diubah), Flash sale untuk mitra yang tutup kurang dari 1 jam (F-53), halaman mitra untuk memilih paket dan membeli satuan (F-54). Slot ambil (mulai dan tutup) disederhanakan jadi jam tutup ambil saja (F-15, F-25). F-07 disesuaikan karena keranjang melekat pada satu mitra |
| 1.4 | 1 Okt 2026 | Pesanan Saya: filter Berlangsung, Selesai, Dibatalkan (F-12 diubah, jadi W), pintasan QR, petunjuk arah, dan hubungi mitra (F-52) |
| 1.3 | 1 Okt 2026 | Mitra: ubah stok cepat, aktif/nonaktif paket, kode manual, riwayat pindai dan rekap, saldo dengan pencairan otomatis, tutup gerai (F-44–F-51, NF-11). Navigasi mitra 5 tab: Dasbor, Paket, Scan QR, Pesanan, Saldo |
| 1.2 | 1 Okt 2026 | Pembayaran di aplikasi (QRIS, GoPay, VA) menggantikan bayar di tempat: F-10 dan F-11 diubah, tambah F-40–F-43 dan NF-10, layar Konfirmasi Pesanan dan Kode Ambil diganti Checkout, Pembayaran, dan Status Pesanan |
