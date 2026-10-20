/// pekerjaan admin Sisa Rasa (F-36 - F-38): verifikasi mitra yang baru daftar.
/// mitra yang belum diverifikasi ga keliatan pembeli dan ga bisa nerima pesanan
abstract class LayananAdmin {
  /// mitra dengan [status] (menunggu / terverifikasi / ditolak / nonaktif),
  /// kosong = semua. tiap mitra: id, nama, email, jenis, alamat, status,
  /// alasan, jumlahPaket, daftar (waktu daftar)
  Future<List<Map<String, dynamic>>> daftarMitra({String status = ''});

  /// ubah status mitra [id]. [alasan] wajib buat ditolak / nonaktif,
  /// dikasih tau ke mitranya di dasbor
  Future<void> periksa(String id, String status, {String alasan = ''});
}

/// status gerai mitra, sama kayak konstanta GeraiXxx di backend
abstract final class StatusGerai {
  static const menunggu = 'menunggu';
  static const terverifikasi = 'terverifikasi';
  static const ditolak = 'ditolak';
  static const nonaktif = 'nonaktif';
}
