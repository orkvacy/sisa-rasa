import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sisa_rasa/cubit/paket_cubit.dart';
import 'package:sisa_rasa/main.dart';
import 'package:sisa_rasa/screens/halaman_utama.dart';
import 'package:sisa_rasa/widgets/navigasi_melayang.dart';

/// hitung mundur batas bayar jalan tiap detik, jadi selama layarnya kebuka
/// pumpAndSettle ga akan pernah "tenang". di bagian itu pake pump biasa
Future<void> lewati(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

int sisaPorsi(WidgetTester tester, String id) {
  // skipOffstage false: halaman utama tetep ada di bawah layar penuh (pembayaran dll)
  final context = tester.element(
    find.byType(HalamanUtama, skipOffstage: false),
  );
  return context.read<PaketCubit>().cari(id)['sisaPorsi'];
}

/// dari beranda sampe checkout, dengan [jumlah] porsi sandwich (id p1)
Future<void> keCheckout(WidgetTester tester, {String jumlah = '1'}) async {
  await tester.tap(find.text('Sandwich Sisa Brunch'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), jumlah);
  await tester.pump();
  await tester.tap(find.textContaining('Tambah · '));
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
  await tester.tap(find.text('$jumlah porsi'));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('Lanjut ke checkout'));
  await tester.pumpAndSettle();
}

void main() {
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
    expect(find.text('Belum ada pesanan berlangsung'), findsOneWidget);

    await tester.tap(find.text('Akun').last);
    await tester.pumpAndSettle();
    expect(find.text('Rani Amelia'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('detail, keranjang, checkout, bayar VA, sampai kode ambil', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const SisaRasaApp());

    // kolom jumlah hanya menerima angka dan dibatasi sisa porsi (3)
    await tester.tap(find.text('Sandwich Sisa Brunch'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '9a');
    await tester.pump();
    expect(find.text('Tambah · Rp42.000'), findsOneWidget);
    await tester.tap(find.text('Tambah · Rp42.000'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // keranjang -> checkout, total checkout ditambah biaya layanan 10%
    await tester.tap(find.text('3 porsi'));
    await tester.pumpAndSettle();
    expect(find.text('Bayar di tempat'), findsNothing);
    await tester.tap(find.text('Lanjut ke checkout · Rp42.000'));
    await tester.pumpAndSettle();
    expect(find.text('Rp4.200'), findsOneWidget);
    expect(find.text('Bayar · Rp46.200'), findsOneWidget);

    // pilih VA, terus pastiin aturan "tidak diambil" (F-56) keliatan sebelum bayar
    await tester.tap(find.text('Virtual Account BCA'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.textContaining('dananya tidak dikembalikan'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('dananya tidak dikembalikan'), findsOneWidget);

    // bayar, porsinya langsung ditahan
    await tester.tap(find.text('Bayar · Rp46.200'));
    await lewati(tester);
    expect(find.text('Salin nomor'), findsOneWidget);
    // keterangan mode uji ada di paling bawah, digulir dulu
    await tester.scrollUntilVisible(
      find.textContaining('Mode uji'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('Mode uji'), findsOneWidget);
    expect(sisaPorsi(tester, 'p1'), 0);

    // cek status -> lunas -> kode ambil
    await tester.tap(find.text('Saya sudah bayar · cek status'));
    await lewati(tester);
    await lewati(tester);
    expect(find.text('Pembayaran berhasil'), findsOneWidget);
    expect(find.text('Dibayar · Virtual Account BCA'), findsOneWidget);
    expect(find.textContaining('SR-'), findsWidgets);

    // kode ambil nempel di tab pesanan, jadi balik ke sana
    await tester.ensureVisible(find.text('Lihat pesanan saya'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lihat pesanan saya'));
    await tester.pumpAndSettle();
    expect(find.text('Berlangsung · 1'), findsOneWidget);
    expect(find.text('Tampilkan kode'), findsOneWidget);
    expect(find.text('Disiapkan'), findsWidgets);

    // stok yg udah dibayar ga balik: sandwich tinggal 0, beranda nampilin Habis
    await tester.tap(find.text('Beranda').last);
    await tester.pumpAndSettle();
    expect(find.text('Habis'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('batalin sebelum bayar, porsi balik ke stok', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const SisaRasaApp());

    await keCheckout(tester);
    await tester.tap(find.text('Bayar · Rp15.400'));
    await lewati(tester);
    expect(find.text('Bayar dengan QRIS'), findsOneWidget);
    expect(sisaPorsi(tester, 'p1'), 2);

    // F-55: batalin lewat dialog konfirmasi
    await tester.tap(find.text('Batalkan pesanan'));
    await lewati(tester);
    await tester.tap(find.text('Batalkan'));
    await lewati(tester);
    await tester.pumpAndSettle();

    expect(sisaPorsi(tester, 'p1'), 3);
    expect(find.text('Berlangsung · 0'), findsOneWidget);
    await tester.tap(find.text('Dibatalkan').last);
    await tester.pumpAndSettle();
    expect(find.text('Kamu membatalkan sebelum membayar.'), findsOneWidget);
    expect(find.text('Belum ada dana yang ditarik.'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });
}
