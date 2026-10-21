import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisa_rasa/data/repositories/akun_tiruan.dart';
import 'package:sisa_rasa/data/repositories/paket_lokal.dart';
import 'package:sisa_rasa/presentation/cubit/akun_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/keranjang_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/paket_cubit.dart';
import 'package:sisa_rasa/presentation/screens/beranda.dart';
import 'package:sisa_rasa/presentation/screens/cari.dart';
import 'package:sisa_rasa/presentation/screens/mitra/profil_usaha.dart';
import 'package:sisa_rasa/presentation/widgets/kartu_paket.dart';

import 'bantu_lokasi.dart';

void main() {
  group('KartuPaket - Badge Meja Berbagi (F-22)', () {
    testWidgets(
      'menampilkan badge Meja Berbagi jika mejaBerbagi bernilai true',
      (tester) async {
        final paket = {
          'id': 'test-1',
          'nama': 'Nasi Bungkus Peduli',
          'mitra': 'Dapur Berkah',
          'hargaAsli': 20000,
          'hargaDiskon': 0,
          'sisaPorsi': 3,
          'mulai': 12 * 60,
          'tutup': 18 * 60,
          'mejaBerbagi': true,
          'foto': 'assets/images/paket/croissant.jpg',
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MultiBlocProvider(
                providers: [lokasiUji()],
                child: KartuPaket(paket: paket, onTap: () {}),
              ),
            ),
          ),
        );

        expect(find.text('Meja Berbagi'), findsOneWidget);
      },
    );

    testWidgets(
      'tidak menampilkan badge Meja Berbagi jika false atau tidak ada',
      (tester) async {
        final paket = {
          'id': 'test-2',
          'nama': 'Roti Croissant',
          'mitra': 'Bakery Enak',
          'hargaAsli': 25000,
          'hargaDiskon': 12000,
          'sisaPorsi': 2,
          'mulai': 12 * 60,
          'tutup': 18 * 60,
          'mejaBerbagi': false,
          'foto': 'assets/images/paket/croissant.jpg',
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MultiBlocProvider(
                providers: [lokasiUji()],
                child: KartuPaket(paket: paket, onTap: () {}),
              ),
            ),
          ),
        );

        expect(find.text('Meja Berbagi'), findsNothing);
      },
    );
  });

  group('Cari (F-04) - Filter stok & gerai buka', () {
    testWidgets('hanya menampilkan paket yang buka dan sisa porsi > 0', (
      tester,
    ) async {
      final paketCubit = PaketCubit(layanan: PaketLokal());
      await paketCubit.muat();

      // Tambah paket habis (sisaPorsi 0)
      paketCubit.tambahPaket({
        'mitra': 'Ibis Hotel',
        'nama': 'Paket Habis Terjual',
        'deskripsi': '',
        'kategori': 'Hidangan utama',
        'hargaAsli': 30000,
        'hargaDiskon': 10000,
        'totalPorsi': 0,
        'mulai': 10 * 60,
        'tutup': 22 * 60,
        'mejaBerbagi': false,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: paketCubit),
              lokasiUji(),
            ],
            child: Cari(onBukaPaket: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Paket habis tidak boleh muncul
      expect(find.text('Paket Habis Terjual'), findsNothing);

      // Cari paket yang ada
      await tester.enterText(find.byType(TextField), 'Breakfast');
      await tester.pumpAndSettle();

      expect(find.text('American Breakfast Set'), findsOneWidget);

      await paketCubit.close();
    });
  });

  group('Beranda (F-03) - Urutkan & Saring', () {
    testWidgets('membuka modal filter dan menampilkan opsi filter', (
      tester,
    ) async {
      final paketCubit = PaketCubit(layanan: PaketLokal());
      await paketCubit.muat();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: paketCubit),
                // ikon keranjang di bilah atas beranda butuh KeranjangCubit
                BlocProvider(create: (_) => KeranjangCubit()),
                lokasiUji(),
              ],
              child: Beranda(onBukaMitra: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tekan tombol urutkan & saring
      final tombolFilter = find.byIcon(Icons.tune);
      expect(tombolFilter, findsOneWidget);
      await tester.tap(tombolFilter);
      await tester.pumpAndSettle();

      // Cek isi modal bottom sheet
      expect(find.text('Urutkan & Saring'), findsOneWidget);
      expect(find.text('Jam tutup terdekat'), findsOneWidget);
      expect(find.text('Harga termurah'), findsOneWidget);
      expect(find.text('Diskon terbesar'), findsOneWidget);
      expect(find.text('≤ Rp25rb'), findsOneWidget);
      expect(find.text('Bisa diambil sekarang'), findsOneWidget);
      // donasi bukan dari pembeli, halal udah keliatan di halaman mitra
      expect(find.text('Meja Berbagi (Donasi)'), findsNothing);
      expect(find.text('Terapkan'), findsOneWidget);

      // Tutup sheet dengan tap Terapkan
      await tester.tap(find.text('Terapkan'));
      await tester.pumpAndSettle();

      expect(find.text('Urutkan & Saring'), findsNothing);

      await paketCubit.close();
    });
  });

  group('Profil Usaha Mitra (F-64)', () {
    testWidgets('menampilkan info gerai mitra terdaftar secara read-only', (
      tester,
    ) async {
      final akunCubit = AkunCubit(
        layanan: AkunTiruan(),
        awal: const {
          'id': 'm1',
          'nama': 'Ibis Hotel',
          'email': 'ibis@gmail.com',
          'peran': 'mitra',
          'token': 'tok-m1',
        },
      );
      final paketCubit = PaketCubit(layanan: PaketLokal());
      await paketCubit.muat();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              lokasiUji(),
              BlocProvider.value(value: akunCubit),
              BlocProvider.value(value: paketCubit),
            ],
            child: const ProfilUsaha(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Profil Usaha'), findsOneWidget);
      expect(find.text('Informasi Gerai'), findsOneWidget);
      expect(find.text('Ibis Hotel'), findsWidgets);
      expect(find.text('Terverifikasi Aktif'), findsOneWidget);

      await akunCubit.close();
      await paketCubit.close();
    });
  });
}
