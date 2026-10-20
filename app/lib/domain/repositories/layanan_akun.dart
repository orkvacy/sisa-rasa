/// gagal masuk / daftar, pesannya langsung ditampilin ke pengguna
class GagalAkun implements Exception {
  const GagalAkun(this.pesan);

  final String pesan;

  @override
  String toString() => pesan;
}

/// semua urusan akun (daftar, masuk, keluar) lewat kelas ini.
/// layar sama cubit ga tau datanya dari server atau tiruan,
/// jadi pas backend Go udah ada cukup tuker implementasinya (NF-04).
///
/// hasil masuk / daftar: data akun + 'token' sesi
abstract class LayananAkun {
  Future<Map<String, String>> masuk(String email, String sandi);

  Future<Map<String, String>> daftar({
    required String nama,
    required String email,
    required String sandi,
    required String peran,
  });

  /// F-30b: [idToken] dari Google diperiksa server. akun baru otomatis jadi
  /// pembeli tanpa kata sandi ('punyaSandi': 'false').
  /// lempar GagalAkun kalau emailnya udah terdaftar pakai sandi
  Future<Map<String, String>> masukGoogle(String idToken);

  /// akun pemilik token, null kalau token udah ga berlaku
  Future<Map<String, String>?> sesi(String token);

  /// F-33: token dicabut, ga bisa dipake lagi
  Future<void> keluar(String token);

  /// F-63: ganti nama akun pembeli, balikin data akun terbaru (tanpa token).
  /// lempar GagalAkun kalau ditolak (misal akun mitra)
  Future<Map<String, String>> ubahNama(String token, String nama);

  /// F-62: hapus akun setelah sandinya dicek lagi. semua sesi ikut dicabut.
  /// akun Google tanpa sandi gantinya [idToken] dari masuk Google lagi.
  /// lempar GagalAkun kalau sandi salah / masih ada pesanan berjalan
  Future<void> hapusAkun(String token, String sandi, {String idToken = ''});

  /// F-61 langkah 1: kirim kode OTP ke email. sengaja ga ngasih tau
  /// emailnya terdaftar atau ga, biar ga bisa dipake nebak email orang.
  /// lempar GagalAkun kalau minta ulang sebelum [jedaKirimUlang] lewat
  Future<void> mintaKodeReset(String email);

  /// F-61 langkah 2: cocokin kode, balikin tiket sekali pakai buat langkah 3
  Future<String> cekKodeReset(String email, String kode);

  /// F-61 langkah 3: ganti kata sandi, semua sesi lama akun ini ikut dicabut
  Future<void> aturSandiBaru(String tiket, String sandi);

  /// true kalau belum nyambung ke server beneran (email belum dikirim, dll)
  bool get modeUji;

  /// akun contoh buat tombol Ganti akun, kosong kalau server beneran
  List<Map<String, String>> get akunUji;

  /// mode uji: kode OTP yg "dikirim" ke email ini, null di server beneran
  String? kodeUji(String email);
}

/// F-61: kode OTP berlaku 10 menit, cuma bisa dipake sekali
const berlakuKodeReset = Duration(minutes: 10);

/// jeda sebelum boleh minta kode lagi
const jedaKirimUlang = Duration(seconds: 60);

/// salah masukin kode lebih dari ini, kodenya hangus
const batasSalahKode = 5;
