/// titik lintang / bujur dari GPS
class Posisi {
  const Posisi(this.lat, this.lng);

  final double lat;
  final double lng;
}

/// lokasi ga bisa diambil. [keSetelan] true kalau izinnya ditolak permanen
/// atau GPS mati, jadi pengguna harus diarahkan ke setelan HP
class GagalLokasi implements Exception {
  const GagalLokasi(this.pesan, {this.keSetelan = false});

  final String pesan;
  final bool keSetelan;

  @override
  String toString() => pesan;
}

/// lokasi HP (F-66). cuma dipakai di HP buat ngitung jarak ke gerai,
/// lokasi pembeli ga pernah dikirim ke server
abstract class LayananLokasi {
  /// posisi sekarang. [minta] false = jangan munculin dialog izin,
  /// langsung gagal kalau izinnya belum dikasih
  Future<Posisi> posisiSaya({bool minta = true});

  /// buka setelan izin aplikasi / setelan lokasi HP
  Future<void> bukaSetelan({required bool gpsMati});
}
