import 'package:flutter/material.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/widgets/navigasi_melayang.dart';

/// isi sementara tab mitra yg layarnya belum dibikin (Paket, Saldo)
class SegeraHadir extends StatelessWidget {
  const SegeraHadir({required this.judul, required this.keterangan, super.key});

  final String judul;
  final String keterangan;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          NavigasiMelayang.ruangBawah,
        ),
        children: [
          Text(
            judul,
            style: const TextStyle(
              fontSize: 28,
              height: 34 / 28,
              letterSpacing: -0.4,
              fontWeight: FontWeight.w800,
              color: Warna.teks,
            ),
          ),
          const SizedBox(height: 64),
          const Icon(
            Icons.construction_outlined,
            size: 56,
            color: Warna.teksPendukung,
          ),
          const SizedBox(height: 12),
          Text(
            keterangan,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Warna.teksPendukung),
          ),
        ],
      ),
    );
  }
}
