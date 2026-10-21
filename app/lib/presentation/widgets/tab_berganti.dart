import 'package:flutter/widgets.dart';
import 'package:sisa_rasa/core/theme/warna.dart';

/// isi tab bawah (pembeli & mitra). semua tab tetap hidup biar scroll-nya
/// ga ke-reset, tab yg baru dipilih muncul pelan: memudar masuk sambil naik
/// sedikit, kayak pindah tab di Gojek
class TabBerganti extends StatelessWidget {
  const TabBerganti({required this.indeks, required this.anak, super.key});

  final int indeks;
  final List<Widget> anak;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final (i, isi) in anak.indexed)
          KeyedSubtree(
            key: ValueKey('$i-${Warna.modeGelap}'),
            child: _SatuTab(aktif: i == indeks, child: isi),
          ),
      ],
    );
  }
}

class _SatuTab extends StatefulWidget {
  const _SatuTab({required this.aktif, required this.child});

  final bool aktif;
  final Widget child;

  @override
  State<_SatuTab> createState() => _SatuTabState();
}

class _SatuTabState extends State<_SatuTab>
    with SingleTickerProviderStateMixin {
  late final _gerak = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: widget.aktif ? 1 : 0,
  );
  late final _halus = CurvedAnimation(
    parent: _gerak,
    curve: Curves.easeOutCubic,
  );
  late final _geser = Tween(
    begin: const Offset(0, 0.015),
    end: Offset.zero,
  ).animate(_halus);

  @override
  void didUpdateWidget(_SatuTab lama) {
    super.didUpdateWidget(lama);
    if (widget.aktif && !lama.aktif) _gerak.forward(from: 0);
    if (!widget.aktif) _gerak.value = 0;
  }

  @override
  void dispose() {
    _halus.dispose();
    _gerak.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Offstage: tab yg ga aktif ga digambar dan ga bisa disentuh, tapi isinya tetap
    return Offstage(
      offstage: !widget.aktif,
      child: TickerMode(
        enabled: widget.aktif,
        child: FadeTransition(
          opacity: _halus,
          child: SlideTransition(position: _geser, child: widget.child),
        ),
      ),
    );
  }
}
