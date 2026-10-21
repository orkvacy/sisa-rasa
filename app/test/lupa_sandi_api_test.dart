import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sisa_rasa/data/repositories/akun_api.dart';
import 'package:sisa_rasa/domain/repositories/layanan_akun.dart';

void main() {
  test(
    'lupa sandi lewat server: minta kode, cek kode -> tiket, atur sandi',
    () async {
      final diminta = <http.Request>[];
      final api = AkunApi(
        alamat: 'https://api.tes',
        klien: MockClient((req) async {
          diminta.add(req);
          final isi = jsonDecode(req.body) as Map<String, dynamic>;
          return switch (req.url.path) {
            '/v1/akun/lupa-sandi' => http.Response('', 204),
            '/v1/akun/lupa-sandi/cek' when isi['kode'] == '123456' =>
              http.Response(jsonEncode({'tiket': 'tiket-1'}), 200),
            '/v1/akun/lupa-sandi/cek' => http.Response(
              jsonEncode({'pesan': 'Kode salah atau sudah kedaluwarsa.'}),
              422,
            ),
            _ => http.Response('', 204),
          };
        }),
      );

      await api.mintaKodeReset('rani@gmail.com');
      expect(
        () => api.cekKodeReset('rani@gmail.com', '000000'),
        throwsA(
          isA<GagalAkun>().having(
            (g) => g.pesan,
            'pesan',
            'Kode salah atau sudah kedaluwarsa.',
          ),
        ),
      );
      expect(await api.cekKodeReset('rani@gmail.com', '123456'), 'tiket-1');
      await api.aturSandiBaru('tiket-1', 'sandibaru123');

      expect(
        [for (final r in diminta) r.url.path],
        [
          '/v1/akun/lupa-sandi',
          '/v1/akun/lupa-sandi/cek',
          '/v1/akun/lupa-sandi/cek',
          '/v1/akun/lupa-sandi/atur',
        ],
      );
      expect(jsonDecode(diminta.last.body), {
        'tiket': 'tiket-1',
        'sandi': 'sandibaru123',
      });
      // ga ada token sesi yang ikut, pengguna memang belum masuk
      expect(diminta.first.headers['Authorization'], isNull);
      expect(api.modeUji, isFalse);
      expect(api.kodeUji('rani@gmail.com'), isNull);
    },
  );
}
