import 'package:flutter/material.dart';
import 'package:sisa_rasa/utils/format.dart';

/// pil gelap yg ngambang tepat di atas navigasi melayang kalau keranjang ada isinya.
/// lebarnya disamain sama navigasi (274) biar rapi satu kolom
class BarKeranjang extends StatelessWidget {
  const BarKeranjang({
    required this.foto,
    required this.jumlahPorsi,
    required this.total,
    required this.onTap,
    super.key,
  });

  static const _lebar = 274.0;

  final String foto;
  final int jumlahPorsi;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _lebar),
        // Material + InkWell: biar ada efek riak waktu diketuk
        child: Material(
          color: cs.inverseSurface,
          borderRadius: BorderRadius.circular(999),
          elevation: 6,
          shadowColor: cs.scrim.withValues(alpha: 0.4),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Semantics(
              button: true,
              label: 'Keranjang, $jumlahPorsi porsi, ${rupiah(total)}',
              excludeSemantics: true,
              child: Padding(
                // tinggi total 56 (>= 48 dp) buat area sentuh
                padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
                child: Row(
                  children: [
                    ClipOval(
                      child: Image.asset(
                        foto,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$jumlahPorsi porsi',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: teks.labelSmall?.copyWith(
                              color: cs.onInverseSurface.withValues(
                                alpha: 0.75,
                              ),
                            ),
                          ),
                          Text(
                            rupiah(total),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: teks.titleSmall?.copyWith(
                              color: cs.onInverseSurface,
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Keranjang',
                      style: teks.labelSmall?.copyWith(
                        color: cs.onInverseSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: cs.onInverseSurface,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
