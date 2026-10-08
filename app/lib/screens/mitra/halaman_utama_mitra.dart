import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/screens/mitra/ketik_kode.dart';
import 'package:sisa_rasa/theme/warna.dart';

/// induk tab mitra (figma v3): Dasbor, Paket, tombol pindai di tengah, Pesanan, Saldo
class HalamanUtamaMitra extends StatelessWidget {
  const HalamanUtamaMitra({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.only(bottom: 12),
        child: _NavigasiMitra(
          aktif: shell.currentIndex,
          // pencet tab yg lagi aktif = balik ke halaman awal tab itu
          onPilih: (i) =>
              shell.goBranch(i, initialLocation: i == shell.currentIndex),
          onPindai: () => bukaKetikKode(context),
        ),
      ),
    );
  }
}

/// pil putih selebar layar, 4 tab + tombol bulat hijau di tengah buat pindai kode
class _NavigasiMitra extends StatelessWidget {
  const _NavigasiMitra({
    required this.aktif,
    required this.onPilih,
    required this.onPindai,
  });

  final int aktif;
  final ValueChanged<int> onPilih;
  final VoidCallback onPindai;

  static const _tab = [
    (label: 'Dasbor', ikon: Icons.home_outlined, ikonAktif: Icons.home),
    (
      label: 'Paket',
      ikon: Icons.inventory_2_outlined,
      ikonAktif: Icons.inventory_2,
    ),
    (
      label: 'Pesanan',
      ikon: Icons.receipt_long_outlined,
      ikonAktif: Icons.receipt_long,
    ),
    (
      label: 'Saldo',
      ikon: Icons.account_balance_wallet_outlined,
      ikonAktif: Icons.account_balance_wallet,
    ),
  ];

  Widget _item(int i) {
    final tab = _tab[i];
    final dipilih = i == aktif;
    return Expanded(
      child: Semantics(
        button: true,
        selected: dipilih,
        label: tab.label,
        excludeSemantics: true,
        child: InkWell(
          onTap: () => onPilih(i),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: dipilih ? Warna.softGreen : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  dipilih ? tab.ikonAktif : tab.ikon,
                  size: 22,
                  color: dipilih ? Warna.teks : Warna.teksPendukung,
                ),
                const SizedBox(height: 2),
                Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    fontWeight: dipilih ? FontWeight.w700 : FontWeight.w500,
                    color: dipilih ? Warna.teks : Warna.teksPendukung,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: 84,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 70,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Warna.garis),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _item(0),
                  _item(1),
                  // ruang kosong buat tombol pindai yg nongol di tengah
                  const SizedBox(width: 72),
                  _item(2),
                  _item(3),
                ],
              ),
            ),
            Positioned(
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: IconButton.filled(
                    tooltip: 'Pindai kode ambil',
                    onPressed: onPindai,
                    icon: const Icon(Icons.qr_code_scanner, size: 26),
                    style: IconButton.styleFrom(
                      backgroundColor: Warna.hijau,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
