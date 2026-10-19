import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sisa_rasa/data/repositories/akun_api.dart';
import 'package:sisa_rasa/domain/repositories/layanan_akun.dart';
import 'package:sisa_rasa/presentation/cubit/akun_cubit.dart';

/// server pura-pura yang ngikutin bentuk jawaban backend/internal/akun
MockClient serverPalsu({bool mati = false}) => MockClient((req) async {
  if (mati) throw http.ClientException('koneksi ditolak');
  final jalur = req.url.path;
  final token = req.headers['Authorization'];
  if (jalur == '/v1/akun/masuk') {
    final isi = jsonDecode(req.body) as Map<String, dynamic>;
    if (isi['sandi'] != 'sisarasa123') {
      return http.Response(
        jsonEncode({'pesan': 'Email atau kata sandi salah.'}),
        401,
      );
    }
    return http.Response(
      jsonEncode({
        'akun': {
          'id': 'uuid-1',
          'nama': 'Rani Amelia',
          'email': 'rani.amelia@gmail.com',
          'peran': 'pembeli',
        },
        'token': 'tok-1',
      }),
      200,
    );
  }
  if (jalur == '/v1/akun/saya') {
    if (token != 'Bearer tok-1') {
      return http.Response(jsonEncode({'pesan': 'Sesi berakhir.'}), 401);
    }
    return http.Response(
      jsonEncode({
        'akun': {
          'id': 'uuid-1',
          'nama': 'Rani Amelia',
          'email': 'rani.amelia@gmail.com',
          'peran': 'pembeli',
        },
      }),
      200,
    );
  }
  if (jalur == '/v1/akun/keluar') return http.Response('', 204);
  return http.Response('', 404);
});

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  const alamat = 'http://server.tes';

  test('masuk: jawaban server jadi map akun + token', () async {
    final api = AkunApi(alamat: alamat, klien: serverPalsu());
    final akun = await api.masuk('rani.amelia@gmail.com', 'sisarasa123');
    expect(akun['id'], 'uuid-1');
    expect(akun['peran'], 'pembeli');
    expect(akun['token'], 'tok-1');
  });

  test('galat dari server dan galat jaringan jadi GagalAkun', () async {
    final api = AkunApi(alamat: alamat, klien: serverPalsu());
    await expectLater(
      api.masuk('rani.amelia@gmail.com', 'salah'),
      throwsA(
        isA<GagalAkun>().having(
          (g) => g.pesan,
          'pesan',
          'Email atau kata sandi salah.',
        ),
      ),
    );

    final mati = AkunApi(alamat: alamat, klien: serverPalsu(mati: true));
    await expectLater(
      mati.masuk('rani.amelia@gmail.com', 'sisarasa123'),
      throwsA(
        isA<GagalAkun>().having(
          (g) => g.pesan,
          'pesan',
          contains('Tidak bisa terhubung'),
        ),
      ),
    );
  });

  test('sesi: token ga berlaku = null, bukan galat', () async {
    final api = AkunApi(alamat: alamat, klien: serverPalsu());
    expect((await api.sesi('tok-1'))!['nama'], 'Rani Amelia');
    expect(await api.sesi('tok-ngasal'), isNull);
  });

  test(
    'server mati pas aplikasi dibuka: ga crash, token tetep disimpen',
    () async {
      FlutterSecureStorage.setMockInitialValues({'token_sesi': 'tok-1'});
      final cubit = AkunCubit(
        layanan: AkunApi(alamat: alamat, klien: serverPalsu(mati: true)),
      );
      await cubit.pulihkan();
      expect(cubit.state, isEmpty);
      expect(await cubit.penyimpanan.read(key: 'token_sesi'), 'tok-1');

      // server nyala lagi: sesi lanjut
      final lagi = AkunCubit(
        layanan: AkunApi(alamat: alamat, klien: serverPalsu()),
      );
      await lagi.pulihkan();
      expect(lagi.state['id'], 'uuid-1');
    },
  );
}
