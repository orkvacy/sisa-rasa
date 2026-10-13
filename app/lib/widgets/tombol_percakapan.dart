import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/cubit/percakapan_cubit.dart';
import 'package:sisa_rasa/router.dart';
import 'package:sisa_rasa/theme/warna.dart';

/// tombol buka percakapan pesanan, dengan angka pesan belum dibaca (F-70).
/// [peran] = peran yg lagi masuk, nentuin teks tombol sama alamat yg dibuka
class TombolPercakapan extends StatelessWidget {
  const TombolPercakapan({
    required this.pesanan,
    required this.peran,
    this.ringkas = false,
    super.key,
  });

  final Map<String, dynamic> pesanan;
  final String peran;

  /// cuma ikon + angka, buat baris yg sempit
  final bool ringkas;

  @override
  Widget build(BuildContext context) {
    // belum dibayar, percakapannya belum ada
    if (keadaanPercakapan(pesanan) == 'tidakAda') {
      return const SizedBox.shrink();
    }
    final String id = pesanan['id'];
    final belum = context.select<PercakapanCubit, int>(
      (cubit) => cubit.belumDibaca(id, peran),
    );
    final label = peran == 'mitra' ? 'Chat pembeli' : 'Chat mitra';
    void buka() => context.push(
      peran == 'mitra' ? Rute.mitraPercakapan(id) : Rute.percakapan(id),
    );

    final ikon = Badge(
      isLabelVisible: belum > 0,
      label: Text('$belum'),
      backgroundColor: Warna.merah,
      child: const Icon(Icons.chat_bubble_outline, size: 18),
    );

    if (ringkas) {
      return IconButton(
        tooltip: belum > 0 ? '$label, $belum pesan baru' : label,
        onPressed: buka,
        color: Warna.hijau,
        icon: ikon,
      );
    }
    return OutlinedButton.icon(
      onPressed: buka,
      icon: ikon,
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: Warna.teks,
        backgroundColor: Colors.white,
        side: const BorderSide(color: Warna.garisKontrol),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
