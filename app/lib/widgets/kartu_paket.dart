import 'package:flutter/material.dart';
import 'package:sisa_rasa/theme/teks.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';

/// kartu paket versi kecil, foto di kiri. dipake buat paket yg bukanya nanti
class KartuPaket extends StatelessWidget {
  const KartuPaket({required this.paket, required this.onTap, super.key});

  final Map<String, dynamic> paket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final int sisa = paket['sisaPorsi'];

    // GestureDetector: biar kartunya bisa dipencet
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Warna.kartu,
          borderRadius: BorderRadius.circular(20),
          // BoxShadow: bayangan tipis biar kartunya keliatan ngambang
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Stack: foto di bawah, label diskon ditumpuk di atasnya
            Stack(
              children: [
                // ClipRRect: motong sudut foto biar ikut bulet
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  // Image.asset: foto paket dari assets/images
                  child: Image.asset(
                    paket['foto'],
                    width: 104,
                    height: 104,
                    fit: BoxFit.cover,
                  ),
                ),
                // Positioned: label diskon di pojok kiri atas foto
                Positioned(
                  top: 6,
                  left: 6,
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
              ],
            ),
            const SizedBox(width: 12),
            // Expanded: info paket ngisi sisa lebar kartu
            Expanded(
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: Teks.tombol,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        rupiah(paket['hargaDiskon']),
                        style: const TextStyle(
                          fontSize: Teks.nama,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // harga asli dicoret
                      Text(
                        rupiah(paket['hargaAsli']),
                        style: const TextStyle(
                          fontSize: Teks.keterangan,
                          color: Warna.teksPendukung,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // jam ambil + sisa porsi, sisanya oren kalau tinggal dikit
                  Text.rich(
                    // TextSpan: potongan teks, jadi satu baris bisa beda2 gaya
                    TextSpan(
                      style: const TextStyle(
                        fontSize: Teks.keterangan,
                        color: Warna.teksPendukung,
                      ),
                      children: [
                        TextSpan(
                          text:
                              '${jam(paket['mulai'])}–${jam(paket['tutup'])} · ',
                        ),
                        TextSpan(
                          text: sisa == 0 ? 'Habis' : 'Sisa $sisa',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: sisa <= 3
                                ? Warna.mendesak
                                : Warna.teksPendukung,
                          ),
                        ),
                      ],
                    ),
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
