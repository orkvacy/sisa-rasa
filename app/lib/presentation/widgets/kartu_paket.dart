import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/presentation/cubit/lokasi_cubit.dart';
import 'package:sisa_rasa/core/theme/teks.dart';
import 'package:sisa_rasa/core/theme/warna.dart';
import 'package:sisa_rasa/core/utils/format.dart';
import 'package:sisa_rasa/presentation/widgets/gambar_paket.dart';
import 'package:sisa_rasa/presentation/widgets/animasi.dart';

/// kartu paket versi kecil, foto di kiri. dipake buat paket yg bukanya nanti
class KartuPaket extends StatelessWidget {
  const KartuPaket({required this.paket, required this.onTap, super.key});

  final Map<String, dynamic> paket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final int sisa = paket['sisaPorsi'];

    // GestureDetector: biar kartunya bisa dipencet
    // TekanMengecil: kartunya mengecil dikit pas dipencet
    return TekanMengecil(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          // rata tanpa bayangan, antar paket cuma dipisah garis tipis
          decoration: BoxDecoration(
            color: Warna.kartu,
            border: Border(bottom: BorderSide(color: Warna.garis)),
          ),
          child: Row(
            children: [
              // Stack: foto di bawah, label diskon ditumpuk di atasnya
              Stack(
                children: [
                  // ClipRRect: motong sudut foto biar ikut bulet
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    // GambarPaket: foto paket dari assets/images
                    child: Hero(
                      tag: 'foto-paket-${paket['id']}',
                      child: GambarPaket(
                        paket['foto'],
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                      ),
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
                  if (paket['mejaBerbagi'] == true)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Warna.hijau,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Meja Berbagi',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Warna.kartu,
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
                      '${paket['mitra']} · ${context.watch<LokasiCubit>().teks(paket)}',
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
                          style: TextStyle(
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
                        style: TextStyle(
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
      ),
    );
  }
}
