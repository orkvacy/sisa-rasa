import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sisa_rasa/data/repositories/akun_api.dart';
import 'package:sisa_rasa/data/repositories/akun_tiruan.dart';
import 'package:sisa_rasa/domain/repositories/layanan_akun.dart';
import 'package:sisa_rasa/domain/repositories/masuk_google.dart';
import 'package:sisa_rasa/injection.dart';
import 'package:sisa_rasa/main.dart';
import 'package:sisa_rasa/presentation/cubit/akun_cubit.dart';

/// jendela pilih akun Google pura-pura: [token] null = pengguna batal
class _GooglePalsu implements MasukGoogle {
  String? token = 'tok-budi';
  var keluarDipanggil = 0;

  @override
  bool get tersedia => true;

  @override
  Future<String?> ambilIdToken() async => token;

  @override
  Future<void> keluar() async => keluarDipanggil++;
}

/// server pura-pura yang nerima token Google 'tok-budi'
class _AkunDenganGoogle extends AkunTiruan {
  String? idTokenHapus;

  @override
  Future<Map<String, String>> masukGoogle(String idToken) async {
    if (idToken != 'tok-budi') {
      throw const GagalAkun('Masuk dengan Google gagal.');
    }
    return {
      'id': 'g1',
      'nama': 'Budi Santoso',
      'email': 'budi@gmail.com',
      'peran': 'pembeli',
      'punyaSandi': 'false',
      'token': 'sesi-budi',
    };
  }

  @override
  Future<Map<String, String>?> sesi(String token) async => null;

  @override
  Future<void> hapusAkun(
    String token,
    String sandi, {
    String idToken = '',
  }) async {
    idTokenHapus = idToken;
  }
}

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await sl.reset();
    daftarkanDependensi();
  });

  test('AkunApi kirim ID token Google, punyaSandi ikut kebaca', () async {
    late http.Request diminta;
    final api = AkunApi(
      alamat: 'https://api.tes',
      klien: MockClient((req) async {
        diminta = req;
        return http.Response(
          jsonEncode({
            'akun': {
              'id': 'g1',
              'nama': 'Budi',
              'email': 'budi@gmail.com',
              'peran': 'pembeli',
              'punyaSandi': false,
            },
            'token': 'sesi-1',
          }),
          200,
        );
      }),
    );
    final akun = await api.masukGoogle('tok-google');
    expect(diminta.url.path, '/v1/akun/google');
    expect(jsonDecode(diminta.body), {'idToken': 'tok-google'});
    expect(akun['punyaSandi'], 'false');
    expect(akun['token'], 'sesi-1');
  });

  test('tanpa Google diatur, tombolnya disembunyikan', () {
    expect(AkunCubit(layanan: AkunTiruan()).bisaGoogle, isFalse);
  });

  testWidgets(
    'lanjut dengan Google dari sambutan, hapus akun konfirmasi Google',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final google = _GooglePalsu();
      final layanan = _AkunDenganGoogle();
      final akun = AkunCubit(layanan: layanan, google: google);
      await tester.pumpWidget(SisaRasaApp(akun: akun));
      await tester.pumpAndSettle();

      // batal milih akun: tetap di sambutan
      google.token = null;
      await tester.ensureVisible(find.byKey(const Key('masuk-google')));
      await tester.tap(find.byKey(const Key('masuk-google')));
      await tester.pumpAndSettle();
      expect(find.text('Buat akun'), findsOneWidget);

      google.token = 'tok-budi';
      await tester.ensureVisible(find.byKey(const Key('masuk-google')));
      await tester.tap(find.byKey(const Key('masuk-google')));
      await tester.pumpAndSettle();
      expect(akun.state['nama'], 'Budi Santoso');
      expect(akun.tanpaSandi, isTrue);
      expect(find.text('Buat akun'), findsNothing);

      await tester.tap(find.text('Akun').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Hapus akun'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Hapus akun'));
      await tester.pumpAndSettle();
      // akun Google ga punya sandi, jadi ga ada kolom sandi
      expect(find.byType(TextField), findsNothing);
      await tester.tap(
        find.widgetWithText(TextButton, 'Konfirmasi dengan Google'),
      );
      await tester.pumpAndSettle();
      expect(layanan.idTokenHapus, 'tok-budi');
      expect(akun.state, isEmpty);
      expect(google.keluarDipanggil, greaterThan(0));
      expect(find.text('Buat akun'), findsOneWidget);
    },
  );
}
