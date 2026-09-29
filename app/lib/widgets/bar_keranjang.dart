import 'package:flutter/material.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';

/// bar item gelap yg ngambang di atas navigation bar kalau keranjang ada isinya
class BarKeranjang extends StatelessWidget {
  const BarKeranjang({
    required this.foto,
    required this.mitra,
    required this.jumlahPorsi,
    required this.total,
    required this.onTap,
    super.key,
  });

  final String foto;
  final String mitra;
  final int jumlahPorsi;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
        decoration: BoxDecoration(
          color: Warna.gelap,
          borderRadius: BorderRadius.circular(18),
          // BoxShadow: bayangan agak tebel biar keliatan di atas kartu
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                foto,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$jumlahPorsi porsi · $mitra',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  Text(
                    rupiah(total),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              'Keranjang',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
