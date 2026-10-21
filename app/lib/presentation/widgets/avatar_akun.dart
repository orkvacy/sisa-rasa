import 'package:flutter/material.dart';
import 'package:sisa_rasa/core/theme/warna.dart';
import 'package:sisa_rasa/presentation/cubit/akun_cubit.dart';
import 'package:sisa_rasa/presentation/widgets/gambar_paket.dart';

/// lingkaran foto profil (F-63). belum pasang foto / fotonya gagal dimuat:
/// inisial nama di latar hijau muda
class AvatarAkun extends StatelessWidget {
  const AvatarAkun({
    required this.nama,
    this.foto,
    this.radius = 22,
    this.ukuranHuruf,
    super.key,
  });

  final String nama;
  final String? foto;
  final double radius;
  final double? ukuranHuruf;

  @override
  Widget build(BuildContext context) {
    final inisialNama = Text(
      inisial(nama),
      style: TextStyle(
        fontSize: ukuranHuruf,
        fontWeight: FontWeight.w800,
        color: Warna.hijau,
      ),
    );
    final ada = foto != null && foto!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Warna.softGreen,
      child: ada
          ? ClipOval(
              child: Image(
                image: GambarPaket.sumber(foto!),
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => inisialNama,
              ),
            )
          : inisialNama,
    );
  }
}
