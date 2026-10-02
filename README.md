# Sisa Rasa

Aplikasi untuk menjual makanan berlebih dari hotel, restoran, dan bakery dengan
harga diskon sebelum terbuang.

## Kelompok

| NIM | Nama |
| --- | --- |
| 2409106046 | Muhammad Nabil Rahmatullah |
| 2409106049 | Muhammad Naufal Adi Brata Putra Suharizman Poerwo |
| 2409106050 | Ananda Daffa Harahap |
| 2409106056 | Muhammad Dzaki Rifa'I |
| 2409106084 | Aulia Natasya |

## Kenapa dibuat

Tiap hari banyak makanan yang masih layak dibuang cuma karena tidak habis
terjual sebelum toko tutup. Sementara itu ada mahasiswa dan keluarga yang lagi
cari makanan murah. Aplikasi ini jadi jembatannya.

Alurnya sederhana. Mitra mengunggah paket makanan berlebih hari itu dengan
harga diskon, pembeli memesan dan membayar lewat aplikasi (QRIS, GoPay, atau
VA) lalu dapat kode ambil, kemudian mengambil sendiri pada jam yang sudah
ditentukan.

## Yang bisa dilakukan

Ada tiga peran, dibedakan lewat akun waktu login: pembeli, mitra, dan admin.

Pembeli bisa mencari paket, lihat detailnya, masukkan ke keranjang, bayar lewat
QRIS, GoPay, atau VA, lalu memantau status pesanannya sampai diambil. Mitra
bisa mengelola paket dan stoknya, menyiapkan pesanan, memindai kode ambil, dan
menerima saldo yang dicairkan otomatis ke rekening. Admin memverifikasi mitra
dan memantau angka platform.

Beberapa aturan yang bikin aplikasinya terasa nyata: stok berkurang tiap ada
yang pesan, porsi ditahan 15 menit sampai dibayar, paket hilang sendiri kalau
jam ambilnya sudah lewat, dan satu pesanan cuma boleh dari satu mitra karena
diambil langsung di tempat.

## Desain

Semua layar, alur, dan prototype-nya ada di Figma. Kalau mau tahu nanti
tampilan aplikasinya bakal seperti apa, lihat di sini:

