import 'package:flutter/material.dart';

/// warna dikumpulin di sini biar ga nulis kode hex berulang.
/// prinsipnya kayak Gojek: latar putih polos + abu netral, hijau brand cuma
/// buat aksen (tombol utama, tab aktif, chip terpilih, harga, status)
class Warna {
  static const latar = Color(0xFFFFFFFF);
  static const kartu = Color(0xFFFFFFFF);
  static const teks = Color(0xFF1A1A1A);
  static const teksPendukung = Color(0xFF6B6B6B);
  static const garis = Color(0xFFEBEBEB);
  static const hijau = Color(0xFF1A382B);
  static const softGreen = Color(0xFFE2E9E3);
  static const merah = Color(0xFFB3261E);

  // pil "Habis" (bar keranjang sama chip terpilih sekarang hijau)
  static const gelap = Color(0xFF1A1A1A);

  // khusus layar kode ambil sama kartu dampak
  static const momen = Color(0xFF1A382B);

  // tepi tombol sama kolom isian, kontrasnya >= 3:1 di latar putih
  static const garisKontrol = Color(0xFF8F8F8F);

  // oren, buat sisa porsi dikit sama hitung mundur
  static const mendesak = Color(0xFF9A4A0B);
  static const mendesakLembut = Color(0xFFFBEBDD);

  // abu muda netral: rel segmen, pil "Disiapkan", latar foto yg belum kemuat.
  // namanya tetap kraft biar ga ganti di semua layar
  static const kraft = Color(0xFFF2F3F2);

  // kilau yang lewat di atas kerangka (skeleton) pas lagi memuat
  static const kilau = Color(0xFFFAFAFA);

  // pil "Dibatalkan"
  static const merahLembut = Color(0xFFF9E3E0);
}
