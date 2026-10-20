import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisa_rasa/data/repositories/paket_lokal.dart';
import 'package:sisa_rasa/domain/repositories/layanan_pesanan.dart';
import 'package:sisa_rasa/presentation/cubit/keranjang_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/paket_cubit.dart';
import 'package:sisa_rasa/presentation/screens/beranda.dart';
import 'package:sisa_rasa/presentation/widgets/kerangka.dart';

/// server pura-pura: tiap muat nunggu [jawab] diselesaiin dari tes
class _PaketLambat extends PaketLokal {
  Completer<List<Map<String, dynamic>>> jawab = Completer();

  @override
  bool get lokal => false;

  @override
  Future<List<Map<String, dynamic>>> semua() => jawab.future;
}

void main() {
  testWidgets('jaringan lambat: kerangka, gagal: coba lagi, lalu tampil', (
    tester,
  ) async {
    final layanan = _PaketLambat();
    final cubit = PaketCubit(layanan: layanan);
    final asli = await PaketLokal().semua();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cubit),
              BlocProvider(create: (_) => KeranjangCubit()),
            ],
            child: Beranda(onBukaMitra: (_) {}),
          ),
        ),
      ),
    );

    // masih nunggu server: kerangka, bukan "belum ada paket"
    unawaited(cubit.muat());
    await tester.pump();
    expect(find.byType(KilauKerangka), findsOneWidget);
    expect(find.textContaining('Belum ada paket'), findsNothing);

    // ga ada jaringan: pesan + tombol coba lagi
    layanan.jawab.completeError(const GagalLayanan('Tidak bisa terhubung.'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(KilauKerangka), findsNothing);
    expect(find.text('Paket belum bisa dimuat'), findsOneWidget);
    expect(find.text('Tidak bisa terhubung.'), findsOneWidget);

    // coba lagi: kerangka lagi, lalu daftar mitranya muncul
    layanan.jawab = Completer();
    await tester.tap(find.byKey(const Key('coba-muat-lagi')));
    await tester.pump();
    expect(find.byType(KilauKerangka), findsOneWidget);
    layanan.jawab.complete(asli);
    await tester.pumpAndSettle();
    expect(find.text('Paket belum bisa dimuat'), findsNothing);
    expect(find.text('Ibis Hotel'), findsWidgets);

    await cubit.close();
  });

  test(
    'udah ada isi lalu muat ulang gagal: isi lama tetap, galat ke snackbar',
    () async {
      final layanan = _PaketLambat();
      final cubit = PaketCubit(layanan: layanan);
      final galat = <String>[];
      final dengar = cubit.galat.listen(galat.add);
      layanan.jawab.complete(await PaketLokal().semua());
      await cubit.muat();
      final jumlah = cubit.state.length;

      layanan.jawab = Completer()..completeError(const GagalLayanan('putus'));
      await cubit.muat();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.length, jumlah);
      expect(cubit.gagalMuat, isNull);
      expect(cubit.memuat, isFalse);
      expect(galat, ['putus']);
      await dengar.cancel();
      await cubit.close();
    },
  );
}
