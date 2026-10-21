# Sisa Rasa

Aplikasi mobile untuk menjual makanan berlebih dari hotel, restoran, dan bakery
dengan harga diskon sebelum terbuang.

| Folder | Isi |
| --- | --- |
| [`app/`](app) | Kode aplikasi mobile (Flutter) |
| [`backend/`](backend) | Server API (Go) yang terhubung ke database PostgreSQL |
| [`docs/`](docs) | PRD dan SRS |

## Kelompok

| NIM | Nama |
| --- | --- |
| 2409106046 | Muhammad Nabil Rahmatullah |
| 2409106049 | Muhammad Naufal Adi Brata Putra Suharizman Poerwo |
| 2409106050 | Ananda Daffa Harahap |
| 2409106056 | Muhammad Dzaki Rifa'I |
| 2409106084 | Aulia Natasya |

## Tentang aplikasi

Tiap hari banyak makanan yang masih layak dibuang cuma karena tidak habis
terjual sebelum toko tutup. Sementara itu ada mahasiswa dan keluarga yang lagi
cari makanan murah. Sisa Rasa jadi jembatannya: hotel, restoran, dan bakery
(mitra) menjual makanan berlebih hari itu dengan harga diskon, pembeli memesan
dan membayar lewat aplikasi, lalu mengambil sendiri di gerai sebelum jam tutup.

Ada tiga peran, dibedakan dari akun waktu masuk:

| Peran | Yang bisa dilakukan |
| --- | --- |
| **Pembeli** | Cari paket (urut terdekat, saring harga / diskon / bisa diambil sekarang), lihat jarak ke gerai dari GPS atau titik yang dipilih sendiri di peta, simpan mitra favorit, keranjang, pakai voucher, bayar lewat QRIS / GoPay / Virtual Account, pantau status pesanan, tunjukkan kode ambil, chat dengan mitra |
| **Mitra** | Terbitkan dan kelola paket (foto, harga, porsi, jam ambil opsional), tandai paket habis, siapkan pesanan, pindai / ketik kode ambil, tutup gerai sementara, pasang titik lokasi gerai, lihat saldo dan atur rekening pencairan |
| **Admin** | Verifikasi mitra baru, buat dan kelola voucher platform |

Fitur akun berlaku untuk semua peran: daftar / masuk dengan email atau Google,
lupa sandi lewat kode di email, ganti sandi, foto profil, dan hapus akun
(khusus pembeli).

Beberapa aturan yang bikin aplikasinya terasa nyata:

- Stok berkurang begitu ada yang pesan, dan porsinya ditahan 15 menit sampai
  dibayar. Lewat dari itu pesanan batal sendiri dan porsinya kembali.
- Satu pesanan cuma dari satu mitra, karena diambil langsung di tempat.
- Paket hilang sendiri kalau jam ambilnya sudah lewat. Pesanan yang tidak
  diambil sampai jam tutup jadi *Tidak diambil*.
- Biaya layanan 10% untuk pembeli, komisi 10% dari mitra. Potongan voucher
  ditanggung platform, jadi penerimaan mitra tidak berkurang.

## Cara kerja aplikasi

### Gambaran besar

```
┌──────────────────┐   HTTPS + JSON    ┌─────────────────────┐     SQL      ┌──────────────┐
│ Aplikasi Flutter │ ────────────────▶ │  Server Go (REST)   │ ───────────▶ │  PostgreSQL  │
│   (HP pembeli,   │ ◀──────────────── │  api.sisarasa.web.id│ ◀─────────── │ (VPS, sama   │
│  mitra, admin)   │   token Bearer    └─────────────────────┘              │  dengan API) │
└──────────────────┘                     │    │    │     │                  └──────────────┘
                                         │    │    │     └─ Google: cek token masuk dengan Google
                                         │    │    └─────── Resend: email kode lupa sandi
                                         │    └──────────── Cloudflare R2: foto paket & profil
                                         └───────────────── Midtrans: QRIS / GoPay / VA + webhook lunas
```

- **Aplikasi tidak pernah terhubung langsung ke database.** Semua data lewat
  server Go. Aplikasi cuma tahu alamat server (`API_URL`), sedangkan alamat dan
  sandi database hanya ada di server.
- Setelah masuk, server memberi **token sesi**. Token disimpan di
  `flutter_secure_storage` dan dikirim di tiap request
  (`Authorization: Bearer <token>`). Di database yang disimpan hanya hash-nya.
- Server memeriksa hak akses di tiap endpoint (pembeli tidak bisa memanggil
  endpoint mitra / admin), memvalidasi ulang semua isian, lalu membaca /
  menulis PostgreSQL.

### Alur satu pesanan

1. **Mitra terbitkan paket**: foto diunggah ke server (dikecilkan, EXIF
   dibuang, disimpan di R2), data paket masuk tabel `paket`.
2. **Pembeli pesan**: aplikasi mengirim `POST /v1/pesanan` dengan
   `Idempotency-Key`. Server mengunci baris paket (`SELECT ... FOR UPDATE`),
   mengurangi stok, membuat pesanan berstatus *menunggu bayar*, lalu meminta
   tagihan ke Midtrans (QR / nomor VA / tautan GoPay).
