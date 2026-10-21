import 'package:flutter/material.dart';

/// warna dikumpulin di sini biar ga nulis kode hex berulang.
/// mendukung mode terang dan mode gelap secara otomatis (SRS F-27, NF-02).
class Warna {
  /// aktif bila aplikasi sedang berada dalam tema gelap
  static bool modeGelap = false;

  static Color get latar =>
      modeGelap ? const Color(0xFF171513) : const Color(0xFFFFFFFF);
  static Color get kartu =>
      modeGelap ? const Color(0xFF1B211E) : const Color(0xFFFFFFFF);
  static Color get teks =>
      modeGelap ? const Color(0xFFF2EFEA) : const Color(0xFF1A1A1A);
  static Color get teksPendukung =>
      modeGelap ? const Color(0xFFB3ADA4) : const Color(0xFF6B6B6B);
  static Color get garis =>
      modeGelap ? const Color(0xFF34302B) : const Color(0xFFEBEBEB);
  static Color get hijau =>
      modeGelap ? const Color(0xFF7FC3A0) : const Color(0xFF1A382B);
  static Color get softGreen =>
      modeGelap ? const Color(0xFF1E2C25) : const Color(0xFFE2E9E3);
  static Color get merah =>
      modeGelap ? const Color(0xFFF2B8B5) : const Color(0xFFB3261E);

  // pil "Habis" (bar keranjang sama chip terpilih sekarang hijau)
  static Color get gelap =>
      modeGelap ? const Color(0xFF2A2826) : const Color(0xFF1A1A1A);

  // khusus layar kode ambil sama kartu dampak
  static Color get momen =>
      modeGelap ? const Color(0xFF12261D) : const Color(0xFF1A382B);

  // modul QR agar selalu kontras tinggi terbaca scanner di semua mode (F-43)
  static const Color qrModul = Color(0xFF1A1A1A);

  // tepi tombol sama kolom isian, kontrasnya >= 3:1 di latar putih
  static Color get garisKontrol =>
      modeGelap ? const Color(0xFF7A746B) : const Color(0xFF8F8F8F);

  // oren, buat sisa porsi dikit sama hitung mundur
  static Color get mendesak =>
      modeGelap ? const Color(0xFFF0A35E) : const Color(0xFF9A4A0B);
  static Color get mendesakLembut =>
      modeGelap ? const Color(0xFF3A2A1C) : const Color(0xFFFBEBDD);

  // abu muda netral: rel segmen, pil "Disiapkan", latar foto yg belum kemuat.
  // namanya tetap kraft biar ga ganti di semua layar
  static Color get kraft =>
      modeGelap ? const Color(0xFF2A2826) : const Color(0xFFF2F3F2);

  // kilau yang lewat di atas kerangka (skeleton) pas lagi memuat
  static Color get kilau =>
      modeGelap ? const Color(0xFF25221F) : const Color(0xFFFAFAFA);

  // pil "Dibatalkan"
  static Color get merahLembut =>
      modeGelap ? const Color(0xFF3C201E) : const Color(0xFFF9E3E0);
}
