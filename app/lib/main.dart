import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/cubit/keranjang_cubit.dart';
import 'package:sisa_rasa/cubit/paket_cubit.dart';
import 'package:sisa_rasa/router.dart';
import 'package:sisa_rasa/theme/tema.dart';

void main() {
  runApp(const SisaRasaApp());
}

class SisaRasaApp extends StatefulWidget {
  const SisaRasaApp({super.key});

  @override
  State<SisaRasaApp> createState() => _SisaRasaAppState();
}

class _SisaRasaAppState extends State<SisaRasaApp> {
  // router dibikin sekali aja, kalau di build bakal ke-reset tiap digambar ulang
  late final GoRouter router = buatRouter();

  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // MultiBlocProvider: cubit sama bloc dipasang paling luar,
    // biar semua halaman yg dibuka lewat router bisa akses
    return MultiBlocProvider(
      providers: [
        // BlocProvider: nyediain satu cubit/bloc biar bisa diambil halaman di bawahnya
        BlocProvider(create: (context) => PaketCubit()),
        BlocProvider(create: (context) => KeranjangCubit()),
        // PesananBloc nahan / ngelepas stok lewat PaketCubit yg dipasang di atasnya
        BlocProvider(
          create: (context) {
            final paket = context.read<PaketCubit>();
            return PesananBloc(
              tahanPorsi: paket.kurangiStok,
              lepasPorsi: paket.kembalikanStok,
            );
          },
        ),
      ],
      // MaterialApp.router: akar aplikasi, halamannya diatur GoRouter (lihat router.dart)
      child: MaterialApp.router(
        title: 'Sisa Rasa',
        debugShowCheckedModeBanner: false,
        // tema dari figma v3 (token warna + tipografi), lihat theme/tema.dart
        theme: SisaRasaTema.terang(),
        darkTheme: SisaRasaTema.gelap(),
        // dikunci terang dulu, layar-layar masih pake Warna statis.
        // ganti ke ThemeMode.system kalau semua layar udah pindah ke tema
        themeMode: ThemeMode.light,
        // halaman awal (yg ada navigation bar nya) ditentuin router di Rute.utama
        routerConfig: router,
      ),
    );
  }
}