[Sisa Rasa Mobile UI](https://www.figma.com/design/30sjBpMW2zR5TOnABwM7Hd/Sisa-Rasa-Mobile-UI?node-id=146-3241)

## Alur kerja & rilis

Repo ini **tidak memakai branch sebagai environment**. Kalau `develop` = staging
dan `main` = production, yang dites di staging dan yang naik ke production itu
dua hasil build yang beda, jadi lolos di staging belum tentu aman di production.
Belum lagi merge antar branch yang sering bentrok dan hotfix yang harus di-merge
balik.

Jadi prinsipnya: **build sekali, file yang sama dipromosikan.**

```
fitur/... ──PR──▶ main ──▶ build otomatis (APK + binary Go)
                              │
                              ├─▶ staging     otomatis tiap ada merge ke main
                              └─▶ production  pas dibikin tag versi, file yang SAMA
```

### Branch

| Branch | Isinya |
| --- | --- |
| `main` | Satu-satunya branch utama. Selalu harus bisa di-build dan lolos tes. |
| `fitur/<nama>` | Tempat ngerjain satu fitur, dibuat dari `main` lalu di-PR balik ke `main`. Contoh: `fitur/keranjang`, `fitur/login`. |
| `perbaikan/<nama>` | Sama kayak fitur, tapi buat benerin bug. Contoh: `perbaikan/stok-minus`. |
| `posttest` | Khusus praktikum Pemrograman Piranti Bergerak. Scope-nya beda, ngikutin materi tiap modul, jadi tidak di-merge ke `main`. |

Aturan PR ke `main`:

- Branch fitur dibikin kecil dan umurnya pendek (idealnya beres dalam beberapa
  hari), biar tidak jauh ketinggalan dari `main` dan tidak bentrok.
- `flutter analyze` dan `flutter test` harus lolos.
- Di-review dan di-approve dulu sebelum di-merge.
- Merge pakai *Squash and merge*, jadi satu PR = satu commit rapi di `main`.
- Branch fitur dihapus setelah di-merge.

### Environment

Staging dan production jalan dari kode yang sama. Bedanya cuma di
**konfigurasi**, bukan di kode:

| | Staging | Production |
| --- | --- | --- |
| Kapan update | Otomatis tiap ada merge ke `main` | Pas dibikin tag versi (`v1.0.0`) |
| Server | `staging` di VPS | `production` di VPS |
| Database | Terpisah, isinya data uji | Data asli |
| Payment gateway | Mode sandbox | Mode live |
| Dipakai | Tim, buat ngetes | Pengguna asli |

- Server Go baca konfigurasi dari environment variable (alamat database,
  server key payment gateway, dll), tidak ada yang ditulis di kode.
- Aplikasi Flutter dapat alamat server lewat `--dart-define` waktu build:

  ```bash
  flutter build apk --dart-define=API_URL=https://staging.contoh.id
  ```

### Rilis ke production

1. Pastikan versi di `main` sudah dicek di staging dan aman.
2. Bikin tag versi di commit itu, lalu push tag-nya:

   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

3. Build dari tag itu dinaikkan ke production dan APK-nya dilampirin di
   halaman Releases.

Penomoran versinya `vMAJOR.MINOR.PATCH`:

- **PATCH** (`v1.0.1`): cuma perbaikan bug.
- **MINOR** (`v1.1.0`): ada fitur baru, yang lama tetap jalan.
- **MAJOR** (`v2.0.0`): ada perubahan besar yang bikin versi lama tidak cocok
  lagi, misalnya API server berubah total.

### Kalau ada bug di production

Perbaikannya tetap lewat `main`: bikin `perbaikan/<nama>` dari `main`, PR,
merge, cek di staging, terus bikin tag patch baru (misal `v1.0.1`). Tidak ada
branch production yang perlu di-merge balik.

> **Status:** alur ini sudah disepakati, tapi build dan deploy otomatisnya
> (GitHub Actions) belum dibuat. Sementara ini tes dan build masih dijalankan
> manual sebelum merge.

## Tech Stack

- Flutter dan Dart, dengan GoRouter, Cubit/BLoC, dan Clean Architecture
- Go dan SQLite untuk backend
- Dijalankan di VPS sendiri

## Keamanan

Karena aplikasinya pegang uang (pembayaran pembeli dan saldo mitra), keamanan
dipikirin dari awal. Belum semuanya jadi, diterapkan bertahap sesuai SRS.

### Aplikasi (Flutter)

- **HTTPS saja** (NF-06). Koneksi `http://` biasa diblok lewat
  `network_security_config` di Android dan App Transport Security di iOS.
- **SSL pinning.** Aplikasi cuma mau ngobrol sama server yang public key
  sertifikatnya cocok sama yang disimpan di aplikasi, jadi tidak bisa
  disadap lewat sertifikat palsu (man-in-the-middle). Yang di-pin public key-nya,
  bukan sertifikatnya, karena sertifikat Let's Encrypt diperpanjang tiap 90 hari.
  Saat perpanjang key-nya dipakai ulang, dan disiapkan satu pin cadangan
  biar aplikasi tidak putus kalau key harus diganti.
- **Token disimpan di `flutter_secure_storage`** (Keystore di Android, Keychain
  di iOS), bukan di `SharedPreferences`.
- **Tidak ada rahasia di aplikasi.** Server key payment gateway dan sejenisnya
  cuma ada di server. Apa pun yang ada di APK dianggap bisa dibongkar.
- **Build rilis diobfuscate** pakai `flutter build --obfuscate --split-debug-info`.
- **Request ke server dihemat.** Kolom cari pakai debounce (nunggu ±400 ms
  setelah berhenti ngetik baru kirim request), request lama yang belum selesai
  dibatalin kalau ada yang baru, tombol bayar/pesan dikunci selama request
  jalan biar tidak kepencet dua kali, dan daftar paket dimuat per halaman
  (pagination). Ini cuma biar server tidak kebanjiran dari aplikasi sendiri,
  perlindungan aslinya tetap rate limit di server.

### Server (Go)

- **Kata sandi di-hash bcrypt** dan tidak pernah disimpan atau dikirim balik
  dalam bentuk asli (F-31). Bcrypt otomatis nambahin salt acak di tiap hash,
  jadi dua akun dengan sandi yang sama hasil hash-nya tetap beda dan tidak
  bisa dibobol pakai tabel hash jadi (rainbow table). Cost-nya diset 12 biar
  sengaja lambat kalau dicoba brute force.
- **Login tidak bocorin info.** Pesan gagalnya sama untuk email tidak terdaftar
  dan sandi salah, plus dibatasi jumlah percobaannya (rate limit) biar tidak
  bisa ditebak terus-terusan.
- **Rate limit di semua endpoint** per IP dan per akun, lebih ketat di login
  dan pembuatan pesanan. Kelewatan batas dapat respons `429 Too Many Requests`.
- **Token sesi berumur pendek** dan dicabut waktu logout (F-33).
- **Hak akses dicek di server** di tiap endpoint, bukan cuma disembunyiin di
  aplikasi. Pembeli tidak bisa manggil endpoint mitra atau admin (F-32).
- **Semua input divalidasi ulang di server** (NF-09). Query ke SQLite pakai
  parameter, tidak pernah gabung string, biar aman dari SQL injection.
- **Stok dikurangi dalam satu transaksi** biar dua orang yang rebutan porsi
  terakhir tidak bikin stok minus (NF-07).
- **Status lunas cuma dari notifikasi payment gateway** yang tanda tangannya
  sudah diverifikasi, bukan dari laporan aplikasi (NF-10).
- **Pencairan saldo pakai kunci unik** jadi tidak pernah terkirim dua kali (NF-11).
- **Kode ambil acak dan sekali pakai**, dicek ke server waktu dipindai mitra.
- **Rahasia disimpan di environment variable**, tidak pernah di-commit ke repo.

### Infrastruktur (VPS)

- Sertifikat TLS dari Let's Encrypt di belakang reverse proxy, dengan HSTS.
- Firewall cuma buka port 80, 443, dan SSH. SSH cuma pakai key, login root
  dimatiin, ditambah fail2ban.
- Database SQLite di-backup berkala ke tempat terpisah.

## Struktur folder (sementara)

```
docs/      dokumentasi
app/       aplikasi Flutter
backend/   server Go
```

## Dokumentasi

- [PRD](docs/PRD.md) - latar belakang produk dan alasan perancangannya
- [SRS](docs/srs.md) - daftar kebutuhan yang harus dipenuhi
- [Rencana Increment](docs/RENCANA-INCREMENT.md) - metode dan urutan pengerjaan (ongoing)
- [Milestone](docs/MILESTONE.md) - progress tiap checkpoint (ongoing)

## Status

Masih tahap awal. Dokumen perencanaan sudah jadi, aplikasinya baru mulai
dikerjakan.
