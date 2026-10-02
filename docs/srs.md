# SRS — Sisa Rasa Mobile

**Spesifikasi Kebutuhan Perangkat Lunak**

**Versi:** 1.6 - 2 Oktober 2026

> Dokumen terkait: [PRD.md](PRD.md) (latar belakang produk dan alasannya)

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

Dibangun bertahap sampai siap dirilis ke production, sekaligus jadi bahan
portofolio.

### 1.3 Dokumen terkait

- `PRD.md` — latar belakang produk dan alasan perancangan
- `RENCANA-INCREMENT.md` - metode pengembangan dan urutan pengerjaan, utamakan MVP (menyusul)
- `MILESTONE.md` - buat track progress (menyusul)
- `API.md` - rancangan backend (menyusul)

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
| B-06 | Ikon dan ilustrasi berupa aset lokal. Foto paket dan foto mitra diunggah ke server, lalu disimpan sementara (cache) di aplikasi supaya tidak diunduh berulang |
| B-07 | Target platform Android |

## 3. Kebutuhan fungsional

Prioritas: **W** wajib, **S** sebaiknya, **O** opsional. Kebutuhan berprioritas
W tidak boleh dikorbankan dengan alasan apa pun. Kebutuhan berprioritas O
dikerjakan paling akhir, setelah seluruh W dan S tuntas.

### 3.1 Pembeli

| ID | Kebutuhan | Prioritas |
| --- | --- | --- |
| F-01 | Sistem menampilkan daftar mitra yang punya paket tersedia, diurutkan dari jam tutup ambil terdekat, beserta foto, nama, jenis, jarak, jam tutup ambil, jumlah paket, dan harga paket termurah. Jam tutup yang kurang dari 1 jam lagi diberi tanda mendesak | W |
| F-02 | Sistem menampilkan detail satu paket beserta deskripsi, info mitra, alamat, jumlah rupiah yang dihemat, label halal, dan info alergen bila diisi mitra | W |
| F-03 | Pengguna dapat menyaring daftar paket berdasarkan kategori | W |
| F-04 | Pengguna dapat mencari paket berdasarkan nama paket atau nama mitra | S |
| F-05 | Pengguna dapat memilih jumlah porsi, dan sistem membatasinya pada sisa porsi yang tersedia | W |
| F-06 | Pengguna dapat menambahkan paket ke keranjang | W |
| F-07 | Keranjang hanya berisi paket dari satu mitra. Sistem meminta konfirmasi pengosongan keranjang bila pengguna menambahkan paket dari mitra lain, baik dari halaman mitra, detail paket, maupun tombol tambah cepat | W |
| F-08 | Pengguna dapat mengubah jumlah dan menghapus item di keranjang | W |
| F-09 | Sistem menampilkan subtotal dan total penghematan pada keranjang dan ringkasan pesanan | W |
| F-10 | Pengguna dapat membuat pesanan dan membayarnya di aplikasi dengan QRIS, GoPay, atau Virtual Account bank | W |
| F-11 | Sistem menerbitkan kode ambil acak berawalan `SR-` untuk setiap pesanan yang sudah dibayar | W |
| F-12 | Sistem menampilkan riwayat pesanan yang dapat disaring menjadi Berlangsung (menunggu bayar, disiapkan, siap diambil), Selesai (sudah diambil atau tidak diambil), dan Dibatalkan, dan pesanan batal menampilkan alasan serta status pengembalian dana | W |
| F-13 | Pengguna dapat menandai paket sebagai favorit | O |
| F-40 | Sistem menahan porsi pesanan selama batas waktu bayar 15 menit (tidak melewati jam tutup ambil), lalu membatalkan pesanan dan mengembalikan porsinya bila belum dibayar | W |
| F-41 | Sistem menampilkan status pesanan bertahap (Menunggu pembayaran → Diproses → Siap diambil → Selesai, atau Dibatalkan, atau Tidak diambil) beserta isi pesanan, rincian pembayaran, metode bayar, dan ID pesanan | W |
| F-42 | Sistem mengembalikan dana pembeli secara penuh bila pesanan yang sudah dibayar dibatalkan mitra atau paketnya tidak tersedia, dan menampilkan status pengembaliannya | W |
| F-52 | Kartu pesanan berlangsung punya pintasan untuk menampilkan kode QR, membuka petunjuk arah ke titik mitra di aplikasi peta, dan menghubungi mitra lewat telepon atau WhatsApp di luar aplikasi | S |
| F-53 | Beranda menampilkan bagian Flash sale di atas daftar, berisi mitra yang jam tutup ambilnya kurang dari 1 jam lagi dalam bentuk kartu yang dapat digeser mendatar. Mitra yang tampil di Flash sale tidak muncul lagi di daftar di bawahnya, dan bagian ini disembunyikan bila tidak ada mitra yang memenuhi | S |
| F-54 | Sistem menampilkan halaman mitra berisi nama, jenis, alamat, jarak, jam tutup ambil, sisa waktu, tombol petunjuk arah, dan seluruh paket aktif mitra. Tiap paket punya tombol tambah, pengatur jumlah bila sudah ada di keranjang, atau penanda Habis, sehingga pembeli dapat mengambil lebih dari satu paket atau satuan dari mitra yang sama | W |
| F-55 | Pembeli dapat membatalkan pesanan yang masih berstatus Menunggu pembayaran. Pesanan yang sudah dibayar tidak dapat dibatalkan pembeli, karena mitra sudah mulai menyiapkannya | W |
| F-56 | Pesanan yang belum diambil sampai jam tutup ambil berubah menjadi Tidak diambil. Dana tidak dikembalikan, penerimaan bersihnya tetap masuk ke saldo mitra, dan makanan tersebut bukan lagi tanggung jawab mitra (boleh dikelola mitra, termasuk lewat Meja Berbagi). Ketentuan ini ditampilkan di Checkout sebelum pembeli membayar | W |
| F-66 | Sistem menghitung jarak dari lokasi perkiraan pembeli ke titik mitra. Bila izin lokasi ditolak, pembeli memilih area secara manual dan daftar diurutkan tanpa jarak | S |

