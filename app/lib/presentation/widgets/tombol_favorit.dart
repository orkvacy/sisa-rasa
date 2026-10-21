import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/core/theme/warna.dart';
import 'package:sisa_rasa/presentation/cubit/akun_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/favorit_cubit.dart';
import 'package:sisa_rasa/presentation/router.dart';
import 'package:sisa_rasa/presentation/widgets/animasi.dart';

/// tombol hati bulat putih di atas foto (halaman mitra, detail paket).
/// [paket] salah satu paket mitranya, dipake buat tau id + nama mitra.
/// tamu diminta masuk dulu, abis itu balik ke halaman ini
class TombolFavorit extends StatelessWidget {
  const TombolFavorit({required this.paket, super.key});

  final Map<String, dynamic> paket;

  @override
  Widget build(BuildContext context) {
    final suka = context.select<FavoritCubit, bool>(
      (c) => c.suka(kunciMitra(paket)),
    );
    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.white,
      child: IconButton(
        tooltip: suka ? 'Hapus dari favorit' : 'Simpan mitra',
        onPressed: () {
          if (context.read<AkunCubit>().tamu) {
            context.push(
              Rute.masukLalu(GoRouterState.of(context).uri.toString()),
            );
            return;
          }
          context.read<FavoritCubit>().ganti(paket);
        },
        // hatinya mantul tiap disimpan / dilepas
        icon: MantulSaatBerubah(
          nilai: suka,
          puncak: 1.3,
          child: Icon(
            suka ? Icons.favorite : Icons.favorite_border,
            size: 22,
            color: suka ? Warna.merah : Warna.teks,
          ),
        ),
      ),
    );
  }
}
