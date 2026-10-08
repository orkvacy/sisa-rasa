import 'package:flutter/material.dart';
import 'package:sisa_rasa/data/status_pesanan.dart';
import 'package:sisa_rasa/theme/warna.dart';

/// pil kecil status pesanan, warnanya ngikutin figma v3
class PilStatus extends StatelessWidget {
  const PilStatus({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (latar, warna) = switch (status) {
      StatusPesanan.menungguBayar => (Warna.mendesakLembut, Warna.mendesak),
      StatusPesanan.disiapkan => (Warna.kraft, Warna.teks),
      StatusPesanan.dibatalkan => (Warna.merahLembut, Warna.merah),
      StatusPesanan.tidakDiambil => (Warna.garis, Warna.teksPendukung),
      _ => (Warna.softGreen, Warna.hijau),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        // di kartu cukup "Menunggu bayar", label panjangnya dipake di tempat lain
        status == StatusPesanan.menungguBayar
            ? 'Menunggu bayar'
            : StatusPesanan.label(status),
        style: TextStyle(
          fontSize: 11,
          height: 16 / 11,
          letterSpacing: 0.1,
          fontWeight: FontWeight.w700,
          color: warna,
        ),
      ),
    );
  }
}
