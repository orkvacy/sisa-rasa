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

    // GestureDetector: kartu bisa dipencet buat buka detail
    return GestureDetector(
      onTap: onTap,
      // Container: kotak putih kartu
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
        // Column: foto atas, info bawah
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Padding: jarak foto dari pinggir kartu
            Padding(
              padding: const EdgeInsets.all(6),
              // Stack: foto di bawah, label diskon sama sisa porsi di atasnya
              child: Stack(
                children: [
                  // ClipRRect: sudut foto dibikin bulet
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    // Image.asset: foto paket
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
                    // Container: label persen diskon
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Warna.kartu,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      // persen diskon
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
                    // Container: label sisa porsi
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: sisa <= 3 ? Warna.mendesakLembut : Warna.kartu,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      // sisa porsi / habis
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
            // Padding: jarak info paket
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              // Column: info paket disusun ke bawah
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // mitra + jarak
                  Text(
                    '${paket['mitra']} · ${paket['jarak']}',
                    style: const TextStyle(
                      fontSize: Teks.keterangan,
                      color: Warna.teksPendukung,
                    ),
                  ),
                  // jarak
                  const SizedBox(height: 2),
                  // nama paket
                  Text(
                    paket['nama'],
                    style: const TextStyle(
                      fontSize: Teks.nama,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  // jarak
                  const SizedBox(height: 8),
                  // Row: harga, harga coret, jam tutup
                  Row(
                    children: [
                      // harga diskon
                      Text(
                        rupiah(paket['hargaDiskon']),
                        style: const TextStyle(
                          fontSize: Teks.hargaBesar,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      // jarak
                      const SizedBox(width: 6),
                      // Expanded: harga coret ngisi tengah, jam tutup kedorong ke kanan
                      Expanded(
                        // harga asli dicoret
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
                      // icon jam
                      const Icon(
                        Icons.schedule,
                        size: 15,
                        color: Warna.mendesak,
                      ),
                      // jarak
                      const SizedBox(width: 4),
                      // jam tutup
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
