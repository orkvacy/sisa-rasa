# Backend Sisa Rasa

REST API untuk aplikasi mobile, ditulis dengan Go (`net/http`) dan PostgreSQL.

## Yang sudah ada

| Metode | Jalur | Keterangan |
| --- | --- | --- |
| `GET` | `/healthz` | Cek server + koneksi database |
| `POST` | `/v1/akun/daftar` | `{nama, email, sandi, peran}` → `{akun, token}` (F-29) |
| `POST` | `/v1/akun/masuk` | `{email, sandi}` → `{akun, token}` (F-30) |
| `POST` | `/v1/akun/lupa-sandi` | `{email}` kirim kode 6 angka ke email (berlaku 10 menit). Selalu 204, terdaftar atau tidak |
| `POST` | `/v1/akun/lupa-sandi/cek` | `{email, kode}` → `{tiket}`. Salah 5 kali = kode hangus |
| `POST` | `/v1/akun/lupa-sandi/atur` | `{tiket, sandi}` ganti sandi, semua sesi lama dicabut |
| `POST` | `/v1/akun/google` | `{idToken}` masuk / daftar pembeli pakai Google. Token diperiksa ke kunci publik Google. Email yang sudah terdaftar pakai sandi ditolak 409 (tidak disambung otomatis) |
| `GET` | `/v1/akun/saya` | Header `Authorization: Bearer <token>` → `{akun}` |
| `POST` | `/v1/akun/keluar` | Mencabut token (F-33) |
| `PATCH` | `/v1/akun/saya` | `{nama}` ganti nama, khusus pembeli (F-63) |
| `POST` | `/v1/akun/hapus` | `{sandi}` (akun Google: `{idToken}`) hapus akun pembeli: data pribadi dikosongkan, semua sesi dicabut, nama di pesanan lama dianonimkan. Ditolak kalau masih ada pesanan berjalan (F-62) |
| `GET` | `/v1/paket` | Paket dari mitra terverifikasi, boleh tanpa masuk (F-65). Mitra yang masuk ikut melihat paketnya sendiri walau belum diverifikasi |
| `GET` | `/v1/favorit` | Khusus pembeli: `{mitra: [{id, nama, jenis}]}` mitra favorit, terbaru di depan |
| `PUT` `DELETE` | `/v1/favorit/{idMitra}` | Simpan / lepas mitra favorit. Idempoten, aman diulang |
| `GET` | `/v1/mitra/status` | `{status, alasan}` status verifikasi gerai: `menunggu` / `terverifikasi` / `ditolak` / `nonaktif` (F-37) |
| `GET` `POST` | `/v1/mitra/paket` | Paket milik mitra / tambah paket (F-15) |
| `PUT` `DELETE` | `/v1/mitra/paket/{id}` | Ubah / hapus paket (F-18) |
| `PATCH` | `/v1/mitra/paket/{id}/sisa` | `{sisa}` (F-44) |
| `PATCH` | `/v1/mitra/paket/{id}/aktif` | `{aktif}` (F-45) |
| `PUT` | `/v1/mitra/gerai/lokasi` | `{lat, lng}` titik gerai dari GPS HP mitra. Paket ikut membawa `lat`/`lng`, jarak dihitung di HP pembeli (lokasi pembeli tidak dikirim ke server) |
| `PUT` | `/v1/mitra/gerai/tutup` | `{tutup}` tutup gerai sementara (F-51) |
| `GET` | `/v1/mitra/saldo` | `{rekening, tersedia, riwayat}` saldo dari pesanan selesai dikurangi komisi 10% dan pencairan (F-48, F-50) |
| `PUT` | `/v1/mitra/rekening` | `{bank, nomor, nama}` nama harus sama dengan nama usaha (F-49) |
| `POST` | `/v1/mitra/foto` | Multipart field `foto` (JPG/PNG/WebP, maks 8 MB). Dikecilkan ke lebar 1200 px, EXIF dibuang, disimpan ke R2. Jawab `{foto: url}` |
| `POST` | `/v1/mitra/ambil` | `{kode}` scan / ketik kode ambil, pesanan selesai (F-46) |
| `GET` | `/v1/pesanan` | Pesanan pembeli, atau pesanan masuk mitra (yang sudah dibayar) |
| `POST` | `/v1/pesanan` | `{isi: {idPaket: jumlah}, metode}` + header **`Idempotency-Key`** |
| `GET` | `/v1/pesanan/{id}` | Satu pesanan |
| `POST` | `/v1/pesanan/{id}/cek-bayar` | Cek lunas (NF-10). Dengan Midtrans: status ditanya ke Midtrans, 409 kalau belum dibayar. Tanpa Midtrans (mode uji): langsung lunas |
| `POST` | `/v1/pembayaran/midtrans` | Webhook Midtrans (tanpa sesi). Tanda tangan SHA512 dicek, status ditanya ulang ke Midtrans, lalu pesanan lunas / batal. Idempoten |
| `POST` | `/v1/pesanan/{id}/batal` | `{alasan}` pembeli batal sebelum bayar, porsi kembali (F-55) |
| `GET` | `/v1/admin/mitra?status=` | Khusus admin: daftar mitra, filter status opsional (F-36) |
| `POST` | `/v1/admin/mitra/{id}/periksa` | Khusus admin: `{status, alasan}` setujui / tolak / nonaktifkan mitra. Alasan wajib untuk ditolak & nonaktif (F-37, F-38) |
| `POST` | `/v1/pesanan/{id}/metode` | `{metode}` ganti metode sebelum bayar |
| `POST` | `/v1/pesanan/{id}/status` | `{status}` mitra: `siap_diambil` / `selesai` (F-43) |
| `POST` | `/v1/pesanan/{id}/batal-mitra` | `{alasan}` mitra batalkan pesanan lunas (F-42) |
| `GET` `POST` | `/v1/pesanan/{id}/pesan` | Riwayat chat / kirim `{id, teks}` (F-67, F-68). `id` dari aplikasi, kiriman ulang tidak dobel |
| `POST` | `/v1/pesanan/{id}/pesan/dibaca` | Tandai pesan lawan bicara sudah dibaca (F-70) |
| `GET` | `/v1/pesan/baru?setelah=` | Pesan + tanda dibaca yang berubah di semua pesanan akun, ditarik aplikasi tiap 4 detik |

