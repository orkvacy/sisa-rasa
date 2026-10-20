import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sisa_rasa/core/alamat.dart';
import 'package:sisa_rasa/core/theme/warna.dart';

/// foto paket dari mana pun asalnya:
/// - "assets/..." foto contoh yang ikut di aplikasi
/// - "https://..." foto unggahan mitra di Cloudflare R2
/// - "/v1/foto/..." foto unggahan yang disimpan di server sendiri
/// - "file://..." foto yang baru dipilih mitra (mode tanpa server)
/// argumennya sama kayak Image.asset biar gampang dituker
class GambarPaket extends StatelessWidget {
  const GambarPaket(
    this.foto, {
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String foto;
  final double? width;
  final double? height;
  final BoxFit fit;

  static ImageProvider sumber(String foto) {
    if (foto.startsWith('http://') || foto.startsWith('https://')) {
      return NetworkImage(foto);
    }
    if (foto.startsWith('/v1/')) return NetworkImage('$alamatApi$foto');
    if (foto.startsWith('file://')) return FileImage(File(foto.substring(7)));
    return AssetImage(foto);
  }

  @override
  Widget build(BuildContext context) {
    return Image(
      image: sumber(foto),
      width: width,
      height: height,
      fit: fit,
      // sinyal jelek / foto dihapus: kotak polos, bukan kotak merah galat
      errorBuilder: (context, error, stack) => Container(
        width: width,
        height: height,
        color: Warna.kraft,
        alignment: Alignment.center,
        child: const Icon(
          Icons.restaurant_outlined,
          color: Warna.teksPendukung,
        ),
      ),
    );
  }
}
