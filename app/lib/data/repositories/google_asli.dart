import 'package:google_sign_in/google_sign_in.dart';
import 'package:sisa_rasa/domain/repositories/layanan_akun.dart';
import 'package:sisa_rasa/domain/repositories/masuk_google.dart';

/// Google Sign-In beneran. [serverClientId] = web client ID yang sama
/// kayak GOOGLE_CLIENT_ID di server, jadi aud token-nya cocok.
/// client ID bukan rahasia, aman ditaruh di aplikasi (NF-16)
class GoogleAsli implements MasukGoogle {
  GoogleAsli(this.serverClientId);

  final String serverClientId;

  Future<void>? _siap;

  GoogleSignIn get _google => GoogleSignIn.instance;

  Future<void> _mulai() =>
      _siap ??= _google.initialize(serverClientId: serverClientId);

  @override
  bool get tersedia => serverClientId.isNotEmpty;

  @override
  Future<String?> ambilIdToken() async {
    try {
      await _mulai();
      final akun = await _google.authenticate();
      return akun.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      throw GagalAkun(
        'Masuk dengan Google gagal (${e.code.name}). Coba lagi, atau pakai email.',
      );
    }
  }

  @override
  Future<void> keluar() async {
    if (_siap == null) return;
    try {
      await _siap;
      await _google.signOut();
    } on GoogleSignInException {
      // ga penting, paling pilihan akunnya ga muncul lagi
    }
  }
}

/// tanpa server (mode tiruan) atau client ID belum diisi: tombol Google disembunyiin
class GoogleMati implements MasukGoogle {
  const GoogleMati();

  @override
  bool get tersedia => false;

  @override
  Future<String?> ambilIdToken() async =>
      throw const GagalAkun('Masuk dengan Google belum tersedia.');

  @override
  Future<void> keluar() async {}
}
