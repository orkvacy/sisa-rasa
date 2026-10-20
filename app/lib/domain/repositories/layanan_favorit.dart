/// mitra favorit pembeli (ikon hati di halaman mitra & detail paket).
/// tiap mitra: id, nama, jenis
abstract class LayananFavorit {
  /// favorit akun yang lagi masuk, yang terbaru disimpan di depan
  Future<List<Map<String, dynamic>>> semua();

  /// simpan ([suka] true) atau lepas mitra [idMitra]. aman diulang
  Future<void> atur(String idMitra, {required bool suka});
}
