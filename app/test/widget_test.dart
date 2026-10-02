import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sisa_rasa/main.dart';
import 'package:sisa_rasa/widgets/navigasi_melayang.dart';

void main() {
  setUp(() {});

  testWidgets('beranda nampilin judul, kelompok jam, dan navigasi melayang', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const SisaRasaApp());

    expect(find.text('Sore ini'), findsOneWidget);
    expect(find.text('Sekarang'), findsOneWidget);
    expect(find.byType(NavigasiMelayang), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('pindah tab lewat navigasi melayang', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const SisaRasaApp());

    await tester.tap(find.text('Pesanan').last);
    await tester.pumpAndSettle();
    expect(find.text('Belum ada pesanan aktif'), findsOneWidget);

    await tester.tap(find.text('Akun').last);
    await tester.pumpAndSettle();
    expect(find.text('Rani Amelia'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('detail, tambah, keranjang, pesan, sampai kode ambil', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const SisaRasaApp());

    // Navigator.push ke detail
    await tester.tap(find.text('Sandwich Sisa Brunch'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah · Rp14.000'), findsOneWidget);

    // kolom jumlah hanya menerima angka dan dibatasi sisa porsi (3)
    await tester.enterText(find.byType(TextField), '9a');
    await tester.pump();
    expect(find.text('Tambah · Rp42.000'), findsOneWidget);

    // tambah lalu Navigator.pop kembali ke beranda, bar keranjang muncul
    await tester.tap(find.text('Tambah · Rp42.000'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('3 porsi · Ibis Hotel'), findsOneWidget);

    // buka keranjang lalu pesan
    await tester.tap(find.text('3 porsi · Ibis Hotel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pesan · Rp42.000'));
    await tester.pumpAndSettle();
    expect(find.text('Pesanan dibuat'), findsOneWidget);
    expect(find.textContaining('SR-'), findsOneWidget);

    // kembali, otomatis pindah ke tab Pesanan
    await tester.ensureVisible(find.text('Lihat pesanan saya'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lihat pesanan saya'));
    await tester.pumpAndSettle();
    expect(find.text('Aktif · 1'), findsOneWidget);

    // stok dikurangin lewat PaketCubit: sandwich tinggal 0, beranda nampilin Habis
    await tester.tap(find.text('Beranda').last);
    await tester.pumpAndSettle();
    expect(find.text('Habis'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });
}