Galat selalu berbentuk `{"pesan": "..."}` dengan kode HTTP yang sesuai
(400 isian rusak, 401 belum/gagal masuk, 409 email terdaftar, 422 isian tidak
valid, 429 terlalu banyak percobaan).

Keamanan yang sudah dipasang:

- Kata sandi disimpan sebagai hash bcrypt (F-31).
- Token sesi acak 256-bit. Yang disimpan di database hanya hash SHA-256-nya.
- Pesan gagal masuk sama untuk email tidak terdaftar dan sandi salah, dan
  waktu jawabnya disamakan, supaya email terdaftar tidak bisa ditebak.
- Masuk dan daftar dibatasi 10 kali per menit per IP (NF-13).
- **Pesanan tidak bisa dobel.** Aplikasi mengirim `Idempotency-Key` unik per
  tombol Bayar. Kalau request yang sama terkirim dua kali (sinyal putus,
  tombol tertekan dua kali), server membalikkan pesanan yang sama (200), stok
  tidak terpotong dua kali.
- **Stok tidak bisa minus.** Baris paket dikunci (`SELECT ... FOR UPDATE`)
  selama pesanan dibuat, jadi dua pembeli yang berebut porsi terakhir tidak
  bisa sama-sama berhasil.
- Pesanan yang lewat batas bayar 15 menit dibatalkan server tiap 30 detik dan
  porsinya dikembalikan (F-40), walau tidak ada yang membuka aplikasi.
- Kode ambil dibuat server setelah lunas, acak 4 huruf dari `crypto/rand`.
- **Saldo tidak bisa cair dua kali.** Pencairan otomatis tiap hari 09.00 WITA
  (NF-11) memakai kunci per tanggal (`harian-YYYY-MM-DD`, unik per mitra) dan
  kunci transaksi per mitra. Walau job jalan dua kali atau server restart,
  saldo hari itu hanya dicairkan sekali. Di luar production statusnya langsung
  `Berhasil` (belum ada transfer bank asli); di production `Diproses`.

## Menjalankan di laptop

1. Pasang PostgreSQL 18, lalu buat database (sekali saja):

   ```powershell
   & 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -U postgres -c "CREATE DATABASE sisarasa_dev"
   ```

2. Jalankan server dari folder `backend`:

   ```powershell
   $env:DATABASE_URL = "postgres://postgres:SANDI_POSTGRES@localhost:5432/sisarasa_dev?sslmode=disable"
   go run ./cmd/server
   ```

   Tabel dibuat otomatis (migrasi di `internal/db/migrasi`). Di lingkungan dev,
   akun contoh ikut dibuat dengan sandi `sisarasa123`:
   `rani.amelia@gmail.com`, `dimas.pratama@contoh.id` (pembeli),
   `dapur.ibis@contoh.id` (mitra Ibis Hotel), plus enam mitra lain dengan
   paketnya (lihat `internal/toko/semai.go`).

3. Jalankan aplikasi yang tersambung ke server:

   ```powershell
   flutter run --dart-define=API_URL=http://10.0.2.2:8080
   ```

   `10.0.2.2` adalah alamat laptop dilihat dari emulator Android. Untuk HP
   sungguhan, pakai IP laptop di Wi-Fi yang sama (lihat dengan `ipconfig`),
   misalnya `http://192.168.1.10:8080`. Tanpa `API_URL`, aplikasi tetap
   memakai data tiruan di HP.

## Pengaturan (environment variable)

