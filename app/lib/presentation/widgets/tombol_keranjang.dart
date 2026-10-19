import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/core/theme/warna.dart';
import 'package:sisa_rasa/presentation/cubit/keranjang_cubit.dart';
import 'package:sisa_rasa/presentation/router.dart';

/// ikon keranjang di kanan atas beranda, angkanya = jumlah porsi di keranjang.
/// gantiin bar keranjang melayang biar ga numpuk sama navigasi melayang
class TombolKeranjang extends StatelessWidget {
  const TombolKeranjang({super.key});

  @override
  Widget build(BuildContext context) {
    // context.select: cuma digambar ulang kalau jumlah porsinya berubah
    final porsi = context.select<KeranjangCubit, int>(
      (cubit) => cubit.state.values.fold(0, (a, b) => a + b),
    );
    return IconButton(
      tooltip: porsi > 0 ? 'Keranjang, $porsi porsi' : 'Keranjang',
      onPressed: () {
        // snackbar "masuk keranjang" ditutup dulu biar ga nutupin tombol checkout
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        context.push(Rute.keranjang);
      },
      icon: Badge(
        isLabelVisible: porsi > 0,
        label: Text(
          porsi > 99 ? '99+' : '$porsi',
          key: const Key('jumlah-keranjang'),
        ),
        backgroundColor: Warna.merah,
        child: const Icon(Icons.shopping_bag_outlined, color: Warna.teks),
      ),
    );
  }
}
