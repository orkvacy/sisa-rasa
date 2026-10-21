import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/data/sumber/dummy_akun.dart';
import 'package:sisa_rasa/domain/aturan/jarak.dart';
import 'package:sisa_rasa/domain/repositories/layanan_lokasi.dart';
import 'package:sisa_rasa/injection.dart';
import 'package:sisa_rasa/main.dart';
import 'package:sisa_rasa/presentation/cubit/lokasi_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/paket_cubit.dart';
import 'package:sisa_rasa/presentation/router.dart';

import 'bantu_lokasi.dart';

/// persis di depan Teras Nusantara (data contoh)
const _diTeras = Posisi(-0.46550, 117.15550);

Future<void> _pakaiLokasi(Posisi? posisi) async {
  await sl.unregister<LayananLokasi>();
  sl.registerSingleton<LayananLokasi>(LokasiUji(posisi));
}

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await sl.reset();
    daftarkanDependensi();
  });

  test('rumus jarak + teksnya', () {
    // Ibis -> Prime Cut di data contoh: sekitar 1,7 km
    final km = jarakKm(-0.49890, 117.14970, -0.48430, 117.14300);
    expect(km, closeTo(1.79, 0.05));
    expect(jarakKm(1, 2, 1, 2), 0);
    expect(teksJarak(0.012), '50 m');
    expect(teksJarak(0.349), '350 m');
    expect(teksJarak(0.999), '1 km');
    expect(teksJarak(1.26), '1,3 km');
    expect(teksJarak(12.4), '12 km');
  });

  test('izin belum ada: dibuka diam-diam ga nampilin galat, ditekan baru kasih tau', () async {
    final cubit = LokasiCubit(layanan: const LokasiUji());
    await cubit.mulai();
    expect(cubit.state['status'], 'belum');
    await cubit.aktifkan();
    expect(cubit.state['status'], 'gagal');
    expect(cubit.state['pesan'], 'Izin lokasi belum diberikan.');
    // jarak tetap pakai teks bawaan gerai
    expect(
      cubit.teks({'jarak': '1,9 km', 'lat': -0.49, 'lng': 117.1}),
      '1,9 km',
    );
    await cubit.close();
  });

  testWidgets('lokasi aktif: jarak dari GPS, urut terdekat', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pakaiLokasi(_diTeras);
    await tester.pumpWidget(SisaRasaApp(akunAwal: dummyAkun.first));
    await tester.pumpAndSettle();

    expect(find.text('Di sekitarmu'), findsOneWidget);
    // Teras Nusantara di depan mata: 50 m, bukan teks bawaan "0,8 km"
    expect(find.textContaining('Restoran · 50 m'), findsOneWidget);

    await tester.tap(find.byTooltip('Urutkan dan saring'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terdekat'));
    await tester.tap(find.text('Terapkan'));
    await tester.pumpAndSettle();
    // di Mitra sekitar, Teras paling atas
    final teras = tester.getTopLeft(find.text('Teras Nusantara').last).dy;
    final bumi = tester.getTopLeft(find.text('Bumi Senyiur').last).dy;
    expect(teras, lessThan(bumi));
  });

  testWidgets('belum ada izin: tombol aktifkan lokasi, ditekan kasih tau', (
    tester,
  ) async {
    await _pakaiLokasi(null);
    await tester.pumpWidget(SisaRasaApp(akunAwal: dummyAkun.first));
    await tester.pumpAndSettle();
    expect(find.text('Aktifkan lokasi'), findsOneWidget);
    // jarak bawaan gerai tetap tampil
    expect(find.textContaining('Restoran · 0,8 km'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tombol-lokasi')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lokasi-gps')));
    await tester.pumpAndSettle();
    expect(find.text('Izin lokasi belum diberikan.'), findsOneWidget);
  });

  testWidgets('mitra pasang titik gerai dari lokasi saat ini', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pakaiLokasi(const Posisi(-0.5, 117.15));
    final mitra = dummyAkun.firstWhere((a) => a['peran'] == 'mitra');
    await tester.pumpWidget(SisaRasaApp(akunAwal: mitra));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .push(Rute.mitraProfilUsaha);
    await tester.pumpAndSettle();
    expect(find.text('Terpasang'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pasang-titik')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Pasang'));
    await tester.pumpAndSettle();
    expect(find.text('Titik gerai disimpan'), findsOneWidget);
    final paket = tester
        .element(find.byType(Scaffold).first)
        .read<PaketCubit>()
        .state
        .firstWhere((p) => p['mitra'] == mitra['nama']);
    expect(paket['lat'], -0.5);
    expect(paket['lng'], 117.15);
  });
}