| Nama | Bawaan | Keterangan |
| --- | --- | --- |
| `DATABASE_URL` | (wajib) | Alamat PostgreSQL |
| `ALAMAT` | `:8080` | Alamat yang didengarkan server |
| `LINGKUNGAN` | `dev` | `dev`, `staging`, atau `production`. Akun contoh dan CORS hanya di `dev` |
| `DI_BELAKANG_PROXY` | kosong | Isi `1` kalau di belakang Coolify/Traefik, supaya IP asli dibaca dari `X-Forwarded-For` |
| `ASAL_WEB` | kosong (`*` di dev) | Origin aplikasi web yang boleh memanggil API, dipisah koma. Contoh `https://app.sisarasa.id` |
| `JAM_DEMO` | kosong | Opsional. Kunci "jam sekarang" ke jam tertentu, misal `16:20`, kalau mau demo paket sore di jam berapa pun. Kosong = jam asli (aplikasi yang tersambung server juga pakai jam asli). Ditolak di production |
| `QRIS_STATIS` | kosong | Isi **teks** QRIS statis merchant (hasil scan gambar QRIS, diawali `000201`). Kalau diisi, pesanan QRIS dapat QR asli dengan nominal pesanan (tag 01 jadi 12, tag 54 nominal, CRC dihitung ulang). Status lunas belum dicek otomatis; tunggu Midtrans |
| `R2_BUCKET` | kosong | Bucket Cloudflare R2 untuk foto paket. Kosong = foto disimpan di `FOLDER_FOTO` |
| `R2_ID_AKUN` | | Account ID Cloudflare |
| `R2_ACCESS_KEY_ID` `R2_SECRET_ACCESS_KEY` | | Kunci API R2 (rahasia, isi di Coolify saja) |
| `R2_PUBLIK` | | Alamat publik bucket, misal `https://cdn.sisarasa.web.id` |
| `FOLDER_FOTO` | `data/foto` (`/data/foto` di Docker) | Tempat foto kalau R2 belum diatur. Di Coolify pasang Persistent Storage ke `/data` |
| `ADMIN_EMAIL` `ADMIN_SANDI` | kosong | Akun admin dibuat saat server nyala kalau belum ada (sandi min. 12 karakter, rahasia, isi di Coolify saja). Admin tidak bisa daftar lewat aplikasi |
| `MIDTRANS_SERVER_KEY` | kosong | Server Key Midtrans (rahasia, isi di Coolify saja). Kosong = pembayaran mode uji |
| `MIDTRANS_PRODUKSI` | kosong | Isi `1` kalau pakai kunci produksi (api.midtrans.com). Kosong = sandbox. Kunci berawalan `SB-` (akun Midtrans lama) ditolak kalau ini `1` |
| `RESEND_API_KEY` | kosong | Kunci API Resend untuk email kode lupa sandi (rahasia, isi di Coolify saja). Kosong = fitur lupa sandi mati (di dev kodenya hanya ditulis ke log) |
| `EMAIL_PENGIRIM` | `Sisa Rasa <noreply@sisarasa.web.id>` | Alamat pengirim, domainnya harus sudah diverifikasi di Resend |
| `GOOGLE_CLIENT_ID` | kosong | Web client ID OAuth dari Google Cloud (bukan rahasia). Kosong = masuk dengan Google mati |
| `SEMAI_AKUN_CONTOH` | kosong | Isi `1` di server demo supaya akun contoh dibuat. Ditolak kalau `LINGKUNGAN=production` |

## Deploy ke Coolify

1. **Database:** New Resource → Database → PostgreSQL 18. Salin
   *Postgres URL (internal)*-nya.
2. **Server:** New Resource → Application → repo `orkvacy/sisa-rasa`, branch
   `main`, Build Pack **Dockerfile**, Base Directory **`/backend`**, port
   **8080**, domain misalnya `https://api.sisarasa.id`.
3. **Environment variables:**

   ```
   DATABASE_URL=<Postgres URL internal dari langkah 1>
   LINGKUNGAN=staging
   SEMAI_AKUN_CONTOH=1
   ```

   `ALAMAT`, `DI_BELAKANG_PROXY`, dan zona waktu sudah diatur di Dockerfile.
   Untuk rilis sungguhan pakai `LINGKUNGAN=production` dan hapus
   `SEMAI_AKUN_CONTOH`.
4. **DNS:** A record `api` → IP VPS. Coolify mengurus sertifikat HTTPS.
5. Cek `https://api.sisarasa.id/healthz` → `{"status":"ok"}`.

Aplikasi Android yang memakai server ini:

```powershell
flutter build apk --release --dart-define=API_URL=https://api.sisarasa.id
```

## Tes

```powershell
go test ./...
```

Tes ke PostgreSQL sungguhan ikut jalan kalau `TEST_DATABASE_URL` diisi, dan
selalu dijalankan di GitHub Actions (`.github/workflows/ci.yml`). Pakai database
khusus tes (namanya harus mengandung `tes`), karena isinya dihapus setiap kali
tes jalan, dan jalankan satu paket sekali jalan (`-p 1`):

```powershell
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -U postgres -c "CREATE DATABASE sisarasa_tes"
$env:TEST_DATABASE_URL = "postgres://postgres:SANDI_POSTGRES@localhost:5432/sisarasa_tes?sslmode=disable"
go test -p 1 ./...
```
