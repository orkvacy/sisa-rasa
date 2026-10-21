import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sisa_rasa/core/sesi_aktif.dart';
import 'package:sisa_rasa/data/repositories/voucher_api.dart';
import 'package:sisa_rasa/data/sumber/dummy_akun.dart';
import 'package:sisa_rasa/data/sumber/klien_api.dart';
import 'package:sisa_rasa/domain/aturan/voucher.dart';
import 'package:sisa_rasa/injection.dart';
import 'package:sisa_rasa/main.dart';
import 'package:sisa_rasa/presentation/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/presentation/cubit/keranjang_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/paket_cubit.dart';
import 'package:sisa_rasa/presentation/router.dart';

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await sl.reset();
    daftarkanDependensi();
  });

  test('aturan potongan: persen dari subtotal, dibatesin maksimal', () {
    final v = {'persen': 20, 'maksPotongan': 10000, 'minBelanja': 30000};
    expect(potonganVoucher(v, 34000), 6800);
    expect(potonganVoucher(v, 76000), 10000);
    expect(alasanVoucherTakBisa(v, 20000, (n) => 'Rp$n'), contains('Rp10000'));
    expect(alasanVoucherTakBisa(v, 30000, (n) => 'Rp$n'), isNull);
  });

  test('VoucherApi: daftar, cek, buat (tanggal UTC ISO)', () async {
    final diminta = <http.Request>[];
    final contoh = {
      'id': 'v1',
      'kode': 'HEMAT20',
      'judul': 'Hemat sore',
      'persen': 20,
      'maksPotongan': 10000,
      'minBelanja': 30000,
      'mulai': '2026-10-21T00:00:00Z',
      'berakhir': '2026-11-21T00:00:00Z',
      'kuota': null,
      'terpakai': 0,
      'khususBaru': false,
      'publik': true,
      'aktif': true,
    };
    final api = VoucherApi(
      KlienApi(
        alamat: 'https://api.tes',
        sesi: SesiAktif()..token = 'tok-1',
        klien: MockClient((req) async {
          diminta.add(req);
          return switch (req.url.path) {
            '/v1/voucher/cek' => http.Response(
              jsonEncode({'voucher': contoh, 'potongan': 6800}),
              200,
            ),
            '/v1/admin/voucher' when req.method == 'POST' => http.Response(
              jsonEncode({'voucher': contoh}),
              201,
            ),
            _ => http.Response(
              jsonEncode({
                'voucher': [contoh],
              }),
              200,
            ),
          };
        }),
      ),
    );
    final daftar = await api.tersedia();
    expect(daftar.single['berakhir'], isA<DateTime>());
    final hasil = await api.cek('hemat20', 34000);
    expect(hasil['potongan'], 6800);
    expect(jsonDecode(diminta[1].body), {'kode': 'hemat20', 'subtotal': 34000});
    await api.buat({
      'kode': 'HEMAT20',
      'mulai': DateTime.utc(2026, 10, 21),
      'berakhir': DateTime.utc(2026, 11, 21),
    });
    final dikirim = jsonDecode(diminta.last.body) as Map;
    expect(dikirim['mulai'], '2026-10-21T00:00:00.000Z');
  });

  testWidgets('checkout pakai voucher: potongan masuk rincian dan pesanan', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SisaRasaApp(akunAwal: dummyAkun.first));
    await tester.pumpAndSettle();

    final c = tester.element(find.byType(Scaffold).first);
    final sarapan = c.read<PaketCubit>().state.firstWhere(
      (p) => p['nama'] == 'American Breakfast Set',
    );
    c.read<KeranjangCubit>().tambah(sarapan, 1);
    GoRouter.of(c).push(Rute.checkout);
    await tester.pumpAndSettle();
    expect(find.text('Pakai voucher'), findsOneWidget);

    await tester.tap(find.byKey(const Key('baris-voucher')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('voucher-SISAHEMAT')), findsOneWidget);
    await tester.tap(find.byKey(const Key('voucher-SISAHEMAT')));
    await tester.pumpAndSettle();

    // 34rb: biaya layanan 3.400, potongan 20% = 6.800
    expect(find.text('SISAHEMAT terpakai'), findsOneWidget);
    expect(find.text('−Rp6.800'), findsOneWidget);
    expect(find.text('Rp30.600'), findsWidgets);

    await tester.tap(find.textContaining('Bayar').last);
    await tester.pumpAndSettle();
    final pesanan = tester
        .element(find.byType(Scaffold).first)
        .read<PesananBloc>()
        .state
        .first;
    expect(pesanan['potongan'], 6800);
    expect(pesanan['kodeVoucher'], 'SISAHEMAT');
    expect(pesanan['subtotal'], 34000);
    expect(pesanan['total'], 30600);
  });

  testWidgets('kode salah: pesan di bawah kolom, voucher ga kepakai', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SisaRasaApp(akunAwal: dummyAkun.first));
    await tester.pumpAndSettle();
    final c = tester.element(find.byType(Scaffold).first);
    final sarapan = c.read<PaketCubit>().state.firstWhere(
      (p) => p['nama'] == 'American Breakfast Set',
    );
    c.read<KeranjangCubit>().tambah(sarapan, 1);
    GoRouter.of(c).push(Rute.checkout);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('baris-voucher')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('kode-voucher')), 'NGAWUR');
    await tester.tap(find.text('Pakai'));
    await tester.pumpAndSettle();
    expect(find.text('Kode voucher tidak ditemukan.'), findsOneWidget);
  });

  testWidgets('admin: daftar voucher, matiin, bikin baru', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final admin = dummyAkun.firstWhere((a) => a['peran'] == 'admin');
    await tester.pumpWidget(SisaRasaApp(akunAwal: admin));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Voucher'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('voucher-admin-SISAHEMAT')), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('voucher-admin-SISAHEMAT')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();
    final sakelar = tester.widget<Switch>(
      find.descendant(
        of: find.byKey(const Key('voucher-admin-SISAHEMAT')),
        matching: find.byType(Switch),
      ),
    );
    expect(sakelar.value, isFalse);

    await tester.tap(find.byKey(const Key('buat-voucher')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('isian-kode')), 'promoig');
    await tester.enterText(find.byKey(const Key('isian-judul')), 'Promo IG');
    await tester.tap(find.byKey(const Key('simpan-voucher')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('voucher-admin-PROMOIG')), findsOneWidget);
    expect(find.text('Voucher dibuat'), findsOneWidget);
  });
}
