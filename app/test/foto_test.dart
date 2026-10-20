import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sisa_rasa/core/sesi_aktif.dart';
import 'package:sisa_rasa/data/repositories/paket_api.dart';
import 'package:sisa_rasa/data/repositories/paket_lokal.dart';
import 'package:sisa_rasa/data/sumber/klien_api.dart';
import 'package:sisa_rasa/presentation/widgets/gambar_paket.dart';

void main() {
  test('sumber gambar sesuai asal fotonya', () {
    expect(
      GambarPaket.sumber('assets/images/paket/sushi.jpg'),
      isA<AssetImage>(),
    );
    expect(
      GambarPaket.sumber('https://cdn.sisarasa.web.id/paket/a.jpg'),
      isA<NetworkImage>().having(
        (n) => n.url,
        'url',
        'https://cdn.sisarasa.web.id/paket/a.jpg',
      ),
    );
    expect(GambarPaket.sumber('/v1/foto/a.jpg'), isA<NetworkImage>());
    expect(GambarPaket.sumber('file:///data/foto.jpg'), isA<FileImage>());
  });

  test('tanpa server: foto dipakai langsung dari file di HP', () async {
    expect(await PaketLokal().unggahFoto('/data/x.jpg'), 'file:///data/x.jpg');
  });

  test(
    'unggah foto: multipart field foto + token, balikin URL dari server',
    () async {
      final berkas = File('${Directory.systemTemp.path}/sisa_rasa_tes_foto.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]);
      addTearDown(() => berkas.deleteSync());

      late http.BaseRequest terkirim;
      late String badan;
      final api = PaketApi(
        KlienApi(
          alamat: 'https://api.tes',
          sesi: SesiAktif()..token = 'tok-1',
          klien: MockClient.streaming((req, aliran) async {
            terkirim = req;
            badan = latin1.decode(await aliran.toBytes());
            return http.StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'foto': 'https://cdn.sisarasa.web.id/paket/a.jpg',
                  }),
                ),
              ),
              201,
            );
          }),
        ),
      );

      final url = await api.unggahFoto(berkas.path);
      expect(url, 'https://cdn.sisarasa.web.id/paket/a.jpg');
      expect(terkirim.url.path, '/v1/mitra/foto');
      expect(terkirim.headers['Authorization'], 'Bearer tok-1');
      expect(
        terkirim.headers['content-type'],
        startsWith('multipart/form-data'),
      );
      expect(badan, contains('name="foto"'));
    },
  );
}
