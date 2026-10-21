import 'package:flutter/material.dart';
import 'package:sisa_rasa/core/theme/warna.dart';

/// satu tab di navigasi bawah
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

/// navigasi bawah selebar layar kayak Gojek / Kopi Kenangan / Fore.
/// tab yg dipilih: garis kecil di atas ikon melebar, ikonnya mantul sedikit.
/// [tengah] (tombol pindai mitra) nongol bulat di tengah, setengahnya
/// di atas garis navigasi
class NavigasiBawah extends StatelessWidget {
  const NavigasiBawah({
    required this.tabs,
    required this.tabAktif,
    required this.onPilih,
    this.tengah,
    super.key,
  });

  /// ruang di bawah daftar biar item terakhir ga mepet navigasi. isi tab
  /// berhenti di atas navigasi (ga extendBody), jadi cukup napas sedikit
  static const ruangBawah = 24.0;

  static const _tinggi = 64.0;

  final List<TabNavigasi> tabs;
  final int tabAktif;
  final ValueChanged<int> onPilih;
  final Widget? tengah;

  @override
  Widget build(BuildContext context) {
    final item = <Widget>[
      for (final (i, tab) in tabs.indexed) ...[
        // ruang kosong buat tombol tengah
        if (tengah != null && i == tabs.length ~/ 2) const SizedBox(width: 72),
        Expanded(
          child: _ItemTab(
            tab: tab,
            aktif: i == tabAktif,
            onTap: () => onPilih(i),
          ),
        ),
      ],
    ];

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Warna.kartu,
            border: const Border(top: BorderSide(color: Warna.garis)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          // putihnya nerus sampai area gestur HP, isinya tetap di atasnya
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: _tinggi,
              child: Row(children: item),
            ),
          ),
        ),
        if (tengah != null) Positioned(top: -22, child: tengah!),
      ],
    );
  }
}

class _ItemTab extends StatefulWidget {
  const _ItemTab({required this.tab, required this.aktif, required this.onTap});

  final TabNavigasi tab;
  final bool aktif;
  final VoidCallback onTap;

  @override
  State<_ItemTab> createState() => _ItemTabState();
}

class _ItemTabState extends State<_ItemTab>
    with SingleTickerProviderStateMixin {
  // mantul: 1 -> 1.18 -> 1 pas tab ini baru dipilih
  late final _mantul = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final _skala = TweenSequence([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.18,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.18,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOutBack)),
      weight: 60,
    ),
  ]).animate(_mantul);

  @override
  void didUpdateWidget(_ItemTab lama) {
    super.didUpdateWidget(lama);
    if (widget.aktif && !lama.aktif) _mantul.forward(from: 0);
  }

  @override
  void dispose() {
    _mantul.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aktif = widget.aktif;
    final warna = aktif ? Warna.hijau : Warna.teksPendukung;

    // Semantics: biar screen reader tau ini tombol tab dan lagi kepilih atau engga
    return Semantics(
      button: true,
      selected: aktif,
      label: widget.tab.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: widget.onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        child: Column(
          children: [
            // garis penanda tab aktif, melebar dari tengah
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: aktif ? 28 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: Warna.hijau,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const Spacer(),
            ScaleTransition(
              scale: _skala,
              child: Icon(
                aktif ? widget.tab.ikonAktif : widget.tab.ikon,
                size: 24,
                color: warna,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                height: 14 / 11,
                fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                color: warna,
              ),
              child: Text(
                widget.tab.label,
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
