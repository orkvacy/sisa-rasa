import 'package:flutter/material.dart';
import 'package:sisa_rasa/theme/tema.dart';
import 'package:sisa_rasa/utils/format.dart';
import 'package:sisa_rasa/widgets/foto_paket.dart';

/// kartu paket versi besar, foto di atas. khusus paket yg jam ambilnya udah buka
class KartuPaketBesar extends StatelessWidget {
  const KartuPaketBesar({required this.paket, required this.onTap, super.key});

  final Map<String, dynamic> paket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;
    final warna = SisaRasaColors.of(context);
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final int sisa = paket['sisaPorsi'];
    final habis = sisa == 0;
    final mendesak = sisa <= 3;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(22),
          // mode gelap ga pake bayangan, dibedain lewat warna permukaan
          boxShadow: gelap
              ? null
              : [
                  BoxShadow(
                    color: cs.onSurface.withValues(alpha: 0.06),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                  BoxShadow(
                    color: cs.onSurface.withValues(alpha: 0.07),
                    blurRadius: 24,
                    spreadRadius: -4,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(6),
              // Stack: foto di bawah, pil diskon sama sisa porsi di atasnya
              child: Stack(
                children: [
                  FotoPaket(
                    foto: paket['foto'],
                    tinggi: 176,
                    radius: 16,
                    habis: habis,
                  ),
                  // Positioned: diskon di kiri atas
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _Pil(
                      teks:
                          '−${persenDiskon(paket['hargaAsli'], paket['hargaDiskon'])}%',
                      latar: cs.surfaceContainerLowest,
                      warnaTeks: cs.onSurface,
                    ),
                  ),
                  // Positioned: sisa porsi di kanan atas, oren kalau tinggal 3 ke bawah
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _Pil(
                      teks: habis ? 'Habis' : 'Sisa $sisa',
                      latar: mendesak
                          ? warna.urgentContainer
                          : cs.surfaceContainerLowest,
                      warnaTeks: mendesak ? warna.urgent : cs.onSurface,
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
                    style: teks.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(paket['nama'], style: teks.titleSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        rupiah(paket['hargaDiskon']),
                        style: teks.titleMedium?.copyWith(
                          fontSize: 20,
                          height: 24 / 20,
                          letterSpacing: -0.2,
                          fontFeatures: SisaRasaText.tabular,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Expanded: harga coret ngisi tengah, jam tutup kedorong ke kanan
                      Expanded(
                        child: Text(
                          rupiah(paket['hargaAsli']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: teks.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                      Icon(Icons.schedule, size: 15, color: warna.urgent),
                      const SizedBox(width: 4),
                      Text(
                        's/d ${jam(paket['tutup'])}',
                        style: teks.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: warna.urgent,
                          fontFeatures: SisaRasaText.tabular,
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

/// pil kecil di atas foto (diskon, sisa porsi)
class _Pil extends StatelessWidget {
  const _Pil({
    required this.teks,
    required this.latar,
    required this.warnaTeks,
  });

  final String teks;
  final Color latar;
  final Color warnaTeks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        teks,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(fontWeight: FontWeight.w700, color: warnaTeks),
      ),
    );
  }
}
