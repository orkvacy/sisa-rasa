import 'package:sisa_rasa/domain/aturan/status_pesanan.dart';

/// percakapan tetap bisa dibuka sampai 2 jam setelah pesanan berakhir (F-67)
const jamPercakapanSetelahSelesai = 2;

/// 'tidakAda' (belum dibayar), 'terbuka', atau 'bacaSaja' (udah lewat batas)
String keadaanPercakapan(Map<String, dynamic> pesanan, {DateTime? sekarang}) {
  if (pesanan['dibayarPada'] == null) return 'tidakAda';
  final status = pesanan['status'];
  if (status == StatusPesanan.disiapkan ||
      status == StatusPesanan.siapDiambil) {
    return 'terbuka';
  }
  final DateTime? akhir = pesanan['diambilPada'] ?? pesanan['dibatalkanPada'];
  // pesanan berakhir tapi waktunya ga kecatet (misal tidak diambil): baca aja
  if (akhir == null) return 'bacaSaja';
  final batas = akhir.add(const Duration(hours: jamPercakapanSetelahSelesai));
  return (sekarang ?? DateTime.now()).isBefore(batas) ? 'terbuka' : 'bacaSaja';
}

/// pesan cepat bertemplat (F-69)
const pesanCepat = {
  'pembeli': [
    'Saya sudah sampai',
    'Saya dalam perjalanan',
    'Saya terlambat sekitar 10 menit',
  ],
  'mitra': [
    'Pesanan sudah siap',
    'Pesanan sedang disiapkan',
    'Silakan ambil di kasir depan',
  ],
};
