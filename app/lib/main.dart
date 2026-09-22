import 'package:flutter/material.dart';
import 'package:sisa_rasa/screens/beranda.dart';

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
      // theme: aturan warna umum, sementara, nnti mau di redesign
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      // landing page utama yg direct kalau baru buka
      home: const Beranda(),
    );
  }
}
