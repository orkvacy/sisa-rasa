import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sisa_rasa/domain/repositories/layanan_akun.dart';

/// akun yg lagi masuk.
/// {} = belum masuk (layar Sambutan), {'peran': 'tamu'} = lihat-lihat tanpa akun,
/// selain itu data akun dari LayananAkun (id, nama, email, peran, token)
class AkunCubit extends Cubit<Map<String, String>> {
  AkunCubit({
    required this.layanan,
    FlutterSecureStorage? penyimpanan,
    Map<String, String> awal = const {},
  }) : penyimpanan = penyimpanan ?? const FlutterSecureStorage(),
       super(awal);

  final LayananAkun layanan;

  /// NF-14: token sesi disimpan di secure storage, bukan SharedPreferences
  final FlutterSecureStorage penyimpanan;

  static const _kunciToken = 'token_sesi';

  bool get sudahMasuk => state['id'] != null;
  bool get tamu => state['peran'] == 'tamu';

  /// dipanggil sekali pas aplikasi dibuka: lanjutin sesi yg masih berlaku
  Future<void> pulihkan() async {
    final token = await penyimpanan.read(key: _kunciToken);
    if (token == null) return;
    final akun = await layanan.sesi(token);
    if (akun == null) {
      await penyimpanan.delete(key: _kunciToken);
      return;
    }
    emit(akun);
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
    if (token != null) await layanan.keluar(token);
  }

  /// khusus mode uji: pindah akun tanpa masuk ulang (tombol Ganti akun)
  void ganti(String id) {
    emit(layanan.akunUji.firstWhere((akun) => akun['id'] == id));
  }

  /// F-63: Pengguna dapat mengubah nama profil
  void ubahNama(String namaBaru) {
    if (state.isEmpty || !sudahMasuk) return;
    emit({...state, 'nama': namaBaru.trim()});
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
