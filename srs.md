# SRS — Sisa Rasa Mobile

**Spesifikasi Kebutuhan Perangkat Lunak**

**Versi:** 1.1 - 19 September 2026

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
paket makanan hari itu dengan harga diskon, pembeli memesan lewat aplikasi dan
menerima kode ambil, lalu mengambil sendiri pada slot jam yang ditentukan
sambil membayar di tempat.

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
| F-01 | Sistem menampilkan daftar paket tersedia beserta foto, nama mitra, harga asli, harga diskon, persentase diskon, slot ambil, dan sisa porsi | W |
| F-02 | Sistem menampilkan detail satu paket beserta deskripsi, info mitra, alamat, dan jumlah rupiah yang dihemat | W |
| F-03 | Pengguna dapat menyaring daftar paket berdasarkan kategori | W |
| F-04 | Pengguna dapat mencari paket berdasarkan nama paket atau nama mitra | S |
| F-05 | Pengguna dapat memilih jumlah porsi, dan sistem membatasinya pada sisa porsi yang tersedia | W |
| F-06 | Pengguna dapat menambahkan paket ke keranjang | W |
| F-07 | Sistem meminta konfirmasi pengosongan keranjang bila pengguna menambahkan paket dari mitra yang berbeda | W |
| F-08 | Pengguna dapat mengubah jumlah dan menghapus item di keranjang | W |
| F-09 | Sistem menampilkan subtotal dan total penghematan pada keranjang dan ringkasan pesanan | W |
| F-10 | Pengguna dapat membuat pesanan dengan metode bayar di tempat | W |
| F-11 | Sistem menerbitkan kode ambil acak berawalan `SR-` untuk setiap pesanan | W |
| F-12 | Sistem menampilkan riwayat pesanan, terbagi menjadi aktif dan selesai | S |
| F-13 | Pengguna dapat menandai paket sebagai favorit | O |

### 3.2 Mitra usaha

| ID | Kebutuhan | Prioritas |
| --- | --- | --- |
| F-14 | Sistem menampilkan daftar paket milik mitra beserta statusnya | W |
| F-15 | Mitra dapat menambah paket baru lewat formulir berisi nama, kategori, deskripsi, harga asli, harga diskon, jumlah porsi, slot ambil, dan foto | W |
| F-16 | Sistem menolak harga diskon yang lebih besar atau sama dengan harga asli, dengan pesan galat di bawah kolom yang bersangkutan | W |
| F-17 | Sistem menolak jumlah porsi yang bukan bilangan bulat positif | W |
| F-18 | Mitra dapat mengubah dan menghapus paket miliknya, dengan dialog konfirmasi sebelum penghapusan | S |
| F-19 | Sistem menampilkan pesanan masuk untuk paket milik mitra beserta kode ambilnya | S |
| F-20 | Mitra dapat menandai pesanan sebagai sudah diambil | S |
| F-21 | Sistem menampilkan ringkasan hari ini: porsi terselamatkan, paket aktif, dan pendapatan | O |
| F-22 | Mitra dapat menandai paket untuk didonasikan bila tidak terjual, dan sistem menampilkan badge Meja Berbagi pada kartunya | O |

### 3.3 Berlaku umum

| ID | Kebutuhan | Prioritas |
| --- | --- | --- |
| F-23 | Sistem mengurangi sisa porsi paket saat pesanan dibuat | W |
| F-24 | Sistem menandai paket yang porsinya habis sebagai "Habis" dan menonaktifkan tombol pesannya | W |
| F-25 | Sistem menyembunyikan paket yang slot ambilnya sudah lewat dari daftar pembeli, tetapi tetap menampilkannya pada daftar mitra dengan status kedaluwarsa | W |
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

---

## 5. Pemetaan kebutuhan ke layar

Tiga belas layar.

| # | Layar | Peran | Kebutuhan |
| --- | --- | --- | --- |
| 1 | Beranda | Pembeli | F-01, F-03, F-04, F-24, F-25, F-28 |
| 2 | Detail Paket | Pembeli | F-02, F-05, F-06, F-07, F-13 |
| 3 | Keranjang | Pembeli | F-08, F-09 |
| 4 | Konfirmasi Pesanan | Pembeli | F-09, F-10 |
| 5 | Kode Ambil | Pembeli | F-11 |
| 6 | Pesanan Saya | Pembeli | F-12 |
| 7 | Setelan | Umum | F-27, F-33 |
| 8 | Beranda Mitra | Mitra | F-14, F-21 |
| 9 | Form Paket | Mitra | F-15, F-16, F-17, F-18, F-22 |
| 10 | Pesanan Masuk | Mitra | F-19, F-20 |
| 11 | Login | Umum | F-30 |
| 12 | Daftar Akun | Umum | F-29 |
| 13 | Panel Admin | Admin | F-37, F-38, F-39 |

Menu samping dipakai untuk berpindah antar layar. Isinya menyesuaikan peran
akun yang sedang masuk, sesuai F-26 dan F-32.

---

## 6. Di luar lingkup

Bersifat mengikat. Menambahkan salah satunya butuh keputusan sadar dan
pembaruan dokumen ini.

- Pembayaran di dalam aplikasi
- Peta dan lokasi akurat. Jarak ditampilkan sebagai data dummy
- Skor higienis mitra
- Percakapan antara pembeli dan mitra, notifikasi, rating, dan ulasan

---

## 7. Riwayat revisi

| Versi | Tanggal | Perubahan |
| --- | --- | --- |
| 1.0 | 19 Sep 2026 | Versi awal, dipisahkan dari PRD |
