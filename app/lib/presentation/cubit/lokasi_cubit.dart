import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/domain/aturan/jarak.dart';
import 'package:sisa_rasa/domain/repositories/layanan_lokasi.dart';

/// lokasi pembeli buat ngitung jarak ke gerai (F-66). state:
/// status ('belum' / 'mencari' / 'aktif' / 'gagal'), lat, lng,
/// pesan + keSetelan kalau gagal
class LokasiCubit extends Cubit<Map<String, dynamic>> {
  LokasiCubit({required this.layanan}) : super(const {'status': 'belum'});

  final LayananLokasi layanan;

  bool get aktif => state['status'] == 'aktif';

  /// pas aplikasi dibuka: kalau izinnya udah pernah dikasih, ambil lokasi
  /// diam-diam. kalau belum, nunggu pengguna nekan "Aktifkan lokasi"
  Future<void> mulai() => _ambil(minta: false, diam: true);

  /// tombol "Aktifkan lokasi" / muat ulang lokasi
  Future<void> aktifkan() => _ambil(minta: true, diam: false);

  Future<void> _ambil({required bool minta, required bool diam}) async {
    if (state['status'] == 'mencari') return;
    final lama = state;
    emit({...state, 'status': 'mencari'});
    try {
      final p = await layanan.posisiSaya(minta: minta);
      if (!isClosed) emit({'status': 'aktif', 'lat': p.lat, 'lng': p.lng});
    } on GagalLokasi catch (e) {
      if (isClosed) return;
      // dibuka diam-diam terus gagal: balik ke keadaan sebelumnya, ga usah ribut
      emit(
        diam
            ? lama
            : {'status': 'gagal', 'pesan': e.pesan, 'keSetelan': e.keSetelan},
      );
    }
  }

  Future<void> bukaSetelan() => layanan.bukaSetelan(
    gpsMati: (state['pesan'] as String? ?? '').startsWith('GPS'),
  );

  /// km ke gerai paket ini, null kalau lokasi belum aktif / gerai belum punya titik
  double? km(Map<String, dynamic> paket) {
    final lat = paket['lat'];
    final lng = paket['lng'];
    if (!aktif || lat is! num || lng is! num) return null;
    return jarakKm(state['lat'], state['lng'], lat.toDouble(), lng.toDouble());
  }

  /// teks jarak buat ditampilin: dari GPS kalau bisa, kalau ga pakai teks
  /// jarak bawaan gerai (data lama / mitra belum masang titik)
  String teks(Map<String, dynamic> paket) {
    final k = km(paket);
    return k == null ? (paket['jarak'] as String? ?? '') : teksJarak(k);
  }
}
