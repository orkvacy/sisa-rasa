import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sisa_rasa/presentation/cubit/paket_cubit.dart';
import 'package:sisa_rasa/data/sumber/dummy_akun.dart';
import 'package:sisa_rasa/injection.dart';
import 'package:sisa_rasa/main.dart';
import 'package:sisa_rasa/presentation/screens/halaman_utama.dart';
import 'package:sisa_rasa/presentation/widgets/navigasi_bawah.dart';

/// hitung mundur batas bayar jalan tiap detik, jadi selama layarnya kebuka
/// pumpAndSettle ga akan pernah "tenang". di bagian itu pake pump biasa
Future<void> lewati(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// angka di samping segmen "Berlangsung" tab pesanan
String jumlahBerlangsung(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('jumlah-berlangsung'))).data!;

/// buka halaman akun (tab Akun pembeli / avatar dasbor mitra), terus ganti akun
Future<void> gantiAkun(WidgetTester tester, String nama) async {
  // di aplikasi mitra, halaman akun dibuka dari avatar di Dasbor
  if (find.text('Dasbor').evaluate().isNotEmpty) {
    await tester.tap(find.text('Dasbor').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('akun-mitra')));
  } else {
    await tester.tap(find.text('Akun').last);
  }
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ganti akun'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(nama).last);
  await tester.pumpAndSettle();
}

int sisaPorsi(WidgetTester tester, String id) {
  // skipOffstage false: halaman utama tetep ada di bawah layar penuh (pembayaran dll)
  final context = tester.element(
    find.byType(HalamanUtama, skipOffstage: false),
  );
  return context.read<PaketCubit>().cari(id)['sisaPorsi'];
}

/// beranda -> kartu Ibis Hotel di Flash sale -> halaman mitranya
Future<void> bukaIbis(WidgetTester tester) async {
  await tester.tap(find.text('Ibis Hotel'));
  await tester.pumpAndSettle();
}

/// beranda -> halaman Ibis Hotel -> detail american breakfast (id p1)
Future<void> keDetailSandwich(WidgetTester tester) async {
  await bukaIbis(tester);
  await tester.tap(find.text('American Breakfast Set'));
  await tester.pumpAndSettle();
}

