# Sisa Rasa

Aplikasi untuk menjual makanan berlebih dari hotel, restoran, dan bakery dengan
harga diskon sebelum terbuang.

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

## Branch

| Branch | Isinya |
| --- | --- |
| `main` | Fitur yang sudah aman dan siap masuk production. Cuma diisi lewat PR dari `develop`. |
| `develop` | Tempat fitur dikumpulkan dan dites dulu, semacam staging. Branch fitur dibuat dari sini dan di-PR balik ke sini. |
| `posttest` | Khusus praktikum Pemrograman Piranti Bergerak. Scope-nya beda, ngikutin materi tiap modul, jadi tidak di-merge ke `main` maupun `develop`. |

Alurnya: `fitur/...` → `develop` → `main`.

## Tech Stack

- Flutter dan Dart, dengan GoRouter, Cubit/BLoC, dan Clean Architecture
- Go dan SQLite untuk backend
- Dijalankan di VPS sendiri

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
