import 'package:flutter/material.dart';

/// satu tab di navigasi melayang
class TabNavigasi {
  const TabNavigasi({
    required this.label,
    required this.ikon,
    required this.ikonAktif,
  });

  final String label;
  final IconData ikon;
  final IconData ikonAktif;
}

/// navigasi bawah berbentuk pil yg ngambang di tengah layar (figma v3),
/// gantinya NavigationBar yg selebar layar
class NavigasiMelayang extends StatelessWidget {
  const NavigasiMelayang({
    required this.tabs,
    required this.tabAktif,
    required this.onPilih,
    super.key,
  });

  /// ruang yg harus disisain di bawah daftar biar item terakhir ga ketutup navigasi
  static const ruangBawah = 104.0;

  /// sama, tapi kalau bar keranjang lagi muncul di atas navigasi
  static const ruangBawahKeranjang = 170.0;

  static const _lebar = 274.0;

  final List<TabNavigasi> tabs;
  final int tabAktif;
  final ValueChanged<int> onPilih;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gelap = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _lebar),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: cs.outlineVariant),
            // mode gelap: ga pake bayangan, dibedain lewat warna permukaan
            boxShadow: gelap
                ? null
                : [
                    BoxShadow(
                      color: cs.onSurface.withValues(alpha: 0.06),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                    BoxShadow(
                      color: cs.onSurface.withValues(alpha: 0.07),
                      blurRadius: 24,
                      spreadRadius: -4,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _ItemTab(
                    tab: tabs[i],
                    aktif: i == tabAktif,
                    onTap: () => onPilih(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemTab extends StatelessWidget {
  const _ItemTab({required this.tab, required this.aktif, required this.onTap});

  final TabNavigasi tab;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final warna = aktif ? cs.primary : cs.onSurfaceVariant;

    // Semantics: biar screen reader tau ini tombol tab dan lagi kepilih atau engga
    return Semantics(
      button: true,
      selected: aktif,
      label: tab.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          // tinggi 52 (>= 48 dp) buat area sentuh
          height: 52,
          decoration: BoxDecoration(
            color: aktif ? cs.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(aktif ? tab.ikonAktif : tab.ikon, size: 22, color: warna),
              const SizedBox(height: 2),
              Text(
                tab.label,
                style: TextStyle(
                  fontSize: 12,
                  height: 14 / 12,
                  fontWeight: aktif ? FontWeight.w700 : FontWeight.w600,
                  color: warna,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
