import 'package:flutter/material.dart';
import 'package:sisa_rasa/theme/tema.dart';
import 'package:sisa_rasa/utils/format.dart';
import 'package:sisa_rasa/widgets/foto_paket.dart';

/// paket versi baris tenang (figma v3): tanpa kotak kartu, dipisah garis tipis,
/// ada tombol + buat nambah 1 porsi langsung dari daftar
class BarisPaket extends StatelessWidget {
  const BarisPaket({
    required this.paket,
    required this.onTap,
    required this.onTambah,
    this.bisaTambah = true,
    super.key,
  });

  final Map<String, dynamic> paket;
  final VoidCallback onTap;

  final VoidCallback onTambah;

  /// false kalau porsi di keranjang udah mentok sama sisa stok
  final bool bisaTambah;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;
    final warna = SisaRasaColors.of(context);
    final int sisa = paket['sisaPorsi'];
    final habis = sisa == 0;

    // InkWell: baris bisa diketuk buat buka detail, ada efek riak
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: cs.outlineVariant)),
        ),
        child: Row(
          children: [
            FotoPaket(foto: paket['foto'], lebar: 76, tinggi: 76, habis: habis),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paket['nama'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: teks.bodyLarge?.copyWith(
                      fontSize: 15,
                      height: 20 / 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${paket['mitra']} · ${paket['jarak']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: teks.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: rupiah(paket['hargaDiskon']),
                          style: teks.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: SisaRasaText.tabular,
                          ),
                        ),
                        const TextSpan(text: '  '),
                        // harga asli dicoret
                        TextSpan(
                          text: rupiah(paket['hargaAsli']),
                          style: teks.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // jam ambil + sisa porsi, sisanya oren kalau tinggal dikit
                  Text.rich(
                    TextSpan(
                      style: teks.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontFeatures: SisaRasaText.tabular,
                      ),
                      children: [
                        TextSpan(
                          text:
                              '${jam(paket['mulai'])}–${jam(paket['tutup'])} · ',
                        ),
                        TextSpan(
                          text: habis ? 'Habis' : 'Sisa $sisa',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: sisa <= 3 ? warna.urgent : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!habis) ...[
              const SizedBox(width: 8),
              // tombol + 40, area sentuhnya jadi 48 lewat materialTapTargetSize.padded di tema
              IconButton.filled(
                tooltip: 'Tambah ${paket['nama']}',
                onPressed: bisaTambah ? onTambah : null,
                icon: const Icon(Icons.add, size: 22),
                style: IconButton.styleFrom(
                  fixedSize: const Size(40, 40),
                  minimumSize: const Size(40, 40),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
