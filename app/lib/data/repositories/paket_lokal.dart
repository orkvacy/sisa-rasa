import 'package:sisa_rasa/data/sumber/dummy_deals.dart';
import 'package:sisa_rasa/domain/repositories/layanan_admin.dart';
import 'package:sisa_rasa/domain/repositories/layanan_paket.dart';

/// paket dari data contoh di HP, dipake selama aplikasi ga tersambung server.
/// perubahan dari mitra cukup di memori (PaketCubit), jadi aksi di sini kosong
class PaketLokal implements LayananPaket {
  @override
  bool get lokal => true;

  @override
  Future<List<Map<String, dynamic>>> semua() async => [
    // disalin, biar data contohnya ga ikut keubah
    for (final paket in dummyDeals) {...paket},
  ];

  @override
  Future<void> tambah(Map<String, dynamic> isian) async {}

  @override
  Future<void> ubah(String id, Map<String, dynamic> isian) async {}

  @override
  Future<void> hapus(String id) async {}

  @override
  Future<void> aturSisa(String id, int sisa) async {}

  @override
  Future<void> aturAktif(String id, {required bool aktif}) async {}

  @override
  Future<void> aturGerai({required bool tutup}) async {}

  @override
  Future<void> aturLokasi(double lat, double lng) async {}

  /// mitra contoh udah diverifikasi semua
  @override
  Future<Map<String, dynamic>> statusGerai() async => {
    'status': StatusGerai.terverifikasi,
  };

  /// ga ada server: foto langsung dibaca dari file di HP
  @override
  Future<String> unggahFoto(String jalur) async => 'file://$jalur';
}
