import 'package:flutter/material.dart';
import 'package:sisa_rasa/screens/halaman_utama.dart';
import 'package:sisa_rasa/theme/warna.dart';

void main() {
  runApp(const SisaRasaApp());
}

class SisaRasaApp extends StatelessWidget {
  const SisaRasaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // pembungkus paling luar, tempat naruh tema sama halaman awal
    return MaterialApp(
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
    );
  }
}
