import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sisa_rasa/data/repositories/akun_api.dart';
import 'package:sisa_rasa/data/repositories/akun_tiruan.dart';
import 'package:sisa_rasa/data/sumber/dummy_akun.dart';
import 'package:sisa_rasa/domain/repositories/layanan_akun.dart';
import 'package:sisa_rasa/domain/repositories/layanan_lokasi.dart';
import 'package:sisa_rasa/injection.dart';
import 'package:sisa_rasa/main.dart';
import 'package:sisa_rasa/presentation/cubit/akun_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/lokasi_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/paket_cubit.dart';
import 'package:sisa_rasa/presentation/screens/pilih_titik.dart';
import 'package:sisa_rasa/presentation/router.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:sisa_rasa/data/sumber/dummy_deals.dart';
import 'package:sisa_rasa/presentation/widgets/avatar_akun.dart';

import 'bantu_lokasi.dart';

/// ganti sandi, foto profil, halaman akun mitra, swipe pesanan,
/// titik lokasi manual, jam ambil opsional, konfirmasi set habis
void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await sl.reset();
    daftarkanDependensi();
  });

  final mitra = dummyAkun.firstWhere((a) => a['nama'] == 'Ibis Hotel');

  test(
    'tiruan: ganti sandi cabut sesi lama, foto profil pasang / hapus',
    () async {
      final layanan = AkunTiruan();
      final rani = await layanan.masuk('rani.amelia@gmail.com', sandiUji);
      final lama = rani['token']!;

      expect(
        () => layanan.gantiSandi(lama, 'salah', 'sandibaru1'),
        throwsA(
          isA<GagalAkun>().having(
            (g) => g.pesan,
            'pesan',
            'Kata sandi lama salah.',
          ),
        ),
      );
      expect(
        () => layanan.gantiSandi(lama, sandiUji, 'pendek'),
        throwsA(isA<GagalAkun>()),
      );
      final baru = await layanan.gantiSandi(lama, sandiUji, 'sandibaru1');
      expect(baru['token'], isNot(lama));
      expect(await layanan.sesi(lama), isNull);
      expect(await layanan.sesi(baru['token']!), isNotNull);
      await layanan.masuk('rani.amelia@gmail.com', 'sandibaru1');

      final berfoto = await layanan.aturFoto(baru['token']!, '/tmp/rani.jpg');
      expect(berfoto['foto'], 'file:///tmp/rani.jpg');
      final tanpa = await layanan.hapusFoto(baru['token']!);
      expect(tanpa.containsKey('foto'), isFalse);
    },
  );

  test('AkunApi: ganti sandi + unggah foto ke jalur yang benar', () async {
    final diminta = <http.BaseRequest>[];
    final berkas = File('${Directory.systemTemp.path}/sisarasa-foto-uji.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    addTearDown(() => berkas.deleteSync());
    final api = AkunApi(
      alamat: 'https://api.tes',
      klien: MockClient.streaming((req, badan) async {
        diminta.add(req);
        final akun = {
          'id': 'a1',
          'nama': 'Rani',
          'email': 'rani@contoh.id',
          'peran': 'pembeli',
          'punyaSandi': true,
          'foto': 'https://foto/rani.jpg',
        };
        final isi = req.url.path == '/v1/akun/sandi'
            ? {'akun': akun, 'token': 'tok-baru'}
            : {'akun': akun};
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(isi))),
          200,
        );
      }),
    );
    final hasil = await api.gantiSandi('tok-1', 'lama123x', 'baru123x');
    expect(hasil['token'], 'tok-baru');
    expect(diminta.last.headers['Authorization'], 'Bearer tok-1');

    final foto = await api.aturFoto('tok-baru', berkas.path);
    expect(foto['foto'], 'https://foto/rani.jpg');
    expect(diminta.last.url.path, '/v1/akun/foto');
    expect(diminta.last, isA<http.MultipartRequest>());

    await api.hapusFoto('tok-baru');
    expect(diminta.last.method, 'DELETE');
  });

  testWidgets('ganti sandi dari tab akun', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final akun = AkunCubit(layanan: sl());
    await akun.masuk('rani.amelia@gmail.com', sandiUji);
    await tester.pumpWidget(SisaRasaApp(akun: akun));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akun').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kata sandi'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('sandi-lama')), 'salahsalah');
    await tester.enterText(find.byKey(const Key('sandi-baru')), 'sandibaru1');
    await tester.enterText(find.byKey(const Key('sandi-ulang')), 'sandibaru1');
    await tester.tap(find.byKey(const Key('simpan-sandi')));
    await tester.pumpAndSettle();
    expect(find.text('Kata sandi lama salah.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('sandi-lama')), sandiUji);
    await tester.tap(find.byKey(const Key('simpan-sandi')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Kata sandi diganti'), findsOneWidget);
    // HP ini tetap masuk pakai sesi baru
    expect(akun.sudahMasuk, isTrue);
    await akun.keluar();
    await akun.masuk('rani.amelia@gmail.com', 'sandibaru1');
  });

  testWidgets('foto profil tampil di tab akun, lembar profil bisa hapus', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final akun = AkunCubit(layanan: sl());
    await akun.masuk('rani.amelia@gmail.com', sandiUji);
    await akun.aturFoto('/tidak/ada.jpg');
    await tester.pumpWidget(SisaRasaApp(akun: akun));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akun').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<AvatarAkun>(find.byType(AvatarAkun).first).foto,
      'file:///tidak/ada.jpg',
    );

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hapus-foto')));
    await tester.pumpAndSettle();
    expect(akun.state['foto'], isNull);
    expect(find.byKey(const Key('hapus-foto')), findsNothing);
  });

  testWidgets('akun mitra dibuka dari dasbor punya latar halaman sendiri', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SisaRasaApp(akunAwal: mitra));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('akun-mitra')));
    await tester.pumpAndSettle();
    final kataSandi = find.text('Kata sandi');
    expect(kataSandi, findsOneWidget);
    // dulu tanpa Scaffold: latar hitam, teks merah bergaris kuning
    expect(
      find.ancestor(of: kataSandi, matching: find.byType(Scaffold)),
      findsWidgets,
    );
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('akun-mitra')), findsOneWidget);
  });

  testWidgets('tab pesanan bisa digeser ke segmen berikutnya', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SisaRasaApp(akunAwal: dummyAkun.first));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pesanan').last);
    await tester.pumpAndSettle();

    PageController halaman() =>
        tester.widget<PageView>(find.byType(PageView)).controller!;
    expect(halaman().page, 0);
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(halaman().page, 1);
    // ketuk segmen tetap jalan, halamannya ikut pindah
    await tester.tap(find.text('Dibatalkan'));
    await tester.pumpAndSettle();
    expect(halaman().page, 2);
  });

  testWidgets('pembeli pilih titik lokasi sendiri di peta', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await sl.unregister<LayananLokasi>();
    sl.registerSingleton<LayananLokasi>(const LokasiUji());
    await tester.pumpWidget(SisaRasaApp(akunAwal: dummyAkun.first));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tombol-lokasi')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lokasi-peta')));
    await tester.pumpAndSettle();
    expect(find.byType(PilihTitik), findsOneWidget);
    await tester.tap(find.byKey(const Key('pakai-titik')));
    await tester.pumpAndSettle();

    expect(find.text('Titik pilihanmu'), findsOneWidget);
    final lokasi = tester
        .element(find.byType(Scaffold).first)
        .read<LokasiCubit>();
    expect(lokasi.manual, isTrue);
    expect(lokasi.state['lat'], PilihTitik.samarinda.lat);
    // dibuka lagi diam-diam: titik manual ga ditimpa GPS
    await lokasi.mulai();
    expect(lokasi.manual, isTrue);
  });

  testWidgets('mitra pasang titik gerai lewat peta', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SisaRasaApp(akunAwal: mitra));
    await tester.pumpAndSettle();
    final c = tester.element(find.byType(Scaffold).first);
    GoRouter.of(c).push(Rute.mitraProfilUsaha);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('titik-peta')));
    await tester.pumpAndSettle();
    expect(find.byType(PilihTitik), findsOneWidget);
    // geser peta dikit, titiknya ikut pindah dari titik lama
    await tester.drag(find.byType(FlutterMap), const Offset(-80, 40));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pakai-titik')));
    await tester.pumpAndSettle();
    expect(find.text('Titik gerai disimpan'), findsOneWidget);

    final paket = c.read<PaketCubit>().state.firstWhere(
      (p) => p['mitra'] == mitra['nama'],
    );
    final lama = dummyDeals.firstWhere((p) => p['mitra'] == mitra['nama']);
    expect(paket['lat'], isNot(lama['lat']));
    expect(paket['lng'], isNot(lama['lng']));
  });

  testWidgets('set habis ditanya dulu, Tidak = sisa porsi tetap', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SisaRasaApp(akunAwal: mitra));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paket').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Tambah sisa American Breakfast Set'), findsNothing);

    final cubit = tester
        .element(find.byType(Scaffold).first)
        .read<PaketCubit>();
    final sarapan = cubit.state.firstWhere(
      (p) => p['nama'] == 'American Breakfast Set',
    );
    final tombol = find.byKey(Key('set-habis-${sarapan['id']}'));
    final sisaAwal = sarapan['sisaPorsi'];
    expect(sisaAwal, greaterThan(0));

    await tester.tap(tombol);
    await tester.pumpAndSettle();
    expect(find.text('Tandai paket habis?'), findsOneWidget);
    await tester.tap(find.text('Tidak'));
    await tester.pumpAndSettle();
    expect(cubit.cari(sarapan['id'])['sisaPorsi'], sisaAwal);

    await tester.tap(tombol);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('yakin-habis')));
    await tester.pumpAndSettle();
    expect(cubit.cari(sarapan['id'])['sisaPorsi'], 0);
  });

  testWidgets('paket baru tanpa jam ambil: bisa diambil sampai 23.59', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SisaRasaApp(akunAwal: mitra));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paket').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paket baru'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Roti Sisa Pagi');
    await tester.tap(find.text('Hidangan utama'));
    await tester.ensureVisible(find.text('Harga asli'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(2), '30000');
    await tester.enterText(find.byType(TextField).at(3), '12000');
    await tester.ensureVisible(find.text('Jam ambil hari ini (opsional)'));
    await tester.pumpAndSettle();
    expect(find.text('Sekarang'), findsOneWidget);
    await tester.tap(find.text('Terbitkan paket'));
    await tester.pumpAndSettle();

    final baru = tester
        .element(find.byType(Scaffold).first)
        .read<PaketCubit>()
        .state
        .firstWhere((p) => p['nama'] == 'Roti Sisa Pagi');
    expect(baru['mulai'], 0);
    expect(baru['tutup'], 24 * 60 - 1);
  });
}
