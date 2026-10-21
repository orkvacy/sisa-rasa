import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sisa_rasa/domain/repositories/layanan_akun.dart';

/// akun lewat server Go (backend/internal/akun). dipake kalau aplikasi di-build
/// dengan --dart-define=API_URL=..., lihat injection.dart
class AkunApi implements LayananAkun {
  AkunApi({required this.alamat, http.Client? klien})
    : _klien = klien ?? http.Client();

  /// alamat dasar server, misal http://192.168.1.10:8080
  final String alamat;
  final http.Client _klien;

  static const _batasWaktu = Duration(seconds: 15);
  static const _gagalTerhubung = GagalAkun(
    'Tidak bisa terhubung ke server. Cek koneksi internetmu lalu coba lagi.',
  );

  Uri _uri(String jalur) => Uri.parse('$alamat$jalur');

  Map<String, String> _kepala([String? token]) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  /// kirim request, galat jaringan / batas waktu jadi GagalAkun
  Future<http.Response> _kirim(Future<http.Response> Function() aksi) async {
    try {
      return await aksi().timeout(_batasWaktu);
    } on TimeoutException {
      throw _gagalTerhubung;
    } on http.ClientException {
      throw _gagalTerhubung;
    }
  }

  /// isi JSON dari jawaban server, galat dari server jadi GagalAkun dengan pesannya
  Map<String, dynamic> _isi(http.Response res) {
    final isi = res.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw GagalAkun(
        isi['pesan'] as String? ?? 'Terjadi gangguan. Coba lagi sebentar.',
      );
    }
    return isi;
  }

  /// {"akun": {...}, "token": "..."} -> satu map datar kayak AkunTiruan
  Map<String, String> _akunDanToken(Map<String, dynamic> isi) => {
    for (final MapEntry(:key, :value)
        in (isi['akun'] as Map<String, dynamic>).entries)
      key: '$value',
    if (isi['token'] != null) 'token': isi['token'] as String,
  };

  @override
  Future<Map<String, String>> masuk(String email, String sandi) async {
    final res = await _kirim(
      () => _klien.post(
        _uri('/v1/akun/masuk'),
        headers: _kepala(),
        body: jsonEncode({'email': email, 'sandi': sandi}),
      ),
    );
    return _akunDanToken(_isi(res));
  }

  @override
  Future<Map<String, String>> masukGoogle(String idToken) async {
    final res = await _kirim(
      () => _klien.post(
        _uri('/v1/akun/google'),
        headers: _kepala(),
        body: jsonEncode({'idToken': idToken}),
      ),
    );
    return _akunDanToken(_isi(res));
  }

  @override
  Future<Map<String, String>> daftar({
    required String nama,
    required String email,
    required String sandi,
    required String peran,
  }) async {
    final res = await _kirim(
      () => _klien.post(
        _uri('/v1/akun/daftar'),
        headers: _kepala(),
        body: jsonEncode({
          'nama': nama,
          'email': email,
          'sandi': sandi,
          'peran': peran,
        }),
      ),
    );
    return _akunDanToken(_isi(res));
  }

  @override
  Future<Map<String, String>?> sesi(String token) async {
    final res = await _kirim(
      () => _klien.get(_uri('/v1/akun/saya'), headers: _kepala(token)),
    );
    // token ga berlaku lagi: bukan galat, cukup dianggap belum masuk
    if (res.statusCode == 401) return null;
    return {..._akunDanToken(_isi(res)), 'token': token};
  }

  @override
  Future<void> keluar(String token) async {
    await _kirim(
      () => _klien.post(_uri('/v1/akun/keluar'), headers: _kepala(token)),
    );
  }

  @override
  Future<Map<String, String>> ubahNama(String token, String nama) async {
    final res = await _kirim(
      () => _klien.patch(
        _uri('/v1/akun/saya'),
        headers: _kepala(token),
        body: jsonEncode({'nama': nama}),
      ),
    );
    return _akunDanToken(_isi(res));
  }

  @override
  Future<void> hapusAkun(
    String token,
    String sandi, {
    String idToken = '',
  }) async {
    final res = await _kirim(
      () => _klien.post(
        _uri('/v1/akun/hapus'),
        headers: _kepala(token),
        body: jsonEncode({'sandi': sandi, 'idToken': idToken}),
      ),
    );
    _isi(res);
  }

  // F-61 atur ulang kata sandi: kode 6 angka dikirim server ke email
  Future<Map<String, dynamic>> _kirimJson(String jalur, Object isi) async {
    final res = await _kirim(
      () => _klien.post(_uri(jalur), headers: _kepala(), body: jsonEncode(isi)),
    );
    return _isi(res);
  }

  @override
  Future<void> mintaKodeReset(String email) =>
      _kirimJson('/v1/akun/lupa-sandi', {'email': email});

  @override
  Future<String> cekKodeReset(String email, String kode) async {
    final hasil = await _kirimJson('/v1/akun/lupa-sandi/cek', {
      'email': email,
      'kode': kode,
    });
    return hasil['tiket'] as String;
  }

  @override
  Future<void> aturSandiBaru(String tiket, String sandi) =>
      _kirimJson('/v1/akun/lupa-sandi/atur', {'tiket': tiket, 'sandi': sandi});

  @override
  bool get modeUji => false;

  @override
  List<Map<String, String>> get akunUji => const [];

  @override
  String? kodeUji(String email) => null;
}
