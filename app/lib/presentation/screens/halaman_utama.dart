import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/presentation/widgets/navigasi_bawah.dart';

/// halaman induk, yg punya navigation bar (beranda, pesanan, akun)
/// isi tiap tab sama tab yg aktif diatur router (StatefulShellRoute di router.dart),
/// di sini tinggal gambar navigasi bawah
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

  @override
  Widget build(BuildContext context) {
    // 0 beranda, 1 pesanan, 2 akun
    final tabAktif = shell.currentIndex;

    // Scaffold: kerangka halaman, ada body sama bottomNavigationBar.
    // isi tab berhenti di atas navigasi, snackbar muncul di atasnya
    return Scaffold(
      body: shell,
      // keranjang pindah jadi ikon di kanan atas beranda (TombolKeranjang)
      bottomNavigationBar: NavigasiBawah(
        tabs: _tabs,
        tabAktif: tabAktif,
        // pencet tab yg lagi aktif = balik ke halaman awal tab itu
        onPilih: (index) =>
            shell.goBranch(index, initialLocation: index == tabAktif),
      ),
    );
  }
}