/// dari beranda sampe checkout, dengan [jumlah] porsi sandwich (id p1)
Future<void> keCheckout(WidgetTester tester, {String jumlah = '1'}) async {
  await keDetailSandwich(tester);
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
  // secure storage di tes pake penyimpanan tiruan, isinya kosong tiap tes
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await sl.reset();
    daftarkanDependensi();
  });

  tesKelolaPaket();
  testWidgets('beranda: flash sale, mitra sekitar, navigasi bawah', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(SisaRasaApp(akunAwal: dummyAkun.first));
    // paket dimuat async dari repository, tunggu satu frame
    await tester.pump();

    expect(find.text('Sore ini'), findsOneWidget);
    // Ibis + Prime Cut tutup 17.00, kurang dari sejam dari 16.20 -> Flash sale (F-53)
    expect(find.text('Flash sale'), findsOneWidget);
    expect(find.text('2 paket'), findsOneWidget);
    expect(find.text('1 paket'), findsOneWidget);
    expect(find.byType(NavigasiBawah), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Mitra sekitar'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Mitra sekitar'), findsOneWidget);
    expect(find.text('Bumi Senyiur'), findsOneWidget);

    // chip kategori: belum ada mitra yg punya paket minuman -> kosong (F-03)
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Minuman'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Minuman'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada paket minuman sore ini'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('pindah tab lewat navigasi bawah', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(SisaRasaApp(akunAwal: dummyAkun.first));
    // paket dimuat async dari repository, tunggu satu frame
    await tester.pump();

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
    await tester.pumpWidget(SisaRasaApp(akunAwal: dummyAkun.first));
    // paket dimuat async dari repository, tunggu satu frame
    await tester.pump();

    // kolom jumlah hanya menerima angka dan dibatasi sisa porsi (3)
    await keDetailSandwich(tester);
    await tester.enterText(find.byType(TextField), '9a');
    await tester.pump();
    expect(find.text('Tambah · Rp102.000'), findsOneWidget);
    await tester.tap(find.text('Tambah · Rp102.000'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // keranjang -> checkout, total checkout ditambah biaya layanan 10%
    await tester.tap(find.text('3 porsi'));
    await tester.pumpAndSettle();
    expect(find.text('Bayar di tempat'), findsNothing);
    await tester.tap(find.text('Lanjut ke checkout · Rp102.000'));
    await tester.pumpAndSettle();
    expect(find.text('Rp112.200'), findsWidgets);
    expect(find.text('Hemat Rp153.000'), findsOneWidget);

    // pilih VA, terus pastiin aturan "tidak diambil" (F-56) keliatan sebelum bayar
    await tester.ensureVisible(find.text('Virtual Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Virtual Account'));
    await tester.pump();
    expect(find.text('Total · VA BCA'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('dananya tidak dikembalikan'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('dananya tidak dikembalikan'), findsOneWidget);
    // biaya layanan 10% dari Rp102.000
    expect(find.text('Rp10.200'), findsOneWidget);

    // bayar, porsinya langsung ditahan
    await tester.tap(find.text('Bayar sekarang'));
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

    // stok yg udah dibayar ga balik: breakfast habis, Ibis tinggal punya 1 paket
    // (kartu Ibis + Prime Cut di Flash sale sama-sama 1 paket)
    await tester.tap(find.text('Beranda').last);
    await tester.pumpAndSettle();
    expect(find.text('1 paket'), findsNWidgets(2));
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('ganti akun cepat, pesanan akun lain ga ikut keliatan', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(SisaRasaApp(akunAwal: dummyAkun.first));
    // paket dimuat async dari repository, tunggu satu frame
    await tester.pump();

    // Rani bikin pesanan (belum dibayar)
    await keCheckout(tester);
    await tester.tap(find.text('Bayar sekarang'));
    await lewati(tester);
    await tester.tap(find.byTooltip('Tutup'));
    await lewati(tester);
    expect(jumlahBerlangsung(tester), '1');

    // pindah ke Dimas lewat tombol mode uji di tab akun
    await tester.tap(find.text('Akun').last);
    await lewati(tester);
    await tester.tap(find.text('Ganti akun'));
    await lewati(tester);
    // akun mitra juga bisa dipilih (halaman mitra udah ada)
    expect(find.text('Mitra · dapur.ibis@contoh.id'), findsOneWidget);
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
    await tester.pumpWidget(SisaRasaApp(akunAwal: dummyAkun.first));
    // paket dimuat async dari repository, tunggu satu frame
    await tester.pump();

    await keCheckout(tester);
    await tester.tap(find.text('Bayar sekarang'));
    await lewati(tester);
    expect(find.text('Bayar dengan QRIS'), findsOneWidget);
    expect(sisaPorsi(tester, 'p1'), 2);

    // ganti metode sebelum bayar: QRIS -> VA BRI, tagihannya dibikin ulang
    await tester.tap(find.text('Ganti metode pembayaran'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Virtual Account BRI'));
    await lewati(tester);
    await lewati(tester);
    expect(find.text('Virtual Account BRI'), findsOneWidget);
    expect(find.text('Salin nomor'), findsOneWidget);

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
    await tester.pumpWidget(SisaRasaApp(akunAwal: dummyAkun.first));
    // paket dimuat async dari repository, tunggu satu frame
    await tester.pump();

    // dari kartu Flash sale buka halaman Ibis Hotel
    await bukaIbis(tester);
    expect(find.text('Paket hari ini'), findsOneWidget);
    expect(find.text('2 paket'), findsOneWidget);
    expect(find.text('Petunjuk arah'), findsOneWidget);
    expect(find.text('Halal bersertifikat'), findsOneWidget);

    // tambah dua paket beda, bar keranjang ngitung keduanya
    await tester.tap(find.byTooltip('Tambah American Breakfast Set'));
    await tester.pump();
    await tester.tap(find.byTooltip('Tambah Petit Four & Macaron'));
    await tester.pump();
    await tester.tap(find.byTooltip('Tambah porsi').last);
    await tester.pump();
    expect(find.text('3 porsi'), findsOneWidget);
    expect(find.text('Rp110.000'), findsOneWidget);

    // minus di jumlah 1 = keluarin dari keranjang
    await tester.tap(find.byTooltip('Hapus dari keranjang'));
    await tester.pump();
    expect(find.text('2 porsi'), findsOneWidget);
    expect(find.text('Rp76.000'), findsWidgets);
    expect(find.byTooltip('Tambah American Breakfast Set'), findsOneWidget);

    // balik ke beranda, gulir ke atas: ikon keranjang di kanan atas nunjukin 2 porsi
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('jumlah-keranjang'))).data,
      '2',
    );
    await tester.tap(find.byTooltip('Keranjang, 2 porsi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lanjut ke checkout'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('tambah cepat dari mitra lain nanya dulu (F-07)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(SisaRasaApp(akunAwal: dummyAkun.first));
    // paket dimuat async dari repository, tunggu satu frame
    await tester.pump();

    // keranjang isi sandwich Ibis Hotel dulu, lalu balik ke beranda
    await keCheckout(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();

    // buka Teras Nusantara dari Mitra sekitar, terus tombol + paketnya
    final mitraLain = find.text('Teras Nusantara');
    await tester.scrollUntilVisible(
      mitraLain,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // geser sampe barisnya di atas, biar ga ketutup bar keranjang yg melayang
    await tester.ensureVisible(mitraLain);
    await tester.pumpAndSettle();
    await tester.tap(mitraLain);
    await tester.pumpAndSettle();
    final tambah = find.byTooltip('Tambah Iga Bakar Madu');
    await tester.tap(tambah);
    await tester.pumpAndSettle();
    expect(find.text('Ganti isi keranjang?'), findsOneWidget);

    // batal: keranjang tetap isi sandwich
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Rp34.000'), findsWidgets);

    // setuju: keranjang diganti iga bakar
    await tester.tap(tambah);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kosongkan & tambah'));
    await tester.pumpAndSettle();
    expect(find.text('1 porsi'), findsOneWidget);
    expect(find.text('Rp50.000'), findsWidgets);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('pesanan sampai selesai lewat aplikasi mitra (F-41, F-43, F-46)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(SisaRasaApp(akunAwal: dummyAkun.first));
    // paket dimuat async dari repository, tunggu satu frame
    await tester.pump();

    // Rani pesan + bayar sandwich Ibis Hotel
    await keCheckout(tester);
    await tester.tap(find.text('Bayar sekarang'));
    await lewati(tester);
    await tester.tap(find.text('Saya sudah bayar · cek status'));
    await lewati(tester);
    await lewati(tester);
    expect(find.text('Pesananmu sedang disiapkan'), findsOneWidget);
    final kode = tester
        .widgetList<Text>(find.textContaining('SR-'))
        .map((t) => t.data!)
        .firstWhere((t) => RegExp(r'^SR-[A-Z2-9]{4}$').hasMatch(t));
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();

    // masuk sebagai mitra Ibis Hotel, router langsung pindah ke dasbor mitra (F-26)
    await gantiAkun(tester, 'Ibis Hotel');
    expect(find.text('Dapur sore ini'), findsOneWidget);
    expect(find.text('Perlu disiapkan'), findsOneWidget);

    // pesanan masuk: tandai siap (F-43)
    await tester.tap(find.text('Pesanan').last);
    await tester.pumpAndSettle();
    expect(find.text(kode), findsOneWidget);
    await tester.tap(find.text('Tandai siap'));
    await tester.pumpAndSettle();
    expect(
      find.text('Belum ada pesanan yang perlu disiapkan.'),
      findsOneWidget,
    );

    // balik jadi Rani: statusnya ikut berubah jadi siap diambil
    await gantiAkun(tester, 'Rani Amelia');
    await tester.tap(find.text('Pesanan').last);
    await tester.pumpAndSettle();
    expect(find.text('Siap diambil'), findsOneWidget);

    // kode QR layar penuh, tunggu snackbar "Masuk sebagai ..." ilang dulu
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tampilkan QR'));
    await tester.pumpAndSettle();
    expect(find.text('Tunjukkan ke kasir Ibis Hotel'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Selesai'));
    await tester.pumpAndSettle();

    // mitra cocokkan kode yg disebut pembeli (F-46) -> selesai diambil (F-20)
    await gantiAkun(tester, 'Ibis Hotel');
    await tester.tap(find.byTooltip('Pindai kode ambil'));
    await tester.pump(const Duration(seconds: 1));
    // kamera ga ada di tes, jadi lewat Ketik kode.
    // tunggu snackbar "Masuk sebagai ..." ilang dulu, soalnya nutupin tombolnya
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Ketik kode'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'xxxx');
    await tester.pump();
    await tester.tap(find.text('Cek kode'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Kode SR-XXXX tidak ditemukan atau sudah dipakai. Cek lagi kode di HP pembeli.',
      ),
      findsOneWidget,
    );
    expect(find.text('Cek ulang'), findsOneWidget);
    // ngetik lagi: galatnya ilang, tombolnya balik jadi Cek kode
    await tester.enterText(find.byType(TextField), kode.substring(3));
    await tester.pump();
    await tester.tap(find.text('Cek kode'));
    await tester.pumpAndSettle();
    expect(find.text('Kode cocok'), findsOneWidget);
    await tester.tap(find.text('Serahkan dan selesaikan'));
    await tester.pumpAndSettle();
    expect(find.text('$kode selesai diambil'), findsOneWidget);
    // dasbor: 1 porsi terselamatkan
    expect(find.text('1'), findsWidgets);

    // pembeli liat pesanannya di segmen Selesai
    await gantiAkun(tester, 'Rani Amelia');
    await tester.tap(find.text('Pesanan').last);
    await tester.pumpAndSettle();
    expect(jumlahBerlangsung(tester), '0');
    await tester.tap(find.text('Selesai').last);
    await tester.pumpAndSettle();
    expect(find.text('1 porsi terselamatkan'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });
}

void tesKelolaPaket() {
  testWidgets(
    'mitra kelola paket: terbitkan, validasi harga, nonaktif, hapus',
    (tester) async {
      // lebih lebar: dialog pemilih jam butuh ruang buat tombol OK nya
      await tester.binding.setSurfaceSize(const Size(800, 1300));
      await tester.pumpWidget(SisaRasaApp(akunAwal: dummyAkun.first));
      // paket dimuat async dari repository, tunggu satu frame
      await tester.pump();
      await gantiAkun(tester, 'Ibis Hotel');

      await tester.tap(find.text('Paket').last);
      await tester.pumpAndSettle();
      expect(find.text('Semua 2'), findsOneWidget);

      // F-15: paket baru, isian kosong ditolak
      await tester.tap(find.text('Paket baru'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terbitkan paket'));
      await tester.pumpAndSettle();
      expect(find.text('Nama paket wajib diisi.'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField).at(0),
        'Nasi Kuning Sisa Sarapan',
      );
      await tester.tap(find.text('Hidangan utama'));
      await tester.ensureVisible(find.text('Harga asli'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(2), '30000');
      // F-16: diskon ga boleh >= harga asli
      await tester.enterText(find.byType(TextField).at(3), '30000');
      await tester.ensureVisible(find.byTooltip('Tambah porsi'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tambah porsi'));
      await tester.tap(find.byTooltip('Tambah porsi'));
      await tester.pump();
      expect(find.byKey(const Key('jumlah-porsi')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('jumlah-porsi'))).data,
        '3',
      );
      // jam ambil: pakai jam awal yg ditawarin (buka 16.20, tutup 18.20)
      await tester.ensureVisible(find.text('Buka'));
      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terbitkan paket'));
      await tester.pumpAndSettle();
      expect(find.text('Harus lebih murah dari harga asli.'), findsOneWidget);

      await tester.ensureVisible(find.text('Harga diskon'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(3), '12000');
      await tester.tap(find.text('Terbitkan paket'));
      await tester.pumpAndSettle();
      expect(find.text('Semua 3'), findsOneWidget);
      expect(find.text('Nasi Kuning Sisa Sarapan'), findsOneWidget);

      // F-45: nonaktifin paket baru, ga keliatan pembeli
      final baris = find
          .ancestor(
            of: find.text('Nasi Kuning Sisa Sarapan'),
            matching: find.byType(Material),
          )
          .first;
      await tester.tap(
        find.descendant(of: baris, matching: find.byType(Switch)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nonaktif 1'), findsOneWidget);

      // F-18: ubah lalu hapus pakai konfirmasi
      await tester.tap(find.text('Nasi Kuning Sisa Sarapan'));
      await tester.pumpAndSettle();
      expect(find.text('Ubah paket'), findsOneWidget);
      await tester.ensureVisible(find.text('Hapus paket'));
      // tunggu snackbar sebelumnya hilang, biar tombolnya ga ketutup
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus paket'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      expect(find.text('Semua 2'), findsOneWidget);
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('mitra saldo: riwayat, ubah rekening, nama harus cocok (F-49)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(SisaRasaApp(akunAwal: dummyAkun.first));
    // paket dimuat async dari repository, tunggu satu frame
    await tester.pump();
    await gantiAkun(tester, 'Ibis Hotel');

    await tester.tap(find.text('Saldo').last);
    await tester.pumpAndSettle();
    // saldo kemarin udah dicairin jam 09.00, sisa dana masuk hari ini
    expect(
      tester.widget<Text>(find.byKey(const Key('saldo-tersedia'))).data,
      'Rp12.600',
    );
    expect(find.text('BCA · 7890'), findsOneWidget);
    expect(find.text('Pencairan ke BCA · 7890'), findsOneWidget);

    await tester.tap(find.text('Ubah'));
    await tester.pumpAndSettle();
    expect(find.text('Rekening pencairan'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '9876543210');
    await tester.enterText(find.byType(TextField).at(1), 'HOTEL LAIN');
    await tester.tap(find.text('Simpan rekening'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nama tidak cocok'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'ibis hotel');
    await tester.pump();
    expect(find.text('Nama cocok dengan data bank'), findsOneWidget);
    await tester.tap(find.text('Simpan rekening'));
    await tester.pumpAndSettle();

    expect(find.text('BCA · 3210'), findsOneWidget);
    expect(find.text('a.n. IBIS HOTEL'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });
  testWidgets('chat pembeli dan mitra per pesanan (F-67 s.d. F-70)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(SisaRasaApp(akunAwal: dummyAkun.first));
    // paket dimuat async dari repository, tunggu satu frame
    await tester.pump();

    // Rani pesan + bayar dulu, sebelum dibayar chat belum ada
    await keCheckout(tester);
    await tester.tap(find.text('Bayar sekarang'));
    await lewati(tester);
    await tester.tap(find.text('Saya sudah bayar · cek status'));
    await lewati(tester);
    await lewati(tester);
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();

    // pesan cepat dari kartu pesanan
    await tester.tap(find.text('Chat mitra'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Belum ada pesan'), findsOneWidget);
    await tester.tap(find.text('Saya sudah sampai'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Saya sudah sampai'), findsNWidgets(2));
    expect(find.byIcon(Icons.done), findsOneWidget);
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();

    // mitra liat ada 1 pesan baru di kartu pesanan masuk
    await gantiAkun(tester, 'Ibis Hotel');
    await tester.tap(find.text('Pesanan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chat pembeli, 1 pesan baru'));
    await tester.pumpAndSettle();
    expect(find.text('Rani A.'), findsOneWidget);
    // tunggu snackbar "Masuk sebagai ..." ilang, soalnya nutupin kolom ketik
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Oke, ditunggu');
    await tester.pump();
    await tester.tap(find.byTooltip('Kirim'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Oke, ditunggu'), findsOneWidget);
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Chat pembeli'), findsOneWidget);

    // Rani: balasan masuk, pesannya sendiri udah dibaca mitra
    await gantiAkun(tester, 'Rani Amelia');
    await tester.tap(find.text('Pesanan').last);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(Badge), matching: find.text('1')),
      findsOneWidget,
    );
    await tester.tap(find.text('Chat mitra'));
    await tester.pumpAndSettle();
    expect(find.text('Oke, ditunggu'), findsOneWidget);
    expect(find.byIcon(Icons.done_all), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });
}
