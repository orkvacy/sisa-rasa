import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sisa_rasa/core/sesi_aktif.dart';
import 'package:sisa_rasa/data/repositories/akun_tiruan.dart';
import 'package:sisa_rasa/data/repositories/pembayaran_tiruan.dart';
import 'package:sisa_rasa/data/repositories/percakapan_tiruan.dart';
import 'package:sisa_rasa/data/repositories/pesanan_api.dart';
import 'package:sisa_rasa/data/sumber/klien_api.dart';
import 'package:sisa_rasa/domain/aturan/status_pesanan.dart';
import 'package:sisa_rasa/presentation/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/presentation/bloc/pesanan_event.dart';
import 'package:sisa_rasa/presentation/cubit/akun_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/percakapan_cubit.dart';
import 'package:sisa_rasa/presentation/screens/mitra/pesanan_masuk.dart';

import 'pesanan_server_test.dart' show pesananJson;

void main() {
  testWidgets('mitra: pesanan tidak diambil ada di segmen Selesai + rekap', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final api = PesananApi(
      KlienApi(
        alamat: 'https://api.tes',
        sesi: SesiAktif()..token = 'tok-m1',
        klien: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'pesanan': [
                pesananJson(
                  status: StatusPesanan.tidakDiambil,
                  kode: 'SR-AB12',
                ),
              ],
            }),
            200,
          ),
        ),
      ),
    );
    final bloc = PesananBloc(
      pembayaran: PembayaranTiruan(),
      server: api,
      muatUlangPaket: () async {},
    )..add(PesananDimuat());
    final akun = AkunCubit(
      layanan: AkunTiruan(),
      awal: const {'id': 'mitra-1', 'nama': 'Ibis Hotel', 'peran': 'mitra'},
    );
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: bloc),
          BlocProvider.value(value: akun),
          BlocProvider(
            create: (_) => PercakapanCubit(layanan: PercakapanTiruan()),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: PesananMasuk())),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Selesai').first);
    await tester.pumpAndSettle();
    expect(find.text('Tidak diambil'), findsOneWidget);
    // udah lewat jam ambil: ga ada tombol tandai diambil
    expect(find.text('Sudah diambil'), findsNothing);
    expect(find.textContaining('1 pesanan selesai'), findsOneWidget);
    await tester.runAsync(bloc.close);
  });
}
