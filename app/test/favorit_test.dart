import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sisa_rasa/core/sesi_aktif.dart';
import 'package:sisa_rasa/data/repositories/favorit_api.dart';
import 'package:sisa_rasa/data/sumber/dummy_akun.dart';
import 'package:sisa_rasa/data/sumber/klien_api.dart';
import 'package:sisa_rasa/domain/repositories/layanan_favorit.dart';
import 'package:sisa_rasa/domain/repositories/layanan_pesanan.dart';
import 'package:sisa_rasa/injection.dart';
import 'package:sisa_rasa/main.dart';
import 'package:sisa_rasa/presentation/cubit/favorit_cubit.dart';

/// server yang selalu nolak
class _FavoritGagal implements LayananFavorit {
  @override
  Future<List<Map<String, dynamic>>> semua() async => [];

  @override
  Future<void> atur(String idMitra, {required bool suka}) async =>
      throw const GagalLayanan('Tidak bisa terhubung.');
}

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await sl.reset();
    daftarkanDependensi();
  });

  test('FavoritApi: daftar, simpan (PUT), lepas (DELETE)', () async {
    final diminta = <http.Request>[];
    final api = FavoritApi(
      KlienApi(
        alamat: 'https://api.tes',
        sesi: SesiAktif()..token = 'tok-1',
        klien: MockClient((req) async {
          diminta.add(req);
          if (req.method == 'GET') {
            return http.Response(
              jsonEncode({
                'mitra': [
                  {'id': 'm1', 'nama': 'Ibis Hotel', 'jenis': 'Hotel'},
                ],
              }),
              200,
            );
          }
          return http.Response('', 204);
        }),
      ),
    );
    expect((await api.semua()).single['nama'], 'Ibis Hotel');
    await api.atur('m1', suka: true);
    await api.atur('m1', suka: false);
    expect(
      [for (final r in diminta) '${r.method} ${r.url.path}'],
      ['GET /v1/favorit', 'PUT /v1/favorit/m1', 'DELETE /v1/favorit/m1'],
    );
  });

  test('server nolak: hati balik lagi, galat ke snackbar', () async {
    final cubit = FavoritCubit(layanan: _FavoritGagal());
    final galat = <String>[];
    final dengar = cubit.galat.listen(galat.add);
    await cubit.ganti({'idMitra': 'm1', 'mitra': 'Ibis Hotel'});
    await Future<void>.delayed(Duration.zero);
    expect(cubit.suka('m1'), isFalse);
    expect(galat, ['Tidak bisa terhubung.']);
    await dengar.cancel();
    await cubit.close();
  });

  testWidgets('simpan mitra dari halaman mitra, muncul di Mitra favorit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SisaRasaApp(akunAwal: dummyAkun.first));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ibis Hotel').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Simpan mitra'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Hapus dari favorit'), findsOneWidget);

    // dari tab Akun -> Mitra favorit
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akun').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Mitra favorit'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Mitra favorit'));
    await tester.pumpAndSettle();
    expect(find.text('Ibis Hotel'), findsOneWidget);
    expect(find.textContaining('mulai Rp'), findsOneWidget);

    // lepas dari daftar
    await tester.tap(find.byTooltip('Hapus Ibis Hotel dari favorit'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada mitra favorit'), findsOneWidget);
  });

  testWidgets('tamu ketuk hati diminta masuk dulu', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const SisaRasaApp(akunAwal: {'peran': 'tamu'}));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ibis Hotel').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Simpan mitra'));
    await tester.pumpAndSettle();
    expect(
      find.text('Masuk dulu untuk lanjut. Isi keranjangmu tetap tersimpan.'),
      findsOneWidget,
    );
  });
}
