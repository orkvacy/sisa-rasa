import 'package:sisa_rasa/domain/repositories/layanan_pembayaran.dart';

/// pembayaran tiruan buat selama backend belum ada.
/// ga ada uang yg beneran pindah, dan "Saya sudah bayar" selalu dianggap lunas
class PembayaranTiruan implements LayananPembayaran {
  const PembayaranTiruan({this.jeda = const Duration(milliseconds: 600)});

  /// pura-pura nunggu jawaban server
  final Duration jeda;

  @override
  bool get modeUji => true;

  @override
  Future<Map<String, String>> buatTagihan({
    required String idPesanan,
    required String metode,
    required int total,
  }) async {
    await Future<void>.delayed(jeda);
    // angka dari id pesanan, biar tiap pesanan nomornya beda tapi tetep sama tiap dibuka
    final angka = idPesanan.codeUnits.fold<int>(
      0,
      (a, b) => (a * 31 + b) % 100000000,
    );
    final nomor = '80770812${angka.toString().padLeft(8, '0')}';
    return {
      'isiQr': 'SISARASA-TIRUAN|$idPesanan|$total',
      'nomorVa':
          '${nomor.substring(0, 4)} ${nomor.substring(4, 8)} '
          '${nomor.substring(8, 12)} ${nomor.substring(12, 16)}',
    };
  }

  @override
  Future<bool> sudahLunas(String idPesanan) async {
    await Future<void>.delayed(jeda);
    return true;
  }
}
