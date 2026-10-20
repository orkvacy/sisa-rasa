import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sisa_rasa/data/repositories/akun_api.dart';
import 'package:sisa_rasa/injection.dart';
import 'package:sisa_rasa/main.dart';
import 'package:sisa_rasa/presentation/cubit/akun_cubit.dart';

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({'token_sesi': 'tok-1'});
    await sl.reset();
    daftarkanDependensi();
  });

  testWidgets('dibuka tanpa internet: layar tanpa koneksi, coba lagi lanjut', (
    tester,
  ) async {
    var nyala = false;
    final akun = AkunCubit(
      layanan: AkunApi(
        alamat: 'https://api.tes',
        klien: MockClient((req) async {
          if (!nyala) throw http.ClientException('ga ada internet');
          return http.Response(
            jsonEncode({
              'akun': {
                'id': 'u1',
                'nama': 'Rani Amelia',
                'email': 'rani.amelia@gmail.com',
                'peran': 'pembeli',
                'punyaSandi': true,
              },
            }),
            200,
          );
        }),
      ),
    );
    await tester.runAsync(akun.pulihkan);
    expect(akun.luring, isTrue);

    await tester.pumpWidget(SisaRasaApp(akun: akun));
    await tester.pumpAndSettle();
    // bukan layar masuk / sambutan
    expect(find.text('Tidak ada koneksi'), findsOneWidget);
    expect(find.text('Buat akun'), findsNothing);

    // masih mati: tetap di sini
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('coba-lagi')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada koneksi'), findsOneWidget);

    nyala = true;
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('coba-lagi')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(akun.state['nama'], 'Rani Amelia');
    expect(find.text('Tidak ada koneksi'), findsNothing);
  });
}