3. **Pembeli bayar** di e-wallet / m-banking. Midtrans mengirim **webhook** ke
   server. Server mengecek tanda tangannya, menanyakan ulang status ke
   Midtrans, lalu menandai pesanan lunas dan membuat kode ambil. Status lunas
   tidak pernah ditentukan oleh aplikasi.
4. **Aplikasi pembeli** memperbarui status otomatis dan menampilkan kode ambil.
5. **Mitra** menyiapkan pesanan, lalu memindai kode ambil pembeli di gerai.
   Pesanan selesai dan penerimaan bersihnya masuk saldo mitra.
6. **Pencairan** saldo berjalan otomatis tiap hari 09.00 WITA, dengan kunci
   unik per tanggal supaya tidak pernah cair dua kali.

### Di dalam aplikasi Flutter

Kode di `app/lib` memakai Clean Architecture. Arah ketergantungannya cuma satu:
`presentation` → `domain` ← `data`.

```
lib/
  main.dart         titik masuk aplikasi
  injection.dart    GetIt, satu-satunya tempat memilih implementasi (tiruan / API)
  core/             tema, warna, format rupiah / tanggal
  domain/
    aturan/         aturan bisnis: biaya layanan, status pesanan, voucher, jarak
    repositories/   kontrak layanan (abstract), mis. LayananPaket, LayananAkun
  data/
    sumber/         data contoh + klien HTTP ke server
    repositories/   implementasi kontrak: *Api (ke server) dan *Tiruan (di HP)
  presentation/
    bloc/ cubit/    state management
    screens/        layar
    widgets/        komponen yang dipakai beberapa layar
    router.dart     semua rute GoRouter, termasuk pembagian halaman per peran
```

Layar hanya bicara dengan Cubit/BLoC, Cubit hanya bicara dengan kontrak di
`domain/repositories`. Implementasinya dipilih di `injection.dart`:

- **Dengan `API_URL`**: kelas `*Api` yang memanggil server Go (data asli).
- **Tanpa `API_URL`**: kelas `*Tiruan` / `*Lokal` yang menyimpan data contoh
  di memori HP. Berguna untuk mencoba tampilan tanpa server dan untuk tes.

Aturan arah ketergantungan ini dijaga `test/arsitektur_test.dart`.

## Cara menghubungkan dengan database

Database Sisa Rasa adalah **PostgreSQL**, dan yang terhubung ke database adalah
**server Go**, bukan aplikasi. Jadi menghubungkan aplikasi ke database berarti
dua langkah: server Go disambungkan ke PostgreSQL, lalu aplikasi disambungkan ke
server Go.

```
aplikasi ──(API_URL)──▶ server Go ──(DATABASE_URL)──▶ PostgreSQL
```

### 1. Siapkan PostgreSQL

Pasang PostgreSQL (dipakai versi 18), lalu buat database kosong sekali saja:

```powershell
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -U postgres -c "CREATE DATABASE sisarasa_dev"
```

Tabel tidak perlu dibuat manual. Saat server menyala, migrasi di
`backend/internal/db/migrasi/*.sql` dijalankan berurutan dan dicatat di tabel
`schema_migrasi`, jadi migrasi yang sudah jalan tidak diulang. Tabel utamanya:

| Tabel | Isi |
| --- | --- |
| `akun`, `sesi` | Akun pembeli / mitra / admin (sandi berupa hash bcrypt, foto profil) dan token sesi (hash) |
| `gerai` | Data gerai mitra: status verifikasi, buka / tutup, titik lokasi |
| `paket` | Paket makanan: harga, porsi, sisa, jam ambil, foto |
| `pesanan`, `pesanan_isi` | Pesanan, status, pembayaran, kode ambil, voucher yang dipakai |
| `pesan_chat` | Chat pembeli dan mitra per pesanan |
| `rekening_mitra`, `pencairan` | Rekening tujuan dan riwayat pencairan saldo |
| `favorit` | Mitra favorit pembeli |
| `reset_sandi` | Kode lupa sandi (hash) |
| `voucher` | Voucher platform |

### 2. Sambungkan server Go ke database

Alamat database diberikan lewat environment variable `DATABASE_URL`, tidak
pernah ditulis di kode:

```powershell
cd backend
$env:DATABASE_URL = "postgres://postgres:SANDI_POSTGRES@localhost:5432/sisarasa_dev?sslmode=disable"
go run ./cmd/server
```

Server mendengarkan di `:8080`. Cek dengan membuka
`http://localhost:8080/healthz`, jawabannya `{"status":"ok"}` kalau server
berhasil terhubung ke database. Di lingkungan dev, akun contoh ikut dibuat
dengan sandi `sisarasa123` (mis. `rani.amelia@gmail.com` untuk pembeli,
`dapur.ibis@contoh.id` untuk mitra).

### 3. Sambungkan aplikasi ke server

