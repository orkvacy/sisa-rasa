/// rekening pencairan + riwayat saldo mitra dari server (F-48 s.d. F-50).
/// riwayat di sini catatan yg udah ada di server (dana masuk hari-hari lalu, pencairan).
/// dana masuk dari pesanan yg baru selesai dihitung langsung di aplikasi
abstract class LayananSaldo {
  Future<Map<String, dynamic>?> rekening(String mitra);

  Future<List<Map<String, dynamic>>> riwayat(String mitra);

  /// F-49: satu mitra satu rekening, yg baru menggantikan yg lama
  Future<void> simpanRekening(String mitra, Map<String, dynamic> rekening);
}