### 3.2 Mitra usaha

| ID | Kebutuhan | Prioritas |
| --- | --- | --- |
| F-14 | Sistem menampilkan daftar paket milik mitra beserta statusnya | W |
| F-15 | Mitra dapat menambah paket baru lewat formulir berisi nama, kategori, deskripsi, harga asli, harga diskon, jumlah porsi, jam tutup ambil, foto, serta label halal dan info alergen yang boleh dikosongkan. Paket yang disimpan langsung tersedia sampai jam tutup ambil | W |
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
| F-48 | Sistem menambahkan penerimaan bersih ke saldo mitra setiap kali pesanan selesai diambil atau berstatus Tidak diambil (F-56), yaitu harga jual dikurangi komisi platform. Persentase komisi diatur di server, tidak ditulis di aplikasi | W |
| F-49 | Mitra dapat mendaftarkan satu rekening bank pencairan, dan sistem memeriksa kecocokan nama pemilik rekening sebelum dipakai | W |
| F-50 | Sistem mencairkan saldo mitra secara otomatis ke rekening pencairan setiap hari, dan mitra dapat melihat riwayat dana masuk, potongan, dan pencairan beserta statusnya | W |
| F-51 | Mitra dapat menutup sementara gerainya, dan selama tutup paketnya tidak tampil pada daftar pembeli | O |
| F-64 | Mitra dapat mengisi dan mengubah profil usaha: nama usaha, jenis, alamat, titik lokasi di peta, nomor telepon atau WhatsApp, dan jam operasional. Data ini dipakai untuk petunjuk arah dan hubungi mitra (F-52) | W |

### 3.3 Berlaku umum

