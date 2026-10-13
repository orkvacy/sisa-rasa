import 'dart:async';

/// kejadian yg dikirim server ke aplikasi lewat koneksi percakapan:
/// {'jenis': 'pesan', 'pesan': {...}} pesan baru (punya sendiri yg udah diterima server,
///   atau dari lawan bicara)
/// {'jenis': 'dibaca', 'idPesanan': ..., 'oleh': 'pembeli' / 'mitra'} lawan bicara udah baca
typedef KejadianPercakapan = Map<String, dynamic>;

/// semua urusan percakapan per pesanan (F-67) lewat kelas ini.
/// nanti diganti versi WebSocket ke server Go (NF-17), layar sama cubit ga perlu diubah
abstract class LayananPercakapan {
  Stream<KejadianPercakapan> get kejadian;

  /// riwayat lengkap satu percakapan, dipanggil pas layarnya dibuka (F-68)
  Future<List<Map<String, dynamic>>> riwayat(String idPesanan);

  /// [pesan] udah bawa 'id' unik dari aplikasi. kalau terkirim dua kali
  /// (misal koneksi putus sebelum server sempet bales), server cuma nyatet sekali (NF-18)
  Future<void> kirim(Map<String, dynamic> pesan);

  /// semua pesan dari lawan bicara di percakapan ini ditandai udah dibaca [oleh]
  Future<void> tandaiDibaca(String idPesanan, String oleh);
}
