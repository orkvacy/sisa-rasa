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

/// angka di samping segmen "Berlangsung" tab pesanan
String jumlahBerlangsung(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('jumlah-berlangsung'))).data!;

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

    // cek status -> lunas -> detail pesanan, tahap Disiapkan
    await tester.tap(find.text('Saya sudah bayar · cek status'));
    await lewati(tester);
    await lewati(tester);
    expect(find.text('Pembayaran berhasil'), findsOneWidget);
    expect(find.text('Pesananmu sedang disiapkan'), findsOneWidget);
    expect(find.textContaining('SR-'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Lunas'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Virtual Account BCA'), findsOneWidget);

    // detail nempel di tab pesanan, jadi kembali ke daftar pesanan
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    expect(jumlahBerlangsung(tester), '1');
    expect(find.text('Tampilkan QR'), findsOneWidget);
    expect(find.text('Disiapkan'), findsOneWidget);

    // stok yg udah dibayar ga balik: sandwich tinggal 0, beranda nampilin Habis
    await tester.tap(find.text('Beranda').last);
    await tester.pumpAndSettle();
    expect(find.text('Habis'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('ganti akun cepat, pesanan akun lain ga ikut keliatan', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const SisaRasaApp());

    // Rani bikin pesanan (belum dibayar)
    await keCheckout(tester);
    await tester.tap(find.text('Bayar · Rp15.400'));
    await lewati(tester);
    await tester.tap(find.byTooltip('Back'));
    await lewati(tester);
    expect(jumlahBerlangsung(tester), '1');

    // pindah ke Dimas lewat tombol mode uji di tab akun
    await tester.tap(find.text('Akun').last);
    await lewati(tester);
    await tester.tap(find.text('Ganti akun'));
    await lewati(tester);
    // akun mitra udah ada tapi halamannya belum, jadi masih dikunci
    expect(find.textContaining('halamannya belum ada'), findsOneWidget);
    await tester.tap(find.text('Dimas Pratama'));
    await lewati(tester);
    expect(find.text('Dimas Pratama'), findsOneWidget);
    expect(find.text('DP'), findsOneWidget);

    await tester.tap(find.text('Pesanan').last);
    await lewati(tester);
    expect(jumlahBerlangsung(tester), '0');
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
    expect(jumlahBerlangsung(tester), '0');
    await tester.tap(find.text('Dibatalkan').last);
    await tester.pumpAndSettle();
    expect(find.text('Hari ini'), findsOneWidget);
    expect(
      find.text(
        'Kamu membatalkan sebelum membayar. Tidak ada dana yang terpotong.',
      ),
      findsOneWidget,
    );
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('halaman mitra: ambil beberapa paket dari mitra yg sama (F-54)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const SisaRasaApp());

    // dari detail sandwich buka halaman Ibis Hotel
    await tester.tap(find.text('Sandwich Sisa Brunch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lihat mitra'));
    await tester.pumpAndSettle();
    expect(find.text('Paket hari ini'), findsOneWidget);
    expect(find.text('2 paket'), findsOneWidget);
    expect(find.text('Petunjuk arah'), findsOneWidget);
    expect(find.text('Halal bersertifikat'), findsOneWidget);

    // tambah dua paket beda, bar keranjang ngitung keduanya
    await tester.tap(find.byTooltip('Tambah Sandwich Sisa Brunch'));
    await tester.pump();
    await tester.tap(find.byTooltip('Tambah Kue Sisa Coffee Break'));
    await tester.pump();
    await tester.tap(find.byTooltip('Tambah porsi').last);
    await tester.pump();
    expect(find.text('3 porsi'), findsOneWidget);
    expect(find.text('Rp38.000'), findsOneWidget);

    // minus di jumlah 1 = keluarin dari keranjang
    await tester.tap(find.byTooltip('Hapus dari keranjang'));
    await tester.pump();
    expect(find.text('2 porsi'), findsOneWidget);
    expect(find.text('Rp24.000'), findsWidgets);
    expect(find.byTooltip('Tambah Sandwich Sisa Brunch'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('tambah cepat dari mitra lain nanya dulu (F-07)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const SisaRasaApp());

    // keranjang isi sandwich Ibis Hotel dulu
    await keCheckout(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // tombol + paket Warung Blok M di beranda
    final tambah = find.byTooltip('Tambah Paket Ayam Goreng');
    await tester.scrollUntilVisible(
      tambah,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(tambah);
    await tester.pumpAndSettle();
    expect(find.text('Ganti isi keranjang?'), findsOneWidget);

    // batal: keranjang tetap isi sandwich
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Rp14.000'), findsWidgets);

    // setuju: keranjang diganti paket ayam
    await tester.tap(tambah);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kosongkan & tambah'));
    await tester.pumpAndSettle();
    expect(find.text('Paket Ayam Goreng masuk keranjang'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('pesanan sampai selesai: siap diambil, kode QR, diambil (F-41)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const SisaRasaApp());

    await keCheckout(tester);
    await tester.tap(find.text('Bayar · Rp15.400'));
    await lewati(tester);
    await tester.tap(find.text('Saya sudah bayar · cek status'));
    await lewati(tester);
    await lewati(tester);
    expect(find.text('Pesananmu sedang disiapkan'), findsOneWidget);

    // mode uji gantiin aplikasi mitra: tandai siap diambil (F-43)
    await tester.tap(find.text('Mode uji: tandai siap diambil'));
    await tester.pumpAndSettle();
    expect(find.text('Pesananmu siap diambil!'), findsOneWidget);

    // kode QR layar penuh, tunggu snackbar "Pembayaran berhasil" ilang dulu
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tampilkan QR'));
    await tester.pumpAndSettle();
    expect(find.text('Tunjukkan ke kasir Ibis Hotel'), findsOneWidget);
    expect(find.text('1× Sandwich Sisa'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Selesai'));
    await tester.pumpAndSettle();
    expect(find.text('Pesananmu siap diambil!'), findsOneWidget);

    // mitra mindai kodenya: pesanan selesai (F-20)
    await tester.tap(find.text('Mode uji: tandai sudah diambil'));
    await tester.pumpAndSettle();
    expect(find.text('Pesanan sudah diambil'), findsOneWidget);

    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    expect(jumlahBerlangsung(tester), '0');
    await tester.tap(find.text('Selesai').last);
    await tester.pumpAndSettle();
    expect(find.text('Hari ini'), findsOneWidget);
    expect(find.text('1 porsi terselamatkan'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });
}