| ID | Kebutuhan | Prioritas |
| --- | --- | --- |
| F-23 | Sistem mengurangi sisa porsi paket saat pesanan dibuat | W |
| F-24 | Sistem menandai paket yang porsinya habis sebagai "Habis" dan menonaktifkan tombol pesannya | W |
| F-25 | Sistem menyembunyikan dari daftar pembeli paket yang jam tutup ambilnya sudah lewat, serta mitra yang tidak punya paket tersisa. Pada daftar paket milik mitra (F-14), paket tersebut tetap tampil dengan status Kedaluwarsa | W |
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
| F-61 | Pengguna dapat mengatur ulang kata sandi lewat kode OTP yang dikirim ke email terdaftar. Kode berlaku 10 menit dan hanya bisa dipakai sekali | S |
| F-62 | Pengguna dapat menghapus akunnya sendiri dari dalam aplikasi beserta data pribadinya. Riwayat transaksi yang wajib disimpan untuk keperluan keuangan dipisahkan dari identitas pengguna | W |
| F-63 | Pengguna dapat mengubah nama, email, dan kata sandi. Mengubah email dan kata sandi wajib memasukkan kata sandi lama | S |
| F-65 | Sistem menampilkan halaman Ketentuan dan Privasi, dan pengguna wajib menyetujuinya saat mendaftar | W |

F-35 adalah alasan sebenarnya keberadaan server. Tanpa itu, dua peran pada
aplikasi ini hanya dapat diperagakan oleh satu orang pada satu perangkat.

Saat login gagal, sistem tidak membedakan pesan antara email yang tidak
terdaftar dan kata sandi yang salah, supaya email yang terdaftar tidak dapat
ditebak.

### 3.5 Notifikasi

| ID | Kebutuhan | Prioritas |
| --- | --- | --- |
| F-57 | Pembeli menerima notifikasi saat status pesanannya berubah: pembayaran berhasil, siap diambil, dan dibatalkan beserta status pengembalian dananya | W |
| F-58 | Pembeli menerima pengingat 5 menit sebelum batas bayar habis (F-40) dan 30 menit sebelum jam tutup ambil bila pesanannya belum diambil (F-56) | S |
| F-59 | Mitra menerima notifikasi setiap ada pesanan baru yang sudah dibayar | W |
| F-60 | Pengguna dapat mematikan notifikasi pengingat di Setelan. Notifikasi status pesanan (F-57, F-59) tetap dikirim | S |

Notifikasi masuk lingkup karena alur aplikasi ini bergantung pada waktu: batas
bayar 15 menit, status siap diambil, dan jam tutup ambil. Tanpa notifikasi,
pembeli harus terus membuka aplikasi dan pesanan rawan tidak diambil.

### 3.6 Admin

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
| NF-12 | Notifikasi dikirim dari server lewat Firebase Cloud Messaging, sehingga tetap sampai saat aplikasi ditutup. Isi notifikasi tidak memuat kode ambil | Tutup aplikasi, ubah status pesanan dari akun mitra, notifikasi muncul di HP pembeli |
| NF-13 | Server membatasi jumlah permintaan per IP dan per akun, lebih ketat pada login, OTP, dan pembuatan pesanan, dan membalas `429 Too Many Requests` bila batas terlewati | Kirim permintaan login berulang dengan cepat, sebagian ditolak dengan 429 |
| NF-14 | Token sesi disimpan di `flutter_secure_storage`, tidak di `SharedPreferences` | Periksa kode penyimpanan token |
| NF-15 | Aplikasi memakai SSL pinning terhadap public key server, dengan satu pin cadangan | Jalankan lewat proxy dengan sertifikat palsu, permintaan harus gagal |
| NF-16 | Tidak ada rahasia (server key payment gateway, kunci server FCM, dan sejenisnya) di dalam kode aplikasi | Cari string kunci di hasil build APK, tidak ditemukan |

---

## 5. Pemetaan kebutuhan ke layar

Dua puluh dua layar utama.

