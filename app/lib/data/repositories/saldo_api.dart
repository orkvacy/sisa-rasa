import 'package:sisa_rasa/data/sumber/klien_api.dart';
import 'package:sisa_rasa/domain/repositories/layanan_saldo.dart';

/// rekening + riwayat pencairan dari server Go. [mitra] ga dipakai,
/// server tau mitranya dari token. dana masuk tetap dihitung dari pesanan
/// selesai di aplikasi (SaldoCubit.riwayat), sama kayak versi lokal
class SaldoApi implements LayananSaldo {
  SaldoApi(this.klien);

  final KlienApi klien;

  @override
  Future<Map<String, dynamic>?> rekening(String mitra) async {
    final hasil = await klien.get('/v1/mitra/saldo');
    final rek = hasil['rekening'];
    return rek == null ? null : Map<String, dynamic>.from(rek as Map);
  }

  @override
  Future<List<Map<String, dynamic>>> riwayat(String mitra) async {
    final hasil = await klien.get('/v1/mitra/saldo');
    return [
      for (final c in hasil['riwayat'] as List)
        {
          ...Map<String, dynamic>.from(c as Map),
          'jenis': 'cair',
          'waktu': DateTime.parse(c['waktu'] as String).toLocal(),
        },
    ];
  }

  @override
  Future<void> simpanRekening(
    String mitra,
    Map<String, dynamic> rekening,
  ) async {
    await klien.put('/v1/mitra/rekening', {
      'bank': rekening['bank'],
      'nomor': rekening['nomor'],
      'nama': rekening['nama'],
    });
  }
}
