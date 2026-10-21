import 'package:flutter/material.dart';
import 'package:sisa_rasa/core/theme/warna.dart';

/// kotak abu pengganti isi yang masih dimuat (skeleton)
class Kerangka extends StatelessWidget {
  const Kerangka({
    this.lebar,
    required this.tinggi,
    this.radius = 8,
    super.key,
  });

  final double? lebar;
  final double tinggi;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: lebar,
      height: tinggi,
      decoration: BoxDecoration(
        color: Warna.kraft,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// kilau yang lewat dari kiri ke kanan di atas semua Kerangka di dalam [child].
/// mati sendiri kalau HP minta animasi dikurangi
class KilauKerangka extends StatefulWidget {
  const KilauKerangka({required this.child, super.key});

  final Widget child;

  @override
  State<KilauKerangka> createState() => _KilauKerangkaState();
}

class _KilauKerangkaState extends State<KilauKerangka>
    with SingleTickerProviderStateMixin {
  late final _gerak = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _gerak.stop();
    } else if (!_gerak.isAnimating) {
      _gerak.repeat();
    }
  }

  @override
  void dispose() {
    _gerak.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Memuat',
      child: AnimatedBuilder(
        animation: _gerak,
        child: widget.child,
        builder: (context, isi) {
          final t = _gerak.value * 3 - 1; // -1 .. 2, lewat sekali per putaran
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (kotak) => LinearGradient(
              begin: Alignment(t - 1, 0),
              end: Alignment(t, 0),
              colors: [Warna.kraft, Warna.kilau, Warna.kraft],
            ).createShader(kotak),
            child: isi,
          );
        },
      ),
    );
  }
}

/// isi ga bisa dimuat (ga ada jaringan / server gangguan) + tombol coba lagi
class GagalMuat extends StatelessWidget {
  const GagalMuat({
    required this.pesan,
    required this.onCobaLagi,
    this.judul = 'Gagal memuat',
    super.key,
  });

  final String judul;
  final String pesan;
  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
      child: Column(
        children: [
          Icon(Icons.wifi_off, size: 40, color: Warna.teksPendukung),
          const SizedBox(height: 12),
          Text(
            judul,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Warna.teks,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pesan,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Warna.teksPendukung),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const Key('coba-muat-lagi'),
            onPressed: onCobaLagi,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Coba lagi'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Warna.hijau,
              side: BorderSide(color: Warna.hijau),
              // tema bikin tombol outlined selebar layar, di sini seukuran isinya
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ],
      ),
    );
  }
}
