import 'package:sisa_rasa/data/sumber/klien_api.dart';
import 'package:sisa_rasa/domain/repositories/layanan_admin.dart';

/// verifikasi mitra di server Go (backend/internal/toko/verifikasi.go)
class AdminApi implements LayananAdmin {
  AdminApi(this.klien);

  final KlienApi klien;

  @override
  Future<List<Map<String, dynamic>>> daftarMitra({String status = ''}) async {
    final hasil = await klien.get(
      '/v1/admin/mitra?status=${Uri.encodeQueryComponent(status)}',
    );
    return [
      for (final m in hasil['mitra'] as List)
        Map<String, dynamic>.from(m as Map),
    ];
  }

  @override
  Future<void> periksa(String id, String status, {String alasan = ''}) =>
      klien.post('/v1/admin/mitra/$id/periksa', {
        'status': status,
        'alasan': alasan,
      });
}
