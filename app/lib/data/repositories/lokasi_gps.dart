import 'package:geolocator/geolocator.dart';
import 'package:sisa_rasa/domain/repositories/layanan_lokasi.dart';

/// lokasi dari GPS HP lewat plugin geolocator
class LokasiGps implements LayananLokasi {
  static const _gpsMati = GagalLokasi(
    'GPS HP mati. Nyalakan lokasi untuk melihat jarak ke mitra.',
    keSetelan: true,
  );

  @override
  Future<Posisi> posisiSaya({bool minta = true}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw _gpsMati;
      var izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied && minta) {
        izin = await Geolocator.requestPermission();
      }
      switch (izin) {
        case LocationPermission.denied:
          throw const GagalLokasi('Izin lokasi belum diberikan.');
        case LocationPermission.deniedForever:
          throw const GagalLokasi(
            'Izin lokasi ditolak. Buka setelan untuk mengizinkan.',
            keSetelan: true,
          );
        default:
      }
      // akurasi sedang cukup buat jarak antar gerai, lebih cepet dan hemat baterai
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return Posisi(p.latitude, p.longitude);
    } on GagalLokasi {
      rethrow;
    } catch (_) {
      // plugin ga ada (tes / web), waktu habis, dll
      throw const GagalLokasi('Lokasi belum bisa diambil. Coba lagi.');
    }
  }

  @override
  Future<void> bukaSetelan({required bool gpsMati}) async {
    try {
      gpsMati
          ? await Geolocator.openLocationSettings()
          : await Geolocator.openAppSettings();
    } catch (_) {
      // setelan ga bisa dibuka, pengguna tetap bisa pakai aplikasi tanpa lokasi
    }
  }
}
