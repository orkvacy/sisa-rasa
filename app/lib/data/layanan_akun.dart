import 'dart:math';

import 'package:sisa_rasa/data/dummy_akun.dart';

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

  /// akun pemilik token, null kalau token udah ga berlaku
  Future<Map<String, String>?> sesi(String token);

  /// F-33: token dicabut, ga bisa dipake lagi
  Future<void> keluar(String token);
}

/// pengganti server selama backend belum ada.
/// kata sandi di sini cuma buat simulasi server: di versi asli kata sandi
/// cuma ada di server dalam bentuk hash bcrypt, aplikasi ga pernah nyimpen (F-31).
/// akun yg didaftarin ilang pas aplikasi ditutup
class AkunTiruan implements LayananAkun {
  AkunTiruan() {
    for (final akun in dummyAkun) {
      _akun[akun['email']!] = {...akun, 'sandi': sandiUji};
    }
  }

  final _akun = <String, Map<String, String>>{};
  // token tiruan = "acak.email", jadi masih kebaca walau aplikasi dibuka ulang.
  // token asli dari server ga boleh bisa ditebak isinya kayak gini
  final _dicabut = <String>{};
  final _acak = Random.secure();

  Map<String, String> _bukaSesi(Map<String, String> akun) {
    final acak = List.generate(
      32,
      (_) => _acak.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final token = '$acak.${akun['email']}';
    return {..._tanpaSandi(akun), 'token': token};
  }

  Map<String, String> _tanpaSandi(Map<String, String> akun) =>
      {...akun}..remove('sandi');

  @override
  Future<Map<String, String>> masuk(String email, String sandi) async {
    final akun = _akun[rapikanEmail(email)];
    // pesannya sengaja sama buat email ga terdaftar dan sandi salah,
    // biar ga bisa dipake nebak email siapa aja yg terdaftar (SRS 3.4)
    if (akun == null || akun['sandi'] != sandi) {
      throw const GagalAkun(
        'Email atau kata sandi salah. Coba lagi, atau atur ulang kata sandi.',
      );
    }
    return _bukaSesi(akun);
  }

  @override
  Future<Map<String, String>> daftar({
    required String nama,
    required String email,
    required String sandi,
    required String peran,
  }) async {
    final kunci = rapikanEmail(email);
    if (_akun.containsKey(kunci)) {
      throw const GagalAkun('Email ini sudah terdaftar. Masuk saja.');
    }
    // F-36: admin ga bisa daftar lewat aplikasi
    if (peran != 'pembeli' && peran != 'mitra') {
      throw const GagalAkun('Peran tidak dikenal.');
    }
    final akun = {
      'id': 'a${_akun.length + 1}',
      'nama': nama.trim(),
      'email': kunci,
      'peran': peran,
      'sandi': sandi,
    };
    _akun[kunci] = akun;
    return _bukaSesi(akun);
  }

  @override
  Future<Map<String, String>?> sesi(String token) async {
    if (_dicabut.contains(token) || !token.contains('.')) return null;
    final akun = _akun[token.substring(token.indexOf('.') + 1)];
    if (akun == null) return null;
    return {..._tanpaSandi(akun), 'token': token};
  }

  @override
  Future<void> keluar(String token) async => _dicabut.add(token);
}

String rapikanEmail(String email) => email.trim().toLowerCase();

/// format email sederhana: ada@nama.domain
bool emailValid(String email) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(email.trim());

/// F-29: minimal 8 karakter
const panjangSandiMinimal = 8;
