/// sumber daftar paket (repository paket di Clean Architecture).
/// sekarang dari data contoh di HP, nanti dari server Go lewat API,
/// tinggal tuker implementasinya di injection.dart (NF-04).
///
/// perubahan dari mitra (tambah, ubah, sisa porsi) masih diurus PaketCubit di memori,
/// nanti ikut lewat sini begitu API-nya ada
abstract class LayananPaket {
  /// semua paket yg lagi ditawarin, dari semua mitra
  Future<List<Map<String, dynamic>>> semua();
}
