import 'package:flutter/material.dart';
import 'package:sisa_rasa/core/theme/warna.dart';

/// tombol + / - kecil buat ngatur porsi (kayak stepper GoFood).
/// lingkarannya 28, area sentuhnya 36 biar tetap gampang dipencet.
/// [penuh] = latar hijau (tombol tambah pertama), selain itu cuma garis hijau
class TombolJumlah extends StatelessWidget {
  const TombolJumlah({
    required this.ikon,
    required this.tooltip,
    required this.onPressed,
    this.penuh = false,
    super.key,
  });

  static const _lingkaran = 28.0;
  static const _sentuh = 36.0;

  final IconData ikon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool penuh;

  @override
  Widget build(BuildContext context) {
    final aktif = onPressed != null;
    final warna = aktif ? Warna.hijau : Warna.garisKontrol;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: aktif,
        label: tooltip,
        excludeSemantics: true,
        child: SizedBox(
          width: _sentuh,
          height: _sentuh,
          child: InkResponse(
            onTap: onPressed,
            radius: _sentuh / 2,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: _lingkaran,
                height: _lingkaran,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: penuh && aktif ? Warna.hijau : Warna.kartu,
                  border: Border.all(
                    color: aktif ? Warna.hijau : Warna.garis,
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  ikon,
                  size: 16,
                  color: penuh && aktif ? Colors.white : warna,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// - jumlah + dalam satu baris
class PengaturJumlah extends StatelessWidget {
  const PengaturJumlah({
    required this.jumlah,
    required this.onKurang,
    required this.onTambah,
    this.labelKurang = 'Kurangi porsi',
    this.labelTambah = 'Tambah porsi',
    super.key,
  });

  final int jumlah;
  final VoidCallback? onKurang;
  final VoidCallback? onTambah;
  final String labelKurang;
  final String labelTambah;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TombolJumlah(
          ikon: Icons.remove,
          tooltip: labelKurang,
          onPressed: onKurang,
        ),
        SizedBox(
          width: 24,
          child: Text(
            '$jumlah',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Warna.teks,
            ),
          ),
        ),
        TombolJumlah(
          ikon: Icons.add,
          tooltip: labelTambah,
          onPressed: onTambah,
        ),
      ],
    );
  }
}
