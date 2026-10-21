import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sisa_rasa/core/sesi_aktif.dart';
import 'package:sisa_rasa/data/repositories/pembayaran_tiruan.dart';
import 'package:sisa_rasa/data/repositories/pesanan_api.dart';
import 'package:sisa_rasa/data/sumber/klien_api.dart';
import 'package:sisa_rasa/domain/aturan/status_pesanan.dart';
import 'package:sisa_rasa/presentation/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/presentation/bloc/pesanan_event.dart';
import 'package:sisa_rasa/presentation/screens/pembayaran.dart';

import 'pesanan_server_test.dart' show pesananJson;

/// layar pembayaran dengan server tiruan yang ngasih tagihan Midtrans
Future<PesananBloc> _pasang(
  WidgetTester tester, {
  required String metode,
  required Map<String, String> tagihan,
  List<String> statusBerikut = const [],
}) async {
  // layar tinggi biar catatan di bawah daftar langkah ikut digambar
  await tester.binding.setSurfaceSize(const Size(420, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final status = [...statusBerikut];
  final api = PesananApi(
    KlienApi(
      alamat: 'https://api.tes',
      sesi: SesiAktif()..token = 'tok-1',
      klien: MockClient((req) async {
        if (req.url.path.endsWith('/cek-bayar')) {
          return http.Response(
            jsonEncode({
              'pesan': 'Pembayaran belum kami terima. Kalau sudah bayar, tunggu sebentar lalu cek lagi.',
            }),
            409,
          );
        }
        final st = status.isEmpty
            ? StatusPesanan.menungguBayar
            : status.removeAt(0);
        final p =
            pesananJson(
              status: st,
              kode: st == StatusPesanan.disiapkan ? 'SR-AB12' : null,
            )..addAll({
              'metode': metode,
              'tagihan': tagihan,
              // batas bayar masih jauh, biar layarnya ga batal sendiri
              'batasBayar': DateTime.now()
                  .toUtc()
                  .add(const Duration(minutes: 15))
                  .toIso8601String(),
            });
        return http.Response(
          jsonEncode({
            'pesanan': [p],
          }),
          200,
        );
      }),
    ),
  );
  final bloc = PesananBloc(
    pembayaran: PembayaranTiruan(),
    server: api,
    muatUlangPaket: () async {},
  )..add(PesananDimuat());
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Pembayaran(idPesanan: 'ps-1'),
      ),
      GoRoute(
        path: '/pesanan/detail/:id',
        builder: (_, _) => const Scaffold(body: Text('detail pesanan')),
      ),
    ],
  );
  await tester.pumpWidget(
    BlocProvider.value(
      value: bloc,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await _tunggu(tester);
  return bloc;
}

/// layar ini punya hitung mundur yg terus jalan, jadi pumpAndSettle ga pernah
/// selesai. cukup tunggu jawaban server tiruan + animasi pindah halaman
Future<void> _tunggu(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets(
    'tagihan Midtrans: tanpa label mode uji, pindah sendiri pas lunas',
    (tester) async {
      final bloc = await _pasang(
        tester,
        metode: 'qris',
        tagihan: {
          'idTagihan': 'ps-1-abcde',
          'penyedia': 'midtrans',
          'isiQr': '00020101021226...6304ABCD',
        },
        // muat pertama masih nunggu, muat berikutnya (abis webhook) udah lunas
        statusBerikut: [StatusPesanan.menungguBayar, StatusPesanan.disiapkan],
      );
      expect(
        find.text('Halaman ini lanjut sendiri setelah pembayaranmu diterima.'),
        findsOneWidget,
      );
      expect(find.textContaining('Mode uji'), findsNothing);
      expect(find.textContaining('QR ini asli'), findsNothing);

      // polling berikutnya: server udah nerima webhook -> layar pindah sendiri
      bloc.add(PesananDimuat());
      await _tunggu(tester);
      expect(find.text('detail pesanan'), findsOneWidget);
      // bloc nunggu request tiruan selesai, jadi ditutup di waktu asli
      await tester.runAsync(bloc.close);
    },
  );

  testWidgets('Mandiri lewat Midtrans: kode perusahaan + kode bayar', (
    tester,
  ) async {
    final bloc = await _pasang(
      tester,
      metode: 'va_mandiri',
      tagihan: {
        'idTagihan': 'ps-1-abcde',
        'penyedia': 'midtrans',
        'nomorVa': '9988 7766 5544',
        'kodePerusahaan': '70012',
      },
    );
    expect(find.text('Kode perusahaan 70012'), findsOneWidget);
    expect(find.text('Kode bayar'), findsOneWidget);
    expect(find.text('9988 7766 5544'), findsOneWidget);
    expect(find.textContaining('Multipayment'), findsOneWidget);
    // bloc nunggu request tiruan selesai, jadi ditutup di waktu asli
    await tester.runAsync(bloc.close);
  });
}
