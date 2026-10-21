import 'package:flutter/material.dart';
import 'package:sisa_rasa/core/theme/warna.dart';
import 'package:sisa_rasa/presentation/widgets/animasi.dart';

/// Satu kabar terbaru, tanpa antrean saat tombol jumlah ditekan cepat.
void kabarJumlah(
  BuildContext context, {
  required String nama,
  required int jumlah,
  bool diKeranjang = true,
  double jarakBawah = 88,
}) {
  final pesan = jumlah == 0
      ? '$nama dihapus dari keranjang'
      : diKeranjang
      ? '$nama: $jumlah porsi di keranjang'
      : '$nama: $jumlah porsi dipilih';
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..removeCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(pesan, key: const Key('kabar-jumlah')),
        backgroundColor: Warna.hijau,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          12,
          0,
          12,
          jarakBawah + MediaQuery.paddingOf(context).bottom,
        ),
        duration: const Duration(seconds: 2),
      ),
      snackBarAnimationStyle: AnimationStyle(
        duration: durasiGerak(context, 250),
        reverseDuration: durasiGerak(context, 180),
      ),
    );
}
