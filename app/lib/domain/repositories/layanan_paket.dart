/// sumber daftar paket (repository paket di Clean Architecture).
/// tanpa API_URL dari data contoh di HP, kalau tersambung dari server Go,
/// tinggal tuker implementasinya di injection.dart (NF-04).
abstract class LayananPaket {
  /// true = data contoh di HP. perubahan dari mitra cukup diurus PaketCubit di memori,
  /// ga ada yg perlu dikirim. false = tiap perubahan dikirim ke server
  bool get lokal;

  /// semua paket yg lagi ditawarin, dari semua mitra
  Future<List<Map<String, dynamic>>> semua();

  /// paket baru dari mitra yg lagi masuk (F-15)
  Future<void> tambah(Map<String, dynamic> isian);

  /// [isian] lengkap: data paket lama yg udah ditimpa isian form (F-18)
  Future<void> ubah(String id, Map<String, dynamic> isian);

  Future<void> hapus(String id);

  /// F-44
  Future<void> aturSisa(String id, int sisa);

  /// F-45
  Future<void> aturAktif(String id, {required bool aktif});

  /// F-51
  Future<void> aturGerai({required bool tutup});

  /// F-66: titik gerai dari GPS HP mitra
  Future<void> aturLokasi(double lat, double lng);

  /// F-37: status verifikasi gerai mitra yang lagi masuk, isinya
  /// status (StatusGerai) dan alasan kalau ditolak / dinonaktifkan admin
  Future<Map<String, dynamic>> statusGerai();

  /// foto paket dari HP ([jalur] file), balikin isi field 'foto' paket:
  /// URL di server, atau file:// kalau ga tersambung server
  Future<String> unggahFoto(String jalur);
}
