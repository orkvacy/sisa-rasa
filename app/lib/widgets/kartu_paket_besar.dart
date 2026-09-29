import 'package:flutter/material.dart';
import 'package:sisa_rasa/theme/teks.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';

/// kartu paket versi besar, foto di atas. khusus paket yg jam ambilnya udah buka
class KartuPaketBesar extends StatelessWidget {
  const KartuPaketBesar({required this.paket, required this.onTap, super.key});

  final Map<String, dynamic> paket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final int sisa = paket['sisaPorsi'];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Warna.kartu,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(6),
              // Stack: foto di bawah, label diskon sama sisa porsi di atasnya
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      paket['foto'],
                      width: double.infinity,
                      height: 176,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Positioned: diskon di kiri atas
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Warna.kartu,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '−${persenDiskon(paket['hargaAsli'], paket['hargaDiskon'])}%',
                        style: const TextStyle(
                          fontSize: Teks.kecil,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  // Positioned: sisa porsi di kanan atas, oren kalau tinggal 3 kebawah
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: sisa <= 3 ? Warna.mendesakLembut : Warna.kartu,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        sisa == 0 ? 'Habis' : 'Sisa $sisa',
                        style: TextStyle(
                          fontSize: Teks.kecil,
                          fontWeight: FontWeight.w700,
                          color: sisa <= 3 ? Warna.mendesak : Warna.teks,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${paket['mitra']} · ${paket['jarak']}',
                    style: const TextStyle(
                      fontSize: Teks.keterangan,
                      color: Warna.teksPendukung,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    paket['nama'],
                    style: const TextStyle(
                      fontSize: Teks.nama,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        rupiah(paket['hargaDiskon']),
                        style: const TextStyle(
                          fontSize: Teks.hargaBesar,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Expanded: harga coret ngisi tengah, jam tutup kedorong ke kanan
                      Expanded(
                        child: Text(
                          rupiah(paket['hargaAsli']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: Teks.keterangan,
                            color: Warna.teksPendukung,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.schedule,
                        size: 15,
                        color: Warna.mendesak,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        's/d ${jam(paket['tutup'])}',
                        style: const TextStyle(
                          fontSize: Teks.keterangan,
                          fontWeight: FontWeight.w700,
                          color: Warna.mendesak,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
