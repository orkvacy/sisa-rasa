import 'dart:math';

import 'package:sisa_rasa/data/sumber/dummy_akun.dart';
import 'package:sisa_rasa/domain/aturan/akun.dart';
import 'package:sisa_rasa/domain/repositories/layanan_akun.dart';

/// pengganti server selama backend belum ada.
/// kata sandi di sini cuma buat simulasi server: di versi asli kata sandi
/// cuma ada di server dalam bentuk hash bcrypt, aplikasi ga pernah nyimpen (F-31).
/// akun yg didaftarin ilang pas aplikasi ditutup
class AkunTiruan implements LayananAkun {
  AkunTiruan({DateTime Function()? jam}) : _jam = jam ?? DateTime.now {
    for (final akun in dummyAkun) {
      _akun[akun['email']!] = {...akun, 'sandi': sandiUji};
    }
  }

  /// jam bisa diganti di tes, buat ngecek kode kedaluwarsa
  final DateTime Function() _jam;

  final _akun = <String, Map<String, String>>{};
  // token tiruan = "acak.versi.email", jadi masih kebaca walau aplikasi dibuka ulang.
  // token asli dari server ga boleh bisa ditebak isinya kayak gini
  final _dicabut = <String>{};
  // naik tiap ganti kata sandi, token versi lama ga berlaku lagi
  final _versiSesi = <String, int>{};
  final _kodeReset = <String, Map<String, dynamic>>{};
  final _tiket = <String, String>{}; // tiket -> email
  final _acak = Random.secure();

  @override
  bool get modeUji => true;

  @override
  List<Map<String, String>> get akunUji => dummyAkun;

  /// email belum beneran dikirim, kodenya ditampilin di layar
  @override
  String? kodeUji(String email) => _kodeReset[rapikanEmail(email)]?['kode'];

  String _hex(int panjang) => List.generate(
    panjang,
    (_) => _acak.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  Map<String, String> _bukaSesi(Map<String, String> akun) {
    final email = akun['email']!;
    final token = '${_hex(32)}.${_versiSesi[email] ?? 0}.$email';
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
    if (_dicabut.contains(token)) return null;
    final bagian = token.split('.');
    if (bagian.length < 3) return null;
    final versi = int.tryParse(bagian[1]);
    final email = bagian.sublist(2).join('.');
    final akun = _akun[email];
    if (akun == null || versi != (_versiSesi[email] ?? 0)) return null;
    return {..._tanpaSandi(akun), 'token': token};
  }

  @override
  Future<void> keluar(String token) async => _dicabut.add(token);

  @override
  Future<void> mintaKodeReset(String email) async {
    final kunci = rapikanEmail(email);
    final lama = _kodeReset[kunci];
    if (lama != null) {
      final boleh = (lama['dikirim'] as DateTime).add(jedaKirimUlang);
      if (_jam().isBefore(boleh)) {
        final sisa = boleh.difference(_jam()).inSeconds + 1;
        throw GagalAkun('Tunggu $sisa detik sebelum minta kode lagi.');
      }
    }
    // email ga terdaftar: diem aja, layar tetep bilang "kode dikirim"
    if (!_akun.containsKey(kunci)) return;
    _kodeReset[kunci] = {
      'kode': (_acak.nextInt(900000) + 100000).toString(),
      'dikirim': _jam(),
      'salah': 0,
    };
  }

  @override
  Future<String> cekKodeReset(String email, String kode) async {
    final kunci = rapikanEmail(email);
    final data = _kodeReset[kunci];
    const salah = GagalAkun('Kode salah atau sudah kedaluwarsa.');
    if (data == null) throw salah;
    final habis = (data['dikirim'] as DateTime).add(berlakuKodeReset);
    if (!_jam().isBefore(habis)) {
      _kodeReset.remove(kunci);
      throw salah;
    }
    if (data['kode'] != kode) {
      data['salah'] = (data['salah'] as int) + 1;
      if (data['salah'] >= batasSalahKode) {
        _kodeReset.remove(kunci);
        throw const GagalAkun('Terlalu banyak percobaan. Minta kode baru.');
      }
      throw salah;
    }
    // sekali pakai: abis cocok, kodenya langsung dihapus
    _kodeReset.remove(kunci);
    final tiket = _hex(16);
    _tiket[tiket] = kunci;
    return tiket;
  }

  @override
  Future<void> aturSandiBaru(String tiket, String sandi) async {
    final email = _tiket.remove(tiket);
    if (email == null) {
      throw const GagalAkun('Sesi atur ulang sudah habis. Ulangi dari awal.');
    }
    if (sandi.length < panjangSandiMinimal) {
      throw const GagalAkun('Kata sandi minimal 8 karakter.');
    }
    _akun[email] = {..._akun[email]!, 'sandi': sandi};
    // semua HP yg masih masuk ke akun ini dikeluarin
    _versiSesi[email] = (_versiSesi[email] ?? 0) + 1;
  }
}