| # | Layar | Peran | Kebutuhan |
| --- | --- | --- | --- |
| 1 | Beranda (daftar mitra dan Flash sale) | Pembeli | F-01, F-03, F-04, F-25, F-28, F-53, F-66 |
| 1a | Halaman Mitra | Pembeli | F-06, F-07, F-24, F-54 |
| 2 | Detail Paket | Pembeli | F-02, F-05, F-06, F-07, F-13 |
| 3 | Keranjang | Pembeli | F-08, F-09 |
| 4 | Checkout | Pembeli | F-09, F-10, F-56 |
| 5 | Pembayaran (QRIS / GoPay / VA) | Pembeli | F-10, F-40 |
| 6 | Status Pesanan (berisi kode ambil) | Pembeli | F-11, F-41, F-42, F-55, F-56 |
| 7 | Pesanan Saya | Pembeli | F-12, F-52 |
| 8 | Setelan | Umum | F-27, F-33, F-60 |
| 8a | Profil dan keamanan akun | Umum | F-62, F-63 |
| 8b | Ketentuan dan Privasi | Umum | F-65 |
| 9 | Dasbor Mitra | Mitra | F-21, F-51 |
| 9a | Profil Usaha | Mitra | F-64 |
| 10 | Kelola Paket | Mitra | F-14, F-44, F-45 |
| 10a | Form Paket | Mitra | F-15, F-16, F-17, F-18, F-22 |
| 11 | Pesanan Masuk | Mitra | F-19, F-20, F-43, F-47 |
| 11a | Scan QR (kamera layar penuh, tombol "Ketik kode" untuk input manual) | Mitra | F-20, F-46 |
| 11b | Saldo dan Rekening Pencairan | Mitra | F-48, F-49, F-50 |
| 12 | Login | Umum | F-30 |
| 12a | Lupa Kata Sandi (email, kode OTP, kata sandi baru) | Umum | F-61 |
| 13 | Daftar Akun | Umum | F-29, F-65 |
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
- Pelacakan lokasi pembeli secara langsung. Jarak cukup dari lokasi perkiraan (F-66), dan petunjuk arah membuka aplikasi peta
- Skor higienis mitra
- Percakapan antara pembeli dan mitra, rating, dan ulasan. Notifikasi status pesanan masuk lingkup (3.5)

---

## 7. Riwayat revisi

| Versi | Tanggal | Perubahan |
| --- | --- | --- |
| 1.0 | 19 Sep 2026 | Versi awal, dipisahkan dari PRD |
| 1.6 | 2 Okt 2026 | Notifikasi masuk lingkup (F-57–F-60, NF-12). Aturan pesanan tidak diambil sampai jam tutup (F-56) dan pembatalan oleh pembeli (F-55). Pengembalian dana jadi W (F-42). Akun: lupa kata sandi, hapus akun, ubah profil, ketentuan dan privasi (F-61–F-63, F-65). Profil usaha mitra (F-64), jarak dari lokasi perkiraan (F-66), label halal dan alergen (F-02, F-15). Keamanan aplikasi (NF-13–NF-16). B-06 dan F-25 diperjelas |
| 1.5 | 2 Okt 2026 | Beranda berpusat pada mitra: daftar mitra diurutkan dari jam tutup ambil terdekat (F-01 diubah), Flash sale untuk mitra yang tutup kurang dari 1 jam (F-53), halaman mitra untuk memilih paket dan membeli satuan (F-54). Slot ambil (mulai dan tutup) disederhanakan jadi jam tutup ambil saja (F-15, F-25). F-07 disesuaikan karena keranjang melekat pada satu mitra |
| 1.4 | 1 Okt 2026 | Pesanan Saya: filter Berlangsung, Selesai, Dibatalkan (F-12 diubah, jadi W), pintasan QR, petunjuk arah, dan hubungi mitra (F-52) |
| 1.3 | 1 Okt 2026 | Mitra: ubah stok cepat, aktif/nonaktif paket, kode manual, riwayat pindai dan rekap, saldo dengan pencairan otomatis, tutup gerai (F-44–F-51, NF-11). Navigasi mitra 5 tab: Dasbor, Paket, Scan QR, Pesanan, Saldo |
| 1.2 | 1 Okt 2026 | Pembayaran di aplikasi (QRIS, GoPay, VA) menggantikan bayar di tempat: F-10 dan F-11 diubah, tambah F-40–F-43 dan NF-10, layar Konfirmasi Pesanan dan Kode Ambil diganti Checkout, Pembayaran, dan Status Pesanan |
