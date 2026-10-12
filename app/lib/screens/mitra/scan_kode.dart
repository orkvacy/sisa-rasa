import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sisa_rasa/router.dart';
import 'package:sisa_rasa/screens/mitra/ketik_kode.dart';
import 'package:sisa_rasa/theme/warna.dart';

/// pindai QR kode ambil pakai kamera (figma v3: mitra/scan qr, F-20).
/// QR di HP pembeli isinya kode ambil (SR-xxxx), lihat layar KodeAmbil
class ScanKode extends StatefulWidget {
  const ScanKode({super.key});

  @override
  State<ScanKode> createState() => _ScanKodeState();
}

class _ScanKodeState extends State<ScanKode> {
  final kamera = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  // dikunci selama lembar "Kode cocok" kebuka, biar QR yg sama ga kebaca berkali-kali
  bool memproses = false;
  bool senter = false;

  @override
  void dispose() {
    kamera.dispose();
    super.dispose();
  }

  Future<void> terbaca(BarcodeCapture tangkapan) async {
    final isi = tangkapan.barcodes.firstOrNull?.rawValue;
    if (memproses || isi == null) return;
    memproses = true;
    HapticFeedback.mediumImpact();

    final hasil = cariKode(context, isi);
    if (hasil.pesanan == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(hasil.galat!)));
      // kasih jeda biar QR yg salah ga langsung kebaca lagi
      await Future<void>.delayed(const Duration(seconds: 2));
      memproses = false;
      return;
    }

    await kamera.stop();
    if (!mounted) return;
    final serahkan = await konfirmasiSerahkan(context, hasil.pesanan!);
    if (!mounted) return;
    if (serahkan) {
      selesaikanPesanan(context, hasil.pesanan!);
      context.pop();
      return;
    }
    // pindai kode lain
    await kamera.start();
    memproses = false;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: kamera,
              onDetect: terbaca,
              // kamera ga bisa dibuka (izin ditolak / ga ada kamera): arahin ke ketik kode
              errorBuilder: (context, galat) => _KameraGagal(
                pesan:
                    galat.errorCode == MobileScannerErrorCode.permissionDenied
                    ? 'Izin kamera ditolak. Izinkan di pengaturan HP, atau ketik kodenya.'
                    : 'Kamera tidak bisa dibuka. Ketik kodenya saja.',
              ),
            ),
            // bingkai bidik + arahan
            IgnorePointer(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomPaint(
                      size: const Size(240, 240),
                      painter: _SudutBidik(),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Arahkan ke kode QR di HP pembeli',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            // tombol tutup + senter di atas
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    _TombolBulat(
                      tooltip: 'Tutup',
                      ikon: Icons.close,
                      onPressed: () => context.pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'Scan kode ambil',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _TombolBulat(
                      tooltip: senter ? 'Matikan senter' : 'Nyalakan senter',
                      ikon: senter ? Icons.flash_on : Icons.flash_off,
                      onPressed: () async {
                        await kamera.toggleTorch();
                        if (mounted) setState(() => senter = !senter);
                      },
                    ),
                  ],
                ),
              ),
            ),
            // ketik kode kalau QR ga kebaca (F-46)
            Positioned(
              left: 0,
              right: 0,
              bottom: 32 + MediaQuery.of(context).padding.bottom,
              child: Center(
                child: FilledButton.icon(
                  onPressed: () => context.pushReplacement(Rute.mitraKetikKode),
                  icon: const Icon(Icons.keyboard_outlined),
                  label: const Text('Ketik kode'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Warna.teks,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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

class _TombolBulat extends StatelessWidget {
  const _TombolBulat({
    required this.tooltip,
    required this.ikon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData ikon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(ikon, color: Colors.white),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.2),
        fixedSize: const Size(44, 44),
      ),
    );
  }
}

class _KameraGagal extends StatelessWidget {
  const _KameraGagal({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white70,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                pesan,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// empat sudut putih bingkai bidik
class _SudutBidik extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cat = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const p = 36.0;
    final w = size.width;
    final h = size.height;
    canvas
      ..drawPath(
        Path()
          ..moveTo(0, p)
          ..lineTo(0, 0)
          ..lineTo(p, 0),
        cat,
      )
      ..drawPath(
        Path()
          ..moveTo(w - p, 0)
          ..lineTo(w, 0)
          ..lineTo(w, p),
        cat,
      )
      ..drawPath(
        Path()
          ..moveTo(0, h - p)
          ..lineTo(0, h)
          ..lineTo(p, h),
        cat,
      )
      ..drawPath(
        Path()
          ..moveTo(w - p, h)
          ..lineTo(w, h)
          ..lineTo(w, h - p),
        cat,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
