import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisa_rasa/data/repositories/akun_tiruan.dart';
import 'package:sisa_rasa/data/repositories/paket_lokal.dart';
import 'package:sisa_rasa/data/repositories/pembayaran_tiruan.dart';
import 'package:sisa_rasa/domain/aturan/status_pesanan.dart';
import 'package:sisa_rasa/domain/repositories/layanan_percakapan.dart';
import 'package:sisa_rasa/presentation/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/presentation/cubit/akun_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/keranjang_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/paket_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/percakapan_cubit.dart';
import 'package:sisa_rasa/presentation/screens/keranjang.dart';
import 'package:sisa_rasa/presentation/screens/percakapan.dart';
import 'package:sisa_rasa/presentation/widgets/animasi.dart';
import 'package:sisa_rasa/presentation/widgets/pil_status.dart';
import 'package:sisa_rasa/presentation/widgets/tombol_jumlah.dart';

import 'bantu_lokasi.dart';

Widget bungkus(Widget child, {bool kurangi = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: kurangi),
    child: Scaffold(body: child),
  ),
);

void main() {
  for (final kurangi in [false, true]) {
    testWidgets(
      'hapus, tambah ulang, dan kosongkan keranjang; reduced=$kurangi',
      (tester) async {
        final paket = PaketCubit(layanan: PaketLokal());
        await paket.muat();
        final keranjang = KeranjangCubit()
          ..tambah(paket.cari('p1'), 1)
          ..tambah(paket.cari('p2'), 1);
        addTearDown(paket.close);
        addTearDown(keranjang.close);
        await tester.pumpWidget(
          bungkus(
            MultiBlocProvider(
              providers: [
                BlocProvider.value(value: paket),
                BlocProvider.value(value: keranjang),
                lokasiUji(),
              ],
              child: const Keranjang(),
            ),
            kurangi: kurangi,
          ),
        );
        final baris = find.byKey(const ValueKey('p1'));
        final tinggi = tester.getSize(baris).height;
        keranjang.hapus('p1');
        await tester.pump();
        if (!kurangi) {
          await tester.pump(const Duration(milliseconds: 110));
          expect(tester.getSize(baris).height, lessThan(tinggi));
          expect(tester.getSize(baris).height, greaterThan(0));
        } else {
          expect(baris, findsNothing);
        }
        // Tambah kembali sebelum animasi selesai: callback lama tidak boleh menghapusnya.
        keranjang.tambah(paket.cari('p1'), 2);
        await tester.pumpAndSettle();
        expect(baris, findsOneWidget);
        expect(keranjang.state['p1'], 2);
        keranjang.hapus('p2');
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('p2')), findsNothing);
        keranjang.kosongkan();
        await tester.pump();
        await tester.pump();
        if (!kurangi) {
          expect(
            tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
            isNull,
          );
        }
        await tester.pumpAndSettle();
        expect(find.text('Keranjang kosong'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('ketukan cepat mempertahankan angka terbaru dan posisi tombol', (
    tester,
  ) async {
    var jumlah = 1;
    await tester.pumpWidget(
      bungkus(
        StatefulBuilder(
          builder: (context, setState) => PengaturJumlah(
            jumlah: jumlah,
            onTambah: () => setState(() => jumlah++),
            onKurang: () => setState(() => jumlah--),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tombol = find.byTooltip('Tambah porsi');
    final posisi = tester.getCenter(tombol);
    for (var i = 0; i < 12; i++) {
      await tester.tap(tombol);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getCenter(tombol), posisi);
    }
    await tester.pumpAndSettle();
    expect(find.text('13'), findsOneWidget);
    expect(find.text('12'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'status dan angka langsung selesai saat reduced motion diaktifkan',
    (tester) async {
      Widget isi(String status, int jumlah, bool kurangi) => bungkus(
        Column(
          children: [
            PilStatus(status: status),
            PengaturJumlah(jumlah: jumlah, onKurang: () {}, onTambah: () {}),
          ],
        ),
        kurangi: kurangi,
      );
      await tester.pumpWidget(isi(StatusPesanan.disiapkan, 1, false));
      await tester.pumpWidget(isi(StatusPesanan.siapDiambil, 2, false));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpWidget(isi(StatusPesanan.siapDiambil, 2, true));
      expect(find.text('Disiapkan'), findsNothing);
      expect(find.text('Siap diambil'), findsOneWidget);
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsOneWidget);
    },
  );

  testWidgets('centang hanya diputar sekali dan berhenti saat reduced motion', (
    tester,
  ) async {
    var mulai = 0;
    final skala = find.descendant(
      of: find.byType(MunculSekali),
      matching: find.byType(ScaleTransition),
    );
    Widget isi(bool animasi, bool kurangi) => bungkus(
      MunculSekali(
        animasi: animasi,
        centang: true,
        onMulai: animasi ? () => mulai++ : null,
        child: const Icon(Icons.check),
      ),
      kurangi: kurangi,
    );
    await tester.pumpWidget(isi(false, false));
    await tester.pumpWidget(isi(true, false));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<ScaleTransition>(skala).scale.value, lessThan(1));
    await tester.pumpWidget(isi(true, true));
    expect(tester.widget<ScaleTransition>(skala).scale.value, 1);
    await tester.pumpWidget(isi(false, false));
    await tester.pumpWidget(isi(true, false));
    expect(mulai, 1);
    expect(tester.widget<ScaleTransition>(skala).scale.value, 1);
  });

  testWidgets(
    'chat: riwayat statis, pesan baru sekali, scroll tidak mengulang',
    (tester) async {
      final server = _ChatUji();
      final chat = PercakapanCubit(layanan: server);
      final akun = AkunCubit(
        layanan: AkunTiruan(),
        awal: const {'peran': 'pembeli'},
      );
      final pesanan = _PesananUji();
      addTearDown(chat.close);
      addTearDown(akun.close);
      addTearDown(pesanan.close);
      addTearDown(server.stream.close);
      await tester.pumpWidget(
        bungkus(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: chat),
              BlocProvider.value(value: akun),
              BlocProvider<PesananBloc>.value(value: pesanan),
            ],
            child: const Percakapan(idPesanan: 'uji'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<MunculSekali>(find.byType(MunculSekali))
            .every((w) => !w.animasi),
        isTrue,
      );
      final baru = server.pesan(100);
      server.stream.add({'jenis': 'pesan', 'pesan': baru});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      final baris = find.byKey(const ValueKey<String>('100'));
      Finder fade() => find
          .descendant(of: baris, matching: find.byType(FadeTransition))
          .first;
      expect(tester.widget<FadeTransition>(fade()).opacity.value, lessThan(1));
      server.stream.add({
        'jenis': 'pesan',
        'pesan': {...baru, 'status': 'dibaca'},
      });
      await tester.pumpAndSettle();
      expect(tester.widget<FadeTransition>(fade()).opacity.value, 1);
      final daftar = find.byType(ListView);
      await tester.drag(daftar, const Offset(0, 2500));
      await tester.pumpAndSettle();
      await tester.drag(daftar, const Offset(0, -5000));
      await tester.pump();
      expect(tester.widget<FadeTransition>(fade()).opacity.value, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

class _PesananUji extends PesananBloc {
  _PesananUji() : super(pembayaran: const PembayaranTiruan()) {
    emit([
      {
        'id': 'uji',
        'mitra': 'Mitra',
        'kode': 'SR-UJI',
        'status': StatusPesanan.disiapkan,
        'dibayarPada': DateTime.now(),
      },
    ]);
  }
}

class _ChatUji implements LayananPercakapan {
  final stream = StreamController<KejadianPercakapan>.broadcast();
  Map<String, dynamic> pesan(int i) => {
    'id': '$i',
    'idPesanan': 'uji',
    'teks': 'Pesan $i',
    'peran': 'pembeli',
    'status': 'terkirim',
    'waktu': DateTime(2026, 10, 21, 12, i),
  };
  @override
  Stream<KejadianPercakapan> get kejadian => stream.stream;
  @override
  Future<List<Map<String, dynamic>>> riwayat(String idPesanan) async =>
      List.generate(30, pesan);
  @override
  Future<void> kirim(Map<String, dynamic> pesan) async {}
  @override
  Future<void> tandaiDibaca(String idPesanan, String oleh) async {}
}
