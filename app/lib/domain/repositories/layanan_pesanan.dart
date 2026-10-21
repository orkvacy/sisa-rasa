/// pesanan lewat server (repository pesanan di Clean Architecture).
///
/// selama aplikasi jalan tanpa API_URL, pesanan diurus PesananBloc sendiri di memori.
/// begitu tersambung server, semua aksi dikirim ke sini dan isi pesanan
/// (status, kode ambil, stok) ditentukan server (NF-10)
abstract class LayananPesanan {
  /// pembeli: pesanannya sendiri. mitra: pesanan lunas yang masuk ke gerainya
  Future<List<Map<String, dynamic>>> daftar();

  /// [kunci] idempotency key: satu per tombol Bayar, dikirim ulang apa adanya
  /// kalau request-nya diulang, biar pesanan ga dobel
  Future<Map<String, dynamic>> buat({
    required Map<String, int> isi,
    required String metode,
    required String kunci,
    String? voucher,
  });

  Future<Map<String, dynamic>> cekBayar(String id);

  Future<Map<String, dynamic>> batal(
    String id, {
    required String alasan,
    bool otomatis = false,
  });

  Future<Map<String, dynamic>> gantiMetode(String id, String metode);

  /// mitra: siap_diambil / selesai
  Future<Map<String, dynamic>> ubahStatus(String id, String status);

  Future<Map<String, dynamic>> batalMitra(String id, String alasan);
}

/// galat dari server / jaringan, [pesan] langsung ditampilin ke pengguna
class GagalLayanan implements Exception {
  const GagalLayanan(this.pesan);

  final String pesan;

  @override
  String toString() => pesan;
}
