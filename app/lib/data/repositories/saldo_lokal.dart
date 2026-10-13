import 'package:sisa_rasa/domain/aturan/pembayaran.dart';
import 'package:sisa_rasa/domain/repositories/layanan_saldo.dart';

/// saldo contoh buat Ibis Hotel, pura-puranya catatan dari server.
/// pencairan beneran jalan di server tiap 09.00 (NF-11), di sini cuma riwayatnya
class SaldoLokal implements LayananSaldo {
  SaldoLokal({DateTime? sekarang}) {
    final kini = sekarang ?? DateTime.now();
    final hariIni = DateTime(kini.year, kini.month, kini.day);
    final kemarin = hariIni.subtract(const Duration(days: 1));
    DateTime pada(DateTime hari, int jam, int menit) =>
        hari.add(Duration(hours: jam, minutes: menit));

    final lama = [
      _masuk('SR-8XQ1', 'Nur H.', 18000, pada(kemarin, 17, 40)),
      _masuk('SR-3MD2', 'Yoga', 24000, pada(kemarin, 17, 5)),
      _masuk('SR-6PL9', 'Sari W.', 30000, pada(kemarin, 16, 50)),
    ];
    _rekening['Ibis Hotel'] = {
      'bank': 'BCA',
      'nomor': '1234567890',
      'nama': 'IBIS HOTEL',
    };
    _riwayat['Ibis Hotel'] = [
      _masuk('SR-4HB2', 'Yoga', 14000, pada(hariIni, 12, 10)),
      // saldo kemarin dicairin semua pagi ini
      {
        'jenis': 'cair',
        'jumlah': lama.fold<int>(0, (n, e) => n + (e['jumlah'] as int)),
        'bank': 'BCA',
        'nomor': '1234567890',
        'status': 'Berhasil',
        'waktu': pada(hariIni, 9, 2),
      },
      ...lama,
    ];
  }

  final _rekening = <String, Map<String, dynamic>>{};
  final _riwayat = <String, List<Map<String, dynamic>>>{};

  static Map<String, dynamic> _masuk(
    String kode,
    String pembeli,
    int jual,
    DateTime waktu,
  ) => {
    'jenis': 'masuk',
    'kode': kode,
    'pembeli': pembeli,
    'jual': jual,
    'komisi': komisi(jual),
    'jumlah': jual - komisi(jual),
    'waktu': waktu,
  };

  @override
  Future<Map<String, dynamic>?> rekening(String mitra) async =>
      _rekening[mitra];

  @override
  Future<List<Map<String, dynamic>>> riwayat(String mitra) async => [
    ...?_riwayat[mitra],
  ];

  @override
  Future<void> simpanRekening(
    String mitra,
    Map<String, dynamic> rekening,
  ) async => _rekening[mitra] = rekening;
}
