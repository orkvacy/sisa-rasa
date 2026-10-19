# Backend Sisa Rasa

REST API untuk aplikasi mobile, ditulis dengan Go (`net/http`) dan PostgreSQL.

## Yang sudah ada

| Metode | Jalur | Keterangan |
| --- | --- | --- |
| `GET` | `/healthz` | Cek server + koneksi database |
| `POST` | `/v1/akun/daftar` | `{nama, email, sandi, peran}` → `{akun, token}` (F-29) |
| `POST` | `/v1/akun/masuk` | `{email, sandi}` → `{akun, token}` (F-30) |
| `GET` | `/v1/akun/saya` | Header `Authorization: Bearer <token>` → `{akun}` |
| `POST` | `/v1/akun/keluar` | Mencabut token (F-33) |

Galat selalu berbentuk `{"pesan": "..."}` dengan kode HTTP yang sesuai
(400 isian rusak, 401 belum/gagal masuk, 409 email terdaftar, 422 isian tidak
valid, 429 terlalu banyak percobaan).

Keamanan yang sudah dipasang:

- Kata sandi disimpan sebagai hash bcrypt (F-31).
- Token sesi acak 256-bit. Yang disimpan di database hanya hash SHA-256-nya.
- Pesan gagal masuk sama untuk email tidak terdaftar dan sandi salah, dan
  waktu jawabnya disamakan, supaya email terdaftar tidak bisa ditebak.
- Masuk dan daftar dibatasi 10 kali per menit per IP (NF-13).

## Menjalankan di laptop

1. Pasang PostgreSQL 17, lalu buat database (sekali saja):

   ```powershell
   & 'C:\Program Files\PostgreSQL\17\bin\psql.exe' -U postgres -c "CREATE DATABASE sisarasa_dev"
   ```

2. Jalankan server dari folder `backend`:

   ```powershell
   $env:DATABASE_URL = "postgres://postgres:SANDI_POSTGRES@localhost:5432/sisarasa_dev?sslmode=disable"
   go run ./cmd/server
   ```

   Tabel dibuat otomatis (migrasi di `internal/db/migrasi`). Di lingkungan dev,
   akun contoh ikut dibuat dengan sandi `sisarasa123`:
   `rani.amelia@gmail.com`, `dimas.pratama@contoh.id` (pembeli),
   `dapur.ibis@contoh.id` (mitra).

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
| `SEMAI_AKUN_CONTOH` | kosong | Isi `1` di server demo supaya akun contoh dibuat. Ditolak kalau `LINGKUNGAN=production` |

## Deploy ke Coolify

1. **Database:** New Resource → Database → PostgreSQL 17. Salin
   *Postgres URL (internal)*-nya.
2. **Server:** New Resource → Application → repo `orkvacy/sisa-rasa`, branch
   `main`, Build Pack **Dockerfile**, Base Directory **`/backend`**, port
   **8080**, domain misalnya `https://api.sisarasa.id`.
3. **Environment variables:**

   ```
   DATABASE_URL=<Postgres URL internal dari langkah 1>
   LINGKUNGAN=staging
   SEMAI_AKUN_CONTOH=1
   ASAL_WEB=https://app.sisarasa.id
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

Tes ke PostgreSQL sungguhan ikut jalan kalau `TEST_DATABASE_URL` diisi.
Pakai database khusus tes, karena isinya dihapus setiap kali tes jalan:

```powershell
& 'C:\Program Files\PostgreSQL\17\bin\psql.exe' -U postgres -c "CREATE DATABASE sisarasa_tes"
$env:TEST_DATABASE_URL = "postgres://postgres:SANDI_POSTGRES@localhost:5432/sisarasa_tes?sslmode=disable"
go test ./...
```
