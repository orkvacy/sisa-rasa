import 'package:flutter/material.dart';
import 'package:sisa_rasa/theme/teks.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';

/// timeline 3 titik: sekarang, buka, tutup
/// garis putus2 = masih nunggu, garis tebel ijo = jam ambilnya
class TimelineAmbil extends StatelessWidget {
  const TimelineAmbil({required this.paket, super.key});

  final Map<String, dynamic> paket;

  @override
  Widget build(BuildContext context) {
    final buka = sudahBuka(paket);

    // urutan titiknya beda kalau udah buka (buka -> sekarang -> tutup)
    final label = buka
        ? ['Buka', 'Sekarang', 'Tutup']
        : ['Sekarang', 'Buka', 'Tutup'];
    final waktu = buka
        ? [paket['mulai'], jamSekarang, paket['tutup']]
        : [jamSekarang, paket['mulai'], paket['tutup']];

    return Column(
      children: [
        Row(
          children: [
            _Titik(jenis: buka ? 'penuh' : 'sekarang'),
            Expanded(
              child: buka
                  ? Container(height: 4, color: Warna.hijau)
                  // LayoutBuilder: ngitung muat berapa titik kecil buat garis putus2
                  : LayoutBuilder(
                      builder: (context, ukuran) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (var i = 0; i < ukuran.maxWidth ~/ 6; i++)
                              Container(
                                width: 2,
                                height: 2,
                                color: Warna.teksPendukung,
                              ),
                          ],
                        );
                      },
                    ),
            ),
            _Titik(jenis: buka ? 'sekarang' : 'cincin'),
            Expanded(child: Container(height: 4, color: Warna.hijau)),
            const _Titik(jenis: 'penuh'),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Column(
                  crossAxisAlignment: i == 0
                      ? CrossAxisAlignment.start
                      : i == 1
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.end,
                  children: [
                    Text(
                      label[i],
                      style: const TextStyle(
                        fontSize: Teks.kecil,
                        color: Warna.teksPendukung,
                      ),
                    ),
                    Text(
                      jam(waktu[i]),
                      style: const TextStyle(
                        fontSize: Teks.keterangan,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Titik extends StatelessWidget {
  const _Titik({required this.jenis});

  // 'sekarang' = titik item, 'cincin' = bulet kosong, 'penuh' = bulet ijo
  final String jenis;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: jenis == 'sekarang' ? 12 : 16,
      height: jenis == 'sekarang' ? 12 : 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: jenis == 'sekarang'
            ? Warna.teks
            : jenis == 'penuh'
            ? Warna.hijau
            : Warna.kartu,
        border: jenis == 'cincin'
            ? Border.all(color: Warna.hijau, width: 3)
            : null,
      ),
    );
  }
}
