import 'package:sisa_rasa/data/sumber/dummy_deals.dart';
import 'package:sisa_rasa/domain/repositories/layanan_paket.dart';

/// paket dari data contoh di HP, dipake selama backend belum ada
class PaketLokal implements LayananPaket {
  @override
  Future<List<Map<String, dynamic>>> semua() async => [
    // disalin, biar data contohnya ga ikut keubah
    for (final paket in dummyDeals) {...paket},
  ];
}
