import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisa_rasa/cubit/akun_cubit.dart';
import 'package:sisa_rasa/data/dummy_akun.dart';
import 'package:sisa_rasa/data/layanan_akun.dart';
import 'package:sisa_rasa/main.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<void> buka(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const SisaRasaApp());
    await tester.pumpAndSettle();
  }

  /// isi kolom ke-[i] di layar yg lagi kebuka
  Future<void> isi(WidgetTester tester, int i, String teks) =>
      tester.enterText(find.byType(TextField).at(i), teks);

  group('layanan dan sesi', () {
    test('pesan gagal sama buat email ga terdaftar dan sandi salah', () async {
      final layanan = AkunTiruan();
      Future<String> gagal(String email, String sandi) async {
        try {
          await layanan.masuk(email, sandi);
          return 'berhasil';
        } on GagalAkun catch (e) {
          return e.pesan;
        }
      }

      expect(
        await gagal('ga.ada@contoh.id', sandiUji),
        await gagal('rani.amelia@gmail.com', 'salah123'),
      );
    });

    test(
      'sesi lanjut abis aplikasi dibuka ulang, keluar nyabut token (F-33)',
      () async {
        final layanan = AkunTiruan();
        final pertama = AkunCubit(layanan: layanan);
        await pertama.masuk(' Rani.Amelia@gmail.com ', sandiUji);
        expect(pertama.state['id'], 'u1');
        final token = pertama.state['token']!;

        // aplikasi dibuka ulang: cubit baru, baca token dari secure storage
        final kedua = AkunCubit(layanan: layanan);
        await kedua.pulihkan();
        expect(kedua.state['id'], 'u1');

        await kedua.keluar();
        expect(kedua.state, isEmpty);
        expect(await layanan.sesi(token), isNull);

        final ketiga = AkunCubit(layanan: layanan);
        await ketiga.pulihkan();
        expect(ketiga.state, isEmpty);
      },
    );
  });

  testWidgets('masuk: salah sandi, berhasil, terus keluar (F-30, F-33)', (
    tester,
  ) async {
    await buka(tester);
    expect(find.text('Lihat paket dulu'), findsOneWidget);

    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    await isi(tester, 0, 'rani.amelia@gmail.com');
    await isi(tester, 1, 'salah123');
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Email atau kata sandi salah'), findsOneWidget);

    await isi(tester, 1, sandiUji);
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pumpAndSettle();
    expect(find.text('Flash sale'), findsOneWidget);

    await tester.tap(find.text('Akun').last);
    await tester.pumpAndSettle();
    expect(find.text('Rani Amelia'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Keluar'), 200);
    // digeser lagi biar ga ketutup navigasi melayang
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    expect(find.text('Keluar dari akun?'), findsOneWidget);
    await tester.tap(find.text('Keluar').last);
    await tester.pumpAndSettle();
    expect(find.text('Lihat paket dulu'), findsOneWidget);
  });

  testWidgets(
    'tamu lihat paket, buka Pesanan diminta daftar dulu (F-29, F-65)',
    (tester) async {
      await buka(tester);
      await tester.ensureVisible(find.text('Lihat paket dulu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lihat paket dulu'));
      await tester.pumpAndSettle();
      expect(find.text('Flash sale'), findsOneWidget);

      await tester.tap(find.text('Pesanan').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Masuk dulu untuk lanjut'), findsOneWidget);

      await tester.tap(find.text('Daftar'));
      await tester.pumpAndSettle();
      // dari halaman pembeli, pilihan peran ga ditampilin
      expect(find.text('Mitra usaha'), findsNothing);
      await isi(tester, 0, 'Budi Santoso');
      await isi(tester, 1, 'budi@contoh.id');
      await isi(tester, 2, 'rahasia1');
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Buat akun'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Buat akun'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Setujui Ketentuan'), findsOneWidget);

      await tester.tap(find.byType(Checkbox));
      await tester.tap(find.widgetWithText(FilledButton, 'Buat akun'));
      await tester.pumpAndSettle();
      // abis daftar langsung dibalikin ke tab Pesanan yg tadi dituju
      expect(find.byKey(const Key('jumlah-berlangsung')), findsOneWidget);
    },
  );

  testWidgets('daftar sebagai mitra langsung ke dasbor, sandi pendek ditolak', (
    tester,
  ) async {
    await buka(tester);
    await tester.tap(find.text('Buat akun'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mitra usaha'));
    await tester.pump();
    expect(find.text('Nama usaha'), findsOneWidget);

    await isi(tester, 0, 'Roti Pagi Bakery');
    await isi(tester, 1, 'roti.pagi@contoh.id');
    await isi(tester, 2, 'pendek');
    await tester.pump();
    expect(find.textContaining('Sisa 2 lagi'), findsOneWidget);
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.widgetWithText(FilledButton, 'Buat akun'));
    await tester.pumpAndSettle();
    expect(find.text('Minimal 8 karakter.'), findsOneWidget);

    await isi(tester, 2, 'pendek123');
    await tester.tap(find.widgetWithText(FilledButton, 'Buat akun'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Roti Pagi Bakery'), findsWidgets);
    expect(find.text('Dasbor'), findsOneWidget);

    // keluar dari halaman akun yg dibuka lewat avatar dasbor
    await tester.tap(find.byKey(const Key('akun-mitra')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Keluar'), 200);
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar').last);
    await tester.pumpAndSettle();
    expect(find.text('Lihat paket dulu'), findsOneWidget);
  });
}
