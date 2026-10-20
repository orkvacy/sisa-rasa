import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sisa_rasa/core/sesi_aktif.dart';
import 'package:sisa_rasa/domain/repositories/layanan_pesanan.dart';

/// pengirim request ke server Go buat paket & pesanan.
/// token diambil dari [sesi] tiap kirim, galat jadi GagalLayanan berisi pesan server
class KlienApi {
  KlienApi({required this.alamat, required this.sesi, http.Client? klien})
    : _klien = klien ?? http.Client();

  /// alamat dasar server, misal https://api.sisarasa.web.id
  final String alamat;
  final SesiAktif sesi;
  final http.Client _klien;

  static const _batasWaktu = Duration(seconds: 15);
  static const _gagalTerhubung = GagalLayanan(
    'Tidak bisa terhubung ke server. Cek koneksi internetmu lalu coba lagi.',
  );

  Map<String, String> _kepala(Map<String, String>? tambahan) => {
    'Content-Type': 'application/json',
    if (sesi.token != null) 'Authorization': 'Bearer ${sesi.token}',
    ...?tambahan,
  };

  Future<Map<String, dynamic>> get(String jalur) => _kirim('GET', jalur);

  Future<Map<String, dynamic>> post(
    String jalur, [
    Object? isi,
    Map<String, String>? kepala,
  ]) => _kirim('POST', jalur, isi, kepala);

  Future<Map<String, dynamic>> put(String jalur, Object? isi) =>
      _kirim('PUT', jalur, isi);

  Future<Map<String, dynamic>> patch(String jalur, Object? isi) =>
      _kirim('PATCH', jalur, isi);

  Future<Map<String, dynamic>> delete(String jalur) => _kirim('DELETE', jalur);

  /// kirim file [jalurBerkas] sebagai multipart/form-data di field [field]
  Future<Map<String, dynamic>> unggah(
    String jalur,
    String field,
    String jalurBerkas,
  ) async {
    final req = http.MultipartRequest('POST', Uri.parse('$alamat$jalur'))
      ..headers.addAll({
        if (sesi.token != null) 'Authorization': 'Bearer ${sesi.token}',
      })
      ..files.add(await http.MultipartFile.fromPath(field, jalurBerkas));
    return _jawab(() => _klien.send(req), batas: const Duration(seconds: 60));
  }

  Future<Map<String, dynamic>> _kirim(
    String metode,
    String jalur, [
    Object? isi,
    Map<String, String>? kepala,
  ]) async {
    final req = http.Request(metode, Uri.parse('$alamat$jalur'))
      ..headers.addAll(_kepala(kepala));
    if (isi != null) req.body = jsonEncode(isi);
    return _jawab(() => _klien.send(req));
  }

  /// kirim lalu baca jawaban server. galat jaringan / batas waktu jadi
  /// GagalLayanan, galat dari server jadi GagalLayanan berisi pesan server
  Future<Map<String, dynamic>> _jawab(
    Future<http.StreamedResponse> Function() kirim, {
    Duration batas = _batasWaktu,
  }) async {
    final http.Response res;
    try {
      res = await http.Response.fromStream(await kirim().timeout(batas))
          .timeout(batas);
    } on TimeoutException {
      throw _gagalTerhubung;
    } on http.ClientException {
      throw _gagalTerhubung;
    }

    final Map<String, dynamic> hasil;
    try {
      hasil = res.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } on FormatException {
      throw const GagalLayanan('Jawaban server tidak bisa dibaca.');
    }
    if (res.statusCode == 401) {
      throw const GagalLayanan('Sesi berakhir. Keluar lalu masuk lagi.');
    }
    if (res.statusCode >= 400) {
      throw GagalLayanan(
        hasil['pesan'] as String? ?? 'Terjadi gangguan. Coba lagi sebentar.',
      );
    }
    return hasil;
  }
}
