import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sisa_rasa/domain/repositories/layanan_akun.dart';
import 'package:sisa_rasa/domain/repositories/masuk_google.dart';

/// akun yg lagi masuk.
/// {} = belum masuk (layar Sambutan), {'peran': 'tamu'} = lihat-lihat tanpa akun,
/// {'luring': '1', 'pesan': ...} = ada sesi tersimpan tapi server ga bisa dihubungi,
/// selain itu data akun dari LayananAkun (id, nama, email, peran, token)
class AkunCubit extends Cubit<Map<String, String>> {
  AkunCubit({
    required this.layanan,
    this.google,
    FlutterSecureStorage? penyimpanan,
    Map<String, String> awal = const {},
  }) : penyimpanan = penyimpanan ?? const FlutterSecureStorage(),
       super(awal);

  final LayananAkun layanan;

  /// kosong di tes yang ga butuh Google
  final MasukGoogle? google;

  /// tombol "Masuk dengan Google" cuma muncul kalau ini true
  bool get bisaGoogle => google?.tersedia ?? false;

  /// akun Google tanpa sandi, konfirmasi hapus akunnya lewat Google
  bool get tanpaSandi => state['punyaSandi'] == 'false';

  /// NF-14: token sesi disimpan di secure storage, bukan SharedPreferences
  final FlutterSecureStorage penyimpanan;

  static const _kunciToken = 'token_sesi';

  bool get sudahMasuk => state['id'] != null;
  bool get tamu => state['peran'] == 'tamu';

  /// sesi tersimpan tapi belum bisa dicek karena ga ada koneksi (layar TanpaKoneksi)
  bool get luring => state['luring'] == '1';

  /// dipanggil pas aplikasi dibuka: lanjutin sesi yg masih berlaku.
  /// dipanggil lagi dari tombol "Coba lagi" di layar TanpaKoneksi
  Future<void> pulihkan() async {
    final token = await penyimpanan.read(key: _kunciToken);
    if (token == null) {
      if (luring) emit(const {});
      return;
    }
    final Map<String, String>? akun;
    try {
      akun = await layanan.sesi(token);
    } on GagalAkun catch (e) {
      // server ga bisa dihubungi: token tetap disimpen, jangan dilempar ke
      // layar masuk. tunggu di layar TanpaKoneksi sampai bisa dicek lagi
      if (!isClosed) emit({'luring': '1', 'pesan': e.pesan});
      return;
    }
    if (akun == null) {
      await penyimpanan.delete(key: _kunciToken);
      if (!isClosed) emit(const {});
      return;
    }
    if (!isClosed) emit(akun);
  }

  /// lempar GagalAkun kalau email / sandi salah
  Future<void> masuk(String email, String sandi) async {
    _mulaiSesi(await layanan.masuk(email, sandi));
  }

  Future<void> daftar({
    required String nama,
    required String email,
    required String sandi,
    required String peran,
  }) async {
    _mulaiSesi(
      await layanan.daftar(
        nama: nama,
        email: email,
        sandi: sandi,
        peran: peran,
      ),
    );
  }

  /// F-30b: false kalau pengguna batal milih akun.
  /// lempar GagalAkun kalau Google / server nolak
  Future<bool> masukGoogle() async {
    final token = await google?.ambilIdToken();
    if (token == null) return false;
    try {
      _mulaiSesi(await layanan.masukGoogle(token));
    } on GagalAkun {
      // ditolak server (misal email udah pakai sandi): akun Google-nya
      // dilupain biar percobaan berikutnya bisa pilih akun lain
      await google?.keluar();
      rethrow;
    }
    return true;
  }

  void _mulaiSesi(Map<String, String> akun) {
    penyimpanan.write(key: _kunciToken, value: akun['token']);
    emit(akun);
  }

  /// "Lihat paket dulu" di Sambutan
  void lihatSebagaiTamu() => emit(const {'peran': 'tamu'});

  /// F-33: token dicabut di server, terus dihapus dari HP
  Future<void> keluar() async {
    final token = state['token'];
    emit(const {});
    await penyimpanan.delete(key: _kunciToken);
    await google?.keluar();
    if (token != null) await layanan.keluar(token);
  }

  /// F-63: lempar GagalAkun kalau ditolak
  Future<void> ubahNama(String nama) async {
    final token = state['token'];
    if (token == null) return;
    final baru = await layanan.ubahNama(token, nama);
    emit({...state, ...baru, 'token': token});
  }

  /// F-62: lempar GagalAkun kalau sandi salah / masih ada pesanan berjalan.
  /// berhasil = sama kayak keluar, token dihapus dari HP
  Future<void> hapusAkun(String sandi) async {
    final token = state['token'];
    if (token == null) return;
    await layanan.hapusAkun(token, sandi);
    await penyimpanan.delete(key: _kunciToken);
    emit(const {});
  }

  /// F-62 buat akun Google tanpa sandi: pilih akun Google yang sama lagi.
  /// false kalau batal milih akun
  Future<bool> hapusAkunGoogle() async {
    final token = state['token'];
    if (token == null) return false;
    final idToken = await google?.ambilIdToken();
    if (idToken == null) return false;
    await layanan.hapusAkun(token, '', idToken: idToken);
    await penyimpanan.delete(key: _kunciToken);
    await google?.keluar();
    emit(const {});
    return true;
  }

  /// khusus mode uji: pindah akun tanpa masuk ulang (tombol Ganti akun)
  void ganti(String id) {
    emit(layanan.akunUji.firstWhere((akun) => akun['id'] == id));
  }
}

String namaPeran(String peran) => switch (peran) {
  'mitra' => 'Mitra',
  'admin' => 'Admin',
  _ => 'Pembeli',
};

/// dua huruf depan nama, dipake di avatar. "Rani Amelia" -> "RA"
String inisial(String nama) {
  final kata = nama.trim().split(RegExp(r'\s+'));
  if (kata.length == 1) return kata.first.substring(0, 1).toUpperCase();
  return (kata[0][0] + kata[1][0]).toUpperCase();
}
