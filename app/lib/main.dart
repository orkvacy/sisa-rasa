import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/cubit/keranjang_cubit.dart';
import 'package:sisa_rasa/cubit/paket_cubit.dart';
import 'package:sisa_rasa/screens/halaman_utama.dart';
import 'package:sisa_rasa/theme/warna.dart';

void main() {
  runApp(const SisaRasaApp());
}

class SisaRasaApp extends StatelessWidget {
  const SisaRasaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiBlocProvider: cubit sama bloc dipasang paling luar,
    // biar semua halaman (termasuk yg dibuka pake Navigator.push) bisa akses
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => PaketCubit()),
        BlocProvider(create: (context) => KeranjangCubit()),
        BlocProvider(create: (context) => PesananBloc()),
      ],
      child: MaterialApp(
        title: 'Sisa Rasa',
        debugShowCheckedModeBanner: false,
        // theme: warna ijo hutan, latar krem, font jakarta sans. ngikut figma v2
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Warna.hijau,
            primary: Warna.hijau,
            surface: Warna.latar,
          ),
          scaffoldBackgroundColor: Warna.latar,
          fontFamily: 'PlusJakartaSans',
          useMaterial3: true,
        ),
        // halaman awal yg ada navigation bar nya
        home: const HalamanUtama(),
      ),
    );
  }
}