Alamat server diberikan waktu menjalankan / build aplikasi:

```powershell
cd app
flutter run --dart-define=API_URL=http://10.0.2.2:8080
```

`10.0.2.2` adalah alamat laptop dilihat dari emulator Android. Untuk HP
sungguhan, pakai IP laptop di Wi-Fi yang sama (lihat dengan `ipconfig`),
misalnya `http://192.168.1.10:8080`. Tanpa `API_URL`, aplikasi memakai data
tiruan di HP dan tidak menyentuh database.

### Di server production

Server dan PostgreSQL berjalan di VPS yang sama lewat Coolify. `DATABASE_URL`
diisi dengan *Postgres URL (internal)* dari Coolify, jadi port database tidak
dibuka ke internet. APK untuk pengguna dibuat dengan alamat API publik:

```powershell
flutter build apk --release --split-per-abi --dart-define=API_URL=https://api.sisarasa.web.id --dart-define=GOOGLE_CLIENT_ID=<web client id>
```

Daftar lengkap environment variable server, endpoint API, dan langkah deploy
ada di [backend/README.md](backend/README.md).

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
feat/...  ──PR──▶ main ──▶ build otomatis (APK + binary Go)
                              │
                              ├─▶ staging     otomatis tiap ada merge ke main
                              └─▶ production  pas dibikin tag versi, file yang SAMA
```

### Branch

| Branch | Isinya |
| --- | --- |
| `main` | Satu-satunya branch utama. Selalu harus bisa di-build dan lolos tes. |
| `feat/<nama>` | Tempat ngerjain satu fitur, dibuat dari `main` lalu di-PR balik ke `main`. Contoh: `feat/keranjang`, `feat/login`. |
| `fix/<nama>` | Sama kayak fitur, tapi buat benerin bug. Contoh: `fix/stok-minus`. |
| `docs/<nama>` | Khusus ubah dokumen (README, PRD, SRS), tidak nyentuh kode. Contoh: `docs/srs-v1.7`. |
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

Perbaikannya tetap lewat `main`: bikin `fix/<nama>` dari `main`, PR,
merge, cek di staging, terus bikin tag patch baru (misal `v1.0.1`). Tidak ada
branch production yang perlu di-merge balik.

> **Status:** tes jalan otomatis di GitHub Actions (`.github/workflows/ci.yml`:
> `flutter analyze`, `flutter test`, `go vet`, `go test` ke PostgreSQL) di tiap
> PR. Server di-deploy otomatis oleh Coolify tiap ada merge ke `main`. Build APK
> dan tag rilis masih dijalankan manual.

## Tech Stack

- **Mobile:** Flutter dan Dart, GoRouter, Cubit/BLoC (flutter_bloc), GetIt,
  Clean Architecture, flutter_secure_storage, flutter_map (OpenStreetMap),
  geolocator, image_picker, mobile_scanner
- **Server:** Go (`net/http`), pgx untuk PostgreSQL, bcrypt
- **Database:** PostgreSQL 18, migrasi SQL ter-embed di server
- **Layanan luar:** Midtrans (pembayaran), Cloudflare R2 (foto), Resend
  (email), Google Sign-In
- **Infrastruktur:** VPS dengan Coolify (Docker), PostgreSQL di server yang
  sama, DNS dan CDN lewat Cloudflare

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
- **Semua input divalidasi ulang di server** (NF-09). Query ke PostgreSQL pakai
  parameter, tidak pernah gabung string, biar aman dari SQL injection.
- **Stok dikurangi dalam satu transaksi** dengan baris paketnya dikunci
  (`SELECT ... FOR UPDATE`), biar dua orang yang rebutan porsi terakhir
  tidak bikin stok minus (NF-07).
- **Status lunas cuma dari notifikasi payment gateway** yang tanda tangannya
  sudah diverifikasi, bukan dari laporan aplikasi (NF-10).
- **Pencairan saldo pakai kunci unik** jadi tidak pernah terkirim dua kali (NF-11).
- **Kode ambil acak dan sekali pakai**, dicek ke server waktu dipindai mitra.
- **Rahasia disimpan di environment variable**, tidak pernah di-commit ke repo.

### Infrastruktur (VPS)

- Sertifikat TLS dari Let's Encrypt di belakang reverse proxy, dengan HSTS.
- Firewall cuma buka port 80, 443, dan SSH. SSH cuma pakai key, login root
  dimatiin, ditambah fail2ban.
- Port PostgreSQL (5432) tidak dibuka ke luar, cuma bisa diakses server Go
  di VPS yang sama.
- Database di-backup tiap hari pakai `pg_dump` (cron) ke tempat terpisah.

## Dokumentasi

- [PRD](docs/PRD.md) - latar belakang produk dan alasan perancangannya
- [SRS](docs/srs.md) - daftar kebutuhan yang harus dipenuhi (kode F-xx / NF-xx
  di komentar kode merujuk ke sini)
- [backend/README.md](backend/README.md) - endpoint API, environment variable,
  deploy, dan tes server
