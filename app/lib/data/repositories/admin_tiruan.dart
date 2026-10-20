import 'package:sisa_rasa/data/sumber/dummy_deals.dart';
import 'package:sisa_rasa/domain/repositories/layanan_admin.dart';

/// verifikasi mitra tanpa server: mitra dari data contoh udah terverifikasi,
/// ditambah satu mitra baru yang nunggu. perubahannya cuma di memori
class AdminTiruan implements LayananAdmin {
  AdminTiruan() {
    for (final paket in dummyDeals) {
      final nama = paket['mitra'] as String;
      if (_mitra.any((m) => m['nama'] == nama)) continue;
      _mitra.add({
        'id': 'mitra-${_mitra.length + 1}',
        'nama': nama,
        'email': '',
        'jenis': paket['jenisMitra'] ?? 'Mitra',
        'alamat': '',
        'status': StatusGerai.terverifikasi,
        'alasan': null,
        'jumlahPaket': dummyDeals.where((p) => p['mitra'] == nama).length,
        'daftar': '2026-10-01T08:00:00Z',
      });
    }
  }

  final List<Map<String, dynamic>> _mitra = [
    {
      'id': 'mitra-baru',
      'nama': 'Dapur Tepian',
      'email': 'dapur.tepian@contoh.id',
      'jenis': 'Restoran',
      'alamat': 'Jl. Gajah Mada, Samarinda',
      'status': StatusGerai.menunggu,
      'alasan': null,
      'jumlahPaket': 0,
      'daftar': '2026-10-20T02:00:00Z',
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> daftarMitra({String status = ''}) async =>
      [
        for (final m in _mitra)
          if (status.isEmpty || m['status'] == status) {...m},
      ];

  @override
  Future<void> periksa(String id, String status, {String alasan = ''}) async {
    final m = _mitra.firstWhere((m) => m['id'] == id);
    m['status'] = status;
    m['alasan'] = alasan.isEmpty ? null : alasan;
  }
}
