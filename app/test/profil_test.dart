import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisa_rasa/data/repositories/akun_tiruan.dart';
import 'package:sisa_rasa/data/sumber/dummy_akun.dart';
import 'package:sisa_rasa/domain/repositories/layanan_akun.dart';
import 'package:sisa_rasa/injection.dart';
import 'package:sisa_rasa/main.dart';
import 'package:sisa_rasa/presentation/cubit/akun_cubit.dart';

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await sl.reset();
    daftarkanDependensi();
  });

  test('ubah nama dan hapus akun di layanan tiruan (F-62, F-63)', () async {
    final layanan = AkunTiruan();
    final rani = await layanan.masuk('rani.amelia@gmail.com', sandiUji);
    final token = rani['token']!;

    final baru = await layanan.ubahNama(token, '  Rani   Putri ');
    expect(baru['nama'], 'Rani Putri');
    expect(baru.containsKey('sandi'), isFalse);
    expect(() => layanan.ubahNama(token, 'R'), throwsA(isA<GagalAkun>()));

    final mitra = await layanan.masuk('dapur.ibis@contoh.id', sandiUji);
    expect(
      () => layanan.ubahNama(mitra['token']!, 'Ibis Baru'),
      throwsA(isA<GagalAkun>()),
    );
    expect(
      () => layanan.hapusAkun(mitra['token']!, sandiUji),
      throwsA(isA<GagalAkun>()),
    );

    expect(
      () => layanan.hapusAkun(token, 'salah'),
      throwsA(
        isA<GagalAkun>().having((g) => g.pesan, 'pesan', 'Kata sandi salah.'),
      ),
    );
    await layanan.hapusAkun(token, sandiUji);
    expect(await layanan.sesi(token), isNull);
    expect(
      () => layanan.masuk('rani.amelia@gmail.com', sandiUji),
      throwsA(isA<GagalAkun>()),
    );
  });

  testWidgets('tab akun: ganti nama lalu hapus akun balik ke sambutan', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final akun = AkunCubit(layanan: sl());
    await akun.masuk('rani.amelia@gmail.com', sandiUji);
    await tester.pumpWidget(SisaRasaApp(akun: akun));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Akun').last);
    await tester.pumpAndSettle();

    // F-63 ganti nama
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ubah-nama')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Rani Putri');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Rani Putri'), findsOneWidget);

    // F-62 sandi salah ditolak, lalu dihapus
    await tester.scrollUntilVisible(
      find.text('Hapus akun'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Hapus akun'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'salah');
    await tester.tap(find.widgetWithText(TextButton, 'Hapus akun'));
    await tester.pumpAndSettle();
    expect(find.text('Kata sandi salah.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), sandiUji);
    await tester.tap(find.widgetWithText(TextButton, 'Hapus akun'));
    await tester.pumpAndSettle();
    expect(akun.state, isEmpty);
    expect(find.text('Buat akun'), findsOneWidget);
  });
}
