import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/cubit/keranjang_cubit.dart';
import 'package:sisa_rasa/cubit/paket_cubit.dart';
import 'package:sisa_rasa/router.dart';
import 'package:sisa_rasa/widgets/bar_keranjang.dart';
import 'package:sisa_rasa/widgets/navigasi_melayang.dart';

/// halaman induk, yg punya navigation bar (beranda, pesanan, akun)
/// isi tiap tab sama tab yg aktif diatur router (StatefulShellRoute di router.dart),
/// di sini tinggal gambar navigasi melayang sama bar keranjang
class HalamanUtama extends StatelessWidget {
  const HalamanUtama({required this.shell, super.key});

  // shell: isi tab yg lagi aktif, plus fungsi buat pindah tab
  final StatefulNavigationShell shell;

  static const _tabs = [
    TabNavigasi(
      label: 'Beranda',
      ikon: Icons.home_outlined,
      ikonAktif: Icons.home,
    ),
    TabNavigasi(
      label: 'Pesanan',
      ikon: Icons.receipt_long_outlined,
      ikonAktif: Icons.receipt_long,
    ),
    TabNavigasi(
      label: 'Akun',
      ikon: Icons.person_outline,
      ikonAktif: Icons.person,
    ),
  ];

  void bukaKeranjang(BuildContext context) {
    // snackbar "masuk keranjang" ditutup dulu biar ga nutupin tombol checkout
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    context.push(Rute.keranjang);
  }

  @override
  Widget build(BuildContext context) {
    // 0 beranda, 1 pesanan, 2 akun
    final tabAktif = shell.currentIndex;

    // Scaffold: kerangka halaman, ada body sama bottomNavigationBar
    return Scaffold(
      // extendBody: halaman tab nerusin sampe belakang navigasi melayang,
      // snackbar tetep muncul di atas navigasi karena navigasinya bottomNavigationBar
      extendBody: true,
      // shell: tab yg aktif, tab lain ga di-reset (scroll nya tetep)
      body: shell,
      // bar keranjang sama navigasi melayang numpuk di bawah, latarnya transparan
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // BlocBuilder: cuma bagian ini yg digambar ulang tiap isi keranjang berubah
            BlocBuilder<KeranjangCubit, Map<String, int>>(
              builder: (context, keranjang) {
                // bar keranjang cuma muncul di beranda, itupun kalau keranjang ada isinya
                if (tabAktif != 0 || keranjang.isEmpty) {
                  // SizedBox: kotak ukuran tetap, .shrink() berarti ukurannya 0 jadi ga keliatan
                  return const SizedBox.shrink();
                }
                final paketCubit = context.read<PaketCubit>();
                final pertama = paketCubit.cari(keranjang.keys.first);
                var porsi = 0;
                var total = 0;
                for (final id in keranjang.keys) {
                  porsi += keranjang[id]!;
                  total +=
                      (paketCubit.cari(id)['hargaDiskon'] as int) *
                      keranjang[id]!;
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BarKeranjang(
                    foto: pertama['foto'],
                    jumlahPorsi: porsi,
                    total: total,
                    onTap: () => bukaKeranjang(context),
                  ),
                );
              },
            ),
            // NavigasiMelayang: navigasi bawah buat pindah halaman utama
            NavigasiMelayang(
              tabs: _tabs,
              tabAktif: tabAktif,
              // pencet tab yg lagi aktif = balik ke halaman awal tab itu
              onPilih: (index) =>
                  shell.goBranch(index, initialLocation: index == tabAktif),
            ),
          ],
        ),
      ),
    );
  }
}
