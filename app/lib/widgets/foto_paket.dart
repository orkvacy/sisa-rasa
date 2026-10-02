import 'package:flutter/material.dart';

/// foto paket dengan sudut bulat. kalau paketnya habis, fotonya dibikin pudar (grayscale 50%)
/// biar jelas ga bisa dipesan
class FotoPaket extends StatelessWidget {
  const FotoPaket({
    required this.foto,
    required this.tinggi,
    this.lebar,
    this.radius = 14,
    this.habis = false,
    super.key,
  });

  final String foto;
  final double tinggi;

  /// null = selebar tempat yg tersedia
  final double? lebar;
  final double radius;
  final bool habis;

  // matriks saturasi 0.5, dipake ColorFiltered buat ngurangin warna separuh
  static const _setengahAbu = ColorFilter.matrix(<double>[
    0.6064, 0.3576, 0.0360, 0, 0, //
    0.1064, 0.8576, 0.0360, 0, 0, //
    0.1064, 0.3576, 0.5360, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final gambar = Image.asset(
      foto,
      width: lebar ?? double.infinity,
      height: tinggi,
      fit: BoxFit.cover,
    );

    // ClipRRect: motong sudut foto biar ikut bulet
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: habis
          ? ColorFiltered(colorFilter: _setengahAbu, child: gambar)
          : gambar,
    );
  }
}
