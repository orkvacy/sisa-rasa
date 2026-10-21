import 'package:sisa_rasa/data/sumber/klien_api.dart';
import 'package:sisa_rasa/domain/repositories/layanan_voucher.dart';

/// voucher di server Go (backend/internal/toko/voucher.go)
class VoucherApi implements LayananVoucher {
  VoucherApi(this.klien);

  final KlienApi klien;

  static List<Map<String, dynamic>> _daftar(Map<String, dynamic> hasil) => [
    for (final v in hasil['voucher'] as List) dariServer(v as Map),
  ];

  /// tanggal dari string ISO jadi DateTime lokal
  static Map<String, dynamic> dariServer(Map json) => {
    ...Map<String, dynamic>.from(json),
    'mulai': DateTime.parse(json['mulai'] as String).toLocal(),
    'berakhir': DateTime.parse(json['berakhir'] as String).toLocal(),
  };

  @override
  Future<List<Map<String, dynamic>>> tersedia() async =>
      _daftar(await klien.get('/v1/voucher'));

  @override
  Future<Map<String, dynamic>> cek(String kode, int subtotal) async {
    final hasil = await klien.post('/v1/voucher/cek', {
      'kode': kode,
      'subtotal': subtotal,
    });
    return {
      'voucher': dariServer(hasil['voucher'] as Map),
      'potongan': hasil['potongan'] as int,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> semua() async =>
      _daftar(await klien.get('/v1/admin/voucher'));

  @override
  Future<Map<String, dynamic>> buat(Map<String, dynamic> isian) async {
    final hasil = await klien.post('/v1/admin/voucher', {
      ...isian,
      'mulai': (isian['mulai'] as DateTime).toUtc().toIso8601String(),
      'berakhir': (isian['berakhir'] as DateTime).toUtc().toIso8601String(),
    });
    return dariServer(hasil['voucher'] as Map);
  }

  @override
  Future<Map<String, dynamic>> aturAktif(
    String id, {
    required bool aktif,
  }) async {
    final hasil = await klien.patch('/v1/admin/voucher/$id', {'aktif': aktif});
    return dariServer(hasil['voucher'] as Map);
  }
}
