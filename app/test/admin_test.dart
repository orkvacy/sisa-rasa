import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sisa_rasa/core/sesi_aktif.dart';
import 'package:sisa_rasa/data/repositories/admin_api.dart';
import 'package:sisa_rasa/data/sumber/dummy_akun.dart';
import 'package:sisa_rasa/data/sumber/klien_api.dart';
import 'package:sisa_rasa/injection.dart';
import 'package:sisa_rasa/main.dart';

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await sl.reset();
    daftarkanDependensi();
  });

  final admin = dummyAkun.firstWhere((a) => a['peran'] == 'admin');

  test('AdminApi kirim filter status dan isian periksa ke server', () async {
    final diminta = <http.Request>[];
    final api = AdminApi(
      KlienApi(
        alamat: 'https://api.tes',
        sesi: SesiAktif()..token = 'tok-admin',
        klien: MockClient((req) async {
          diminta.add(req);
          if (req.method == 'GET') {
            return http.Response(
              jsonEncode({
                'mitra': [
                  {'id': 'm9', 'nama': 'Dapur Baru', 'status': 'menunggu'},
                ],
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'status': 'ditolak'}), 200);
        }),
      ),
    );

    final daftar = await api.daftarMitra(status: 'menunggu');
    expect(daftar.single['nama'], 'Dapur Baru');
    expect(
      diminta.first.url.toString(),
      'https://api.tes/v1/admin/mitra?status=menunggu',
    );
    expect(diminta.first.headers['Authorization'], 'Bearer tok-admin');

    await api.periksa('m9', 'ditolak', alasan: 'Foto buram');
    expect(diminta.last.url.path, '/v1/admin/mitra/m9/periksa');
    expect(jsonDecode(diminta.last.body), {
      'status': 'ditolak',
      'alasan': 'Foto buram',
    });
  });

  testWidgets('admin masuk langsung ke verifikasi, tolak wajib pakai alasan', (
    tester,
  ) async {
    await tester.pumpWidget(SisaRasaApp(akunAwal: admin));
    await tester.pumpAndSettle();

    expect(find.text('Verifikasi mitra'), findsOneWidget);
    expect(find.text('Dapur Tepian'), findsOneWidget);
    // mitra contoh udah terverifikasi, ga muncul di tab Menunggu
    expect(find.text('Ibis Hotel'), findsNothing);

    await tester.tap(find.text('Tolak'));
    await tester.pumpAndSettle();
    final kirim = find.widgetWithText(TextButton, 'Kirim');
    expect(tester.widget<TextButton>(kirim).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('alasan')), 'NIB belum ada');
    await tester.pump();
    await tester.tap(kirim);
    await tester.pumpAndSettle();
    expect(find.text('Dapur Tepian'), findsNothing);

    await tester.tap(find.text('Ditolak').first);
    await tester.pumpAndSettle();
    expect(find.text('Alasan: NIB belum ada'), findsOneWidget);

    await tester.tap(find.text('Aktifkan lagi'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Setujui'));
    await tester.pumpAndSettle();
    expect(find.text('Dapur Tepian'), findsNothing);
    expect(find.text('Dapur Tepian sudah terverifikasi.'), findsOneWidget);
  });
}
