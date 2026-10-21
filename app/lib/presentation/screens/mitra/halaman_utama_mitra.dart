import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/presentation/cubit/akun_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/saldo_cubit.dart';
import 'package:sisa_rasa/presentation/router.dart';
import 'package:sisa_rasa/core/theme/warna.dart';
import 'package:sisa_rasa/presentation/widgets/navigasi_bawah.dart';

/// induk tab mitra: Dasbor, Paket, tombol pindai di tengah, Pesanan, Saldo
class HalamanUtamaMitra extends StatefulWidget {
  const HalamanUtamaMitra({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  State<HalamanUtamaMitra> createState() => _HalamanUtamaMitraState();
}

class _HalamanUtamaMitraState extends State<HalamanUtamaMitra> {
  StatefulNavigationShell get shell => widget.shell;

  @override
  void initState() {
    super.initState();
    // rekening + riwayat saldo diambil sekali pas masuk ke halaman mitra
    final mitra = context.read<AkunCubit>().state['nama'];
    if (mitra != null) context.read<SaldoCubit>().muat(mitra);
  }

  static const _tab = [
    TabNavigasi(
      label: 'Dasbor',
      ikon: Icons.home_outlined,
      ikonAktif: Icons.home,
    ),
    TabNavigasi(
      label: 'Paket',
      ikon: Icons.inventory_2_outlined,
      ikonAktif: Icons.inventory_2,
    ),
    TabNavigasi(
      label: 'Pesanan',
      ikon: Icons.receipt_long_outlined,
      ikonAktif: Icons.receipt_long,
    ),
    TabNavigasi(
      label: 'Saldo',
      ikon: Icons.account_balance_wallet_outlined,
      ikonAktif: Icons.account_balance_wallet,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigasiBawah(
        tabs: _tab,
        tabAktif: shell.currentIndex,
        // pencet tab yg lagi aktif = balik ke halaman awal tab itu
        onPilih: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        // tombol bulat hijau di tengah buat pindai kode ambil
        tengah: Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Warna.kartu,
            shape: BoxShape.circle,
          ),
          child: SizedBox(
            width: 56,
            height: 56,
            child: IconButton.filled(
              tooltip: 'Pindai kode ambil',
              onPressed: () => context.push(Rute.mitraScan),
              icon: const Icon(Icons.qr_code_scanner, size: 26),
              style: IconButton.styleFrom(
                backgroundColor: Warna.hijau,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
