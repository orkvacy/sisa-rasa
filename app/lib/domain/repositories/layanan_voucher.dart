/// voucher platform: pembeli liat / cek di checkout, admin kelola.
/// tiap voucher: id, kode, judul, persen, maksPotongan, minBelanja,
/// mulai, berakhir, kuota (null = ga dibatasi), terpakai, khususBaru, publik, aktif.
/// galat dilempar sebagai GagalLayanan berisi pesan dari server
abstract class LayananVoucher {
  /// voucher publik yang bisa dipakai akun ini sekarang
  Future<List<Map<String, dynamic>>> tersedia();

  /// cek [kode] buat [subtotal] keranjang, balikin {voucher, potongan}
  Future<Map<String, dynamic>> cek(String kode, int subtotal);

  /// admin: semua voucher, yang terbaru di atas
  Future<List<Map<String, dynamic>>> semua();

  /// admin: voucher baru dari isian form
  Future<Map<String, dynamic>> buat(Map<String, dynamic> isian);

  /// admin: nyalain / matiin
  Future<Map<String, dynamic>> aturAktif(String id, {required bool aktif});
}
