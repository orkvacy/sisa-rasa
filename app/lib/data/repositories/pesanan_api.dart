import 'package:sisa_rasa/data/sumber/klien_api.dart';
import 'package:sisa_rasa/domain/repositories/layanan_pesanan.dart';

/// pesanan lewat server Go (backend/internal/toko)
class PesananApi implements LayananPesanan {
  PesananApi(this.klien);

  final KlienApi klien;

  @override
  Future<List<Map<String, dynamic>>> daftar() async {
    final hasil = await klien.get('/v1/pesanan');
    return [for (final p in hasil['pesanan'] as List) dariServer(p as Map)];
  }

  @override
  Future<Map<String, dynamic>> buat({
    required Map<String, int> isi,
    required String metode,
    required String kunci,
  }) async => _satu(
    await klien.post(
      '/v1/pesanan',
      {'isi': isi, 'metode': metode},
      {'Idempotency-Key': kunci},
    ),
  );

  @override
  Future<Map<String, dynamic>> cekBayar(String id) async =>
      _satu(await klien.post('/v1/pesanan/$id/cek-bayar'));

  @override
  Future<Map<String, dynamic>> batal(
    String id, {
    required String alasan,
    bool otomatis = false,
  }) async => _satu(
    await klien.post('/v1/pesanan/$id/batal', {
      'alasan': alasan,
      'otomatis': otomatis,
    }),
  );

  @override
  Future<Map<String, dynamic>> gantiMetode(String id, String metode) async =>
      _satu(await klien.post('/v1/pesanan/$id/metode', {'metode': metode}));

  @override
  Future<Map<String, dynamic>> ubahStatus(String id, String status) async =>
      _satu(await klien.post('/v1/pesanan/$id/status', {'status': status}));

  @override
  Future<Map<String, dynamic>> batalMitra(String id, String alasan) async =>
      _satu(
        await klien.post('/v1/pesanan/$id/batal-mitra', {'alasan': alasan}),
      );

  Map<String, dynamic> _satu(Map<String, dynamic> hasil) =>
      dariServer(hasil['pesanan'] as Map);

  /// JSON server -> map pesanan yang dipakai layar.
  /// waktu dari string ISO jadi DateTime lokal, map angka jadi `Map<String, int>`
  static Map<String, dynamic> dariServer(Map json) {
    DateTime? waktu(Object? nilai) =>
        nilai == null ? null : DateTime.parse(nilai as String).toLocal();
    return {
      ...Map<String, dynamic>.from(json),
      'dibuat': waktu(json['dibuat']),
      'batasBayar': waktu(json['batasBayar']),
      'dibayarPada': waktu(json['dibayarPada']),
      'diambilPada': waktu(json['diambilPada']),
      'dibatalkanPada': waktu(json['dibatalkanPada']),
      'isi': [
        for (final isi in json['isi'] as List)
          Map<String, dynamic>.from(isi as Map),
      ],
      'porsiPaket': Map<String, int>.from(json['porsiPaket'] as Map),
      'tagihan': Map<String, String>.from(json['tagihan'] as Map),
      'mengecek': false,
    };
  }
}
