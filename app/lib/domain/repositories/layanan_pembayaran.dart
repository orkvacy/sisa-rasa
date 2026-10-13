/// semua urusan bayar lewat kelas ini.
/// layar sama bloc ga tau pembayarannya asli atau tiruan,
/// jadi pas backend udah ada cukup tuker implementasinya (NF-04).
///
/// status lunas yg asli harus dari server, bukan dari aplikasi (NF-10),
/// makanya aplikasi cuma bisa "nanya" udah lunas apa belum
abstract class LayananPembayaran {
  /// true kalau ga ada uang beneran yg pindah, layar pembayaran nampilin keterangan
  bool get modeUji;

  /// bikin tagihan buat satu pesanan, balikin isi QR / nomor VA / tautan GoPay
  Future<Map<String, String>> buatTagihan({
    required String idPesanan,
    required String metode,
    required int total,
  });

  /// nanya ke penyedia pembayaran, pesanan ini udah lunas belum
  Future<bool> sudahLunas(String idPesanan);
}
