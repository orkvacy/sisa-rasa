import 'package:flutter/widgets.dart';

Duration durasiGerak(BuildContext context, [int milidetik = 220]) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: milidetik);

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
  const GantiHalus({
    required this.kunci,
    required this.child,
    this.geser = const Offset(0, 0.02),
    super.key,
  });

  final Object kunci;
  final Widget child;
  final Offset geser;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      // isi lama + baru ditumpuk dari atas, biar daftar ga loncat ke tengah
      layoutBuilder: (sekarang, sebelumnya) => Stack(
        alignment: Alignment.topCenter,
        children: [
          for (final lama in sebelumnya)
            ExcludeSemantics(child: IgnorePointer(child: lama)),
          ?sekarang,
        ],
      ),
      transitionBuilder: (anak, gerak) => FadeTransition(
        opacity: gerak,
        child: SlideTransition(
          position: Tween(begin: geser, end: Offset.zero).animate(gerak),
          child: anak,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(kunci), child: child),
    );
  }
}

/// Hanya berjalan saat dipasang, bukan saat nilai/status anak diperbarui.
class MunculSekali extends StatefulWidget {
  const MunculSekali({
    required this.child,
    this.animasi = true,
    this.centang = false,
    this.onMulai,
    super.key,
  });

  final Widget child;
  final bool animasi;
  final bool centang;
  final VoidCallback? onMulai;

  @override
  State<MunculSekali> createState() => _MunculSekaliState();
}

class _MunculSekaliState extends State<MunculSekali>
    with SingleTickerProviderStateMixin {
  late final _gerak = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.centang ? 420 : 220),
  );
  late final _halus = CurvedAnimation(
    parent: _gerak,
    curve: Curves.easeOutCubic,
  );
  bool _dimulai = false;
  bool _pernahAnimasi = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dimulai) {
      _dimulai = true;
      _pernahAnimasi = widget.animasi;
      if (widget.animasi && !MediaQuery.disableAnimationsOf(context)) {
        _gerak.forward();
      } else {
        _gerak.value = 1;
      }
      widget.onMulai?.call();
    } else if (MediaQuery.disableAnimationsOf(context)) {
      _gerak.value = 1;
    }
  }

  @override
  void didUpdateWidget(MunculSekali oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animasi && !_pernahAnimasi) {
      _pernahAnimasi = true;
      if (MediaQuery.disableAnimationsOf(context)) {
        _gerak.value = 1;
      } else {
        _gerak.forward(from: 0);
      }
      widget.onMulai?.call();
    }
  }

  @override
  void dispose() {
    _halus.dispose();
    _gerak.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _halus,
    child: widget.centang
        ? ScaleTransition(
            scale: Tween(begin: 0.65, end: 1.0).animate(_halus),
            child: widget.child,
          )
        : SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(_halus),
            child: widget.child,
          ),
  );
}

/// Data sudah dihapus; salinan tampilannya dipertahankan sampai selesai menyusut.
class SusutSaatDihapus extends StatefulWidget {
  const SusutSaatDihapus({
    required this.ada,
    required this.onHilang,
    required this.child,
    super.key,
  });
  final bool ada;
  final VoidCallback onHilang;
  final Widget child;

  @override
  State<SusutSaatDihapus> createState() => _SusutSaatDihapusState();
}

class _SusutSaatDihapusState extends State<SusutSaatDihapus>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late final _gerak =
      AnimationController(
        vsync: this,
        value: 1,
        duration: const Duration(milliseconds: 220),
      )..addStatusListener((status) {
        if (status == AnimationStatus.dismissed) {
          // Aman juga ketika reduced motion menyelesaikan animasi saat build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !widget.ada) widget.onHilang();
          });
        }
      });
  late final _halus = CurvedAnimation(parent: _gerak, curve: Curves.easeInOut);
  bool _kurangi = false;

  void _atur() {
    if (_kurangi) {
      _gerak.value = widget.ada ? 1 : 0;
    } else if (widget.ada) {
      _gerak.forward();
    } else {
      _gerak.reverse();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _kurangi = MediaQuery.disableAnimationsOf(context);
    _atur();
  }

  @override
  void didUpdateWidget(SusutSaatDihapus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ada != widget.ada) _atur();
  }

  @override
  void dispose() {
    _halus.dispose();
    _gerak.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ExcludeSemantics(
      excluding: !widget.ada,
      child: IgnorePointer(
        ignoring: !widget.ada,
        child: SizeTransition(
          sizeFactor: _halus,
          alignment: Alignment.topCenter,
          child: FadeTransition(opacity: _halus, child: widget.child),
        ),
      ),
    );
  }
}
