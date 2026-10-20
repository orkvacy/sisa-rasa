/// jendela pilih akun Google di HP (F-30b). hasilnya ID token yang
/// dikirim ke server buat diperiksa, aplikasi sendiri ga percaya isinya
abstract class MasukGoogle {
  /// false kalau belum diatur (tanpa server / GOOGLE_CLIENT_ID kosong),
  /// tombol Google ga ditampilin
  bool get tersedia;

  /// buka pilihan akun Google. null kalau pengguna batal.
  /// lempar GagalAkun kalau Google-nya gagal (salah atur, ga ada internet)
  Future<String?> ambilIdToken();

  /// lupain akun Google yang tadi dipilih, biar pas masuk lagi bisa pilih akun lain
  Future<void> keluar();
}
