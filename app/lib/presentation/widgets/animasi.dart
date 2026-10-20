import 'package:flutter/widgets.dart';

/// animasi kecil yg dipake bareng di banyak layar biar rasanya seragam.
/// semuanya pake AnimationController (bukan Timer), jadi aman di widget test

/// kartu mengecil dikit pas jari nempel, balik lagi pas dilepas (kayak Gojek).
/// cuma efek, ketukannya tetap diurus InkWell / GestureDetector di dalam [child]
class TekanMengecil extends StatefulWidget {
  const TekanMengecil({required this.child, this.skala = 0.97, super.key});

  final Widget child;
  final double skala;

  @override
  State<TekanMengecil> createState() => _TekanMengecilState();
}

class _TekanMengecilState extends State<TekanMengecil> {
  bool ditekan = false;

  void _atur(bool nilai) {
    if (ditekan != nilai) setState(() => ditekan = nilai);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _atur(true),
      onPointerUp: (_) => _atur(false),
      onPointerCancel: (_) => _atur(false),
      child: AnimatedScale(
        scale: ditekan ? widget.skala : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// isi daftar muncul satu-satu: memudar masuk sambil naik dikit.
/// [urutan] posisi di daftar, makin bawah makin telat (dibatesin biar
/// daftar panjang ga kelamaan nunggu)
class MunculBertahap extends StatefulWidget {
  const MunculBertahap({required this.urutan, required this.child, super.key});

  final int urutan;
  final Widget child;

  @override
  State<MunculBertahap> createState() => _MunculBertahapState();
}

class _MunculBertahapState extends State<MunculBertahap>
    with SingleTickerProviderStateMixin {
  static const _jeda = 45;
  static const _lama = 320;

  late final int _tunda = widget.urutan.clamp(0, 8) * _jeda;
  late final _gerak = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _tunda + _lama),
  )..forward();
  // jeda di awal dibikin lewat Interval, jadi ga butuh Timer
  late final _halus = CurvedAnimation(
    parent: _gerak,
    curve: Interval(_tunda / (_tunda + _lama), 1, curve: Curves.easeOutCubic),
  );
  late final _geser = Tween(
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(_halus);

  @override
  void dispose() {
    _halus.dispose();
    _gerak.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _halus,
      child: SlideTransition(position: _geser, child: widget.child),
    );
  }
}

/// [child] mantul sekali tiap [nilai] berubah (angka keranjang, hati favorit)
class MantulSaatBerubah extends StatefulWidget {
  const MantulSaatBerubah({
    required this.nilai,
    required this.child,
    this.puncak = 1.25,
    super.key,
  });

  final Object? nilai;
  final Widget child;
  final double puncak;

  @override
  State<MantulSaatBerubah> createState() => _MantulSaatBerubahState();
}

class _MantulSaatBerubahState extends State<MantulSaatBerubah>
    with SingleTickerProviderStateMixin {
  late final _gerak = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );
  late final _skala = TweenSequence([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: widget.puncak,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: widget.puncak,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 65,
    ),
  ]).animate(_gerak);

  @override
  void didUpdateWidget(MantulSaatBerubah lama) {
    super.didUpdateWidget(lama);
    if (widget.nilai != lama.nilai) _gerak.forward(from: 0);
  }

  @override
  void dispose() {
    _gerak.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _skala, child: widget.child);
}

/// isi yg berganti (hasil saringan, status) diganti pelan: yg lama memudar,
/// yg baru masuk dari bawah dikit. [kunci] beda = isinya dianggap baru
class GantiHalus extends StatelessWidget {
  const GantiHalus({required this.kunci, required this.child, super.key});

  final Object kunci;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      // isi lama + baru ditumpuk dari atas, biar daftar ga loncat ke tengah
      layoutBuilder: (sekarang, sebelumnya) => Stack(
        alignment: Alignment.topCenter,
        children: [...sebelumnya, ?sekarang],
      ),
      transitionBuilder: (anak, gerak) => FadeTransition(
        opacity: gerak,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(gerak),
          child: anak,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(kunci), child: child),
    );
  }
}
