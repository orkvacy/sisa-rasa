import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisa_rasa/data/sumber/dummy_akun.dart';
import 'package:sisa_rasa/domain/repositories/layanan_akun.dart';
import 'package:sisa_rasa/injection.dart';
import 'package:sisa_rasa/main.dart';
import 'package:sisa_rasa/data/repositories/akun_tiruan.dart';
import 'package:sisa_rasa/domain/aturan/akun.dart';

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await sl.reset();
    daftarkanDependensi();
  });

  const rani = 'rani.amelia@gmail.com';

  group('kode OTP atur ulang (F-61)', () {
    late DateTime sekarang;
    late AkunTiruan layanan;

    setUp(() {
      sekarang = DateTime(2026, 10, 14, 16);
      layanan = AkunTiruan(jam: () => sekarang);
    });

    Future<String?> galat(Future<void> Function() aksi) async {
      try {
        await aksi();
        return null;
      } on GagalAkun catch (e) {
        return e.pesan;
      }
    }

    test(
      'email ga terdaftar tetep "berhasil", ga ada kode yg dibuat',
      () async {
        await layanan.mintaKodeReset('ga.ada@contoh.id');
        expect(layanan.kodeUji('ga.ada@contoh.id'), isNull);
      },
    );

    test('minta ulang harus nunggu 60 detik', () async {
      await layanan.mintaKodeReset(rani);
      expect(
        await galat(() => layanan.mintaKodeReset(rani)),
        contains('Tunggu'),
      );
      sekarang = sekarang.add(jedaKirimUlang);
      expect(await galat(() => layanan.mintaKodeReset(rani)), isNull);
    });

    test('kode kedaluwarsa setelah 10 menit', () async {
      await layanan.mintaKodeReset(rani);
      final kode = layanan.kodeUji(rani)!;
      sekarang = sekarang.add(berlakuKodeReset);
      expect(
        await galat(() => layanan.cekKodeReset(rani, kode)),
        'Kode salah atau sudah kedaluwarsa.',
      );
    });

    test('kode cuma sekali pakai, salah 5x langsung hangus', () async {
      await layanan.mintaKodeReset(rani);
      final kode = layanan.kodeUji(rani)!;
      await layanan.cekKodeReset(rani, kode);
      expect(await galat(() => layanan.cekKodeReset(rani, kode)), isNotNull);

      sekarang = sekarang.add(jedaKirimUlang);
      await layanan.mintaKodeReset(rani);
      final baru = layanan.kodeUji(rani)!;
      for (var i = 0; i < batasSalahKode - 1; i++) {
        await galat(() => layanan.cekKodeReset(rani, '000000'));
      }
      expect(
        await galat(() => layanan.cekKodeReset(rani, '000000')),
        contains('Terlalu banyak'),
      );
      // kode yg bener pun udah ga bisa dipake
      expect(await galat(() => layanan.cekKodeReset(rani, baru)), isNotNull);
    });

    test('sandi baru berlaku, sandi lama + sesi lama dicabut', () async {
      final lama = await layanan.masuk(rani, sandiUji);
      await layanan.mintaKodeReset(rani);
      final tiket = await layanan.cekKodeReset(rani, layanan.kodeUji(rani)!);
      await layanan.aturSandiBaru(tiket, 'sandibaru123');

      expect(await layanan.sesi(lama['token']!), isNull);
      expect(await galat(() => layanan.masuk(rani, sandiUji)), isNotNull);
      final baru = await layanan.masuk(rani, 'sandibaru123');
      expect(await layanan.sesi(baru['token']!), isNotNull);
      // tiket sekali pakai
      expect(
        await galat(() => layanan.aturSandiBaru(tiket, 'lagi12345')),
        isNotNull,
      );
    });

    test('email disamarkan di layar kode', () {
      expect(samarkanEmail('Rani.Amelia@gmail.com'), 'rani•••@gmail.com');
    });
  });

  testWidgets('lupa sandi dari layar Masuk sampai masuk pakai sandi baru', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const SisaRasaApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, rani);
    await tester.tap(find.text('Lupa kata sandi?'));
    await tester.pumpAndSettle();

    // email dari layar Masuk udah keisi
    expect(find.text('Atur ulang kata sandi'), findsOneWidget);
    expect(find.text(rani), findsOneWidget);
    await tester.tap(find.text('Kirim kode'));
    await tester.pumpAndSettle();
    expect(find.textContaining('rani•••@gmail.com'), findsOneWidget);
    expect(find.textContaining('Kirim ulang dalam'), findsOneWidget);

    // kode salah dulu
    await tester.enterText(find.byKey(const Key('kolom-kode')), '000000');
    await tester.pumpAndSettle();
    expect(find.text('Kode salah atau sudah kedaluwarsa.'), findsOneWidget);

    // kode yg bener diambil dari kotak mode uji, verifikasi jalan sendiri pas 6 digit
    final kode = tester
        .widget<Text>(find.byKey(const Key('kode-uji')))
        .data!
        .split(' ')
        .last;
    await tester.enterText(find.byKey(const Key('kolom-kode')), kode);
    await tester.pumpAndSettle();
    expect(find.text('Buat kata sandi baru'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'sandibaru123');
    await tester.enterText(find.byType(TextField).at(1), 'sandibaru12');
    await tester.tap(find.text('Simpan kata sandi'));
    await tester.pumpAndSettle();
    expect(find.text('Belum sama dengan kata sandi baru.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'sandibaru123');
    await tester.tap(find.text('Simpan kata sandi'));
    await tester.pumpAndSettle();

    // balik ke Masuk, email udah keisi, masuk pake sandi baru
    expect(find.textContaining('Kata sandi diganti'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), 'sandibaru123');
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pumpAndSettle();
    expect(find.text('Flash sale'), findsOneWidget);
  });
}
