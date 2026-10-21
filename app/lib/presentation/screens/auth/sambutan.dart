import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/presentation/cubit/akun_cubit.dart';
import 'package:sisa_rasa/presentation/router.dart';
import 'package:sisa_rasa/presentation/screens/auth/tombol_google.dart';
import 'package:sisa_rasa/core/theme/warna.dart';

/// layar pertama sebelum masuk (figma v3: umum/sambutan)
class Sambutan extends StatelessWidget {
  const Sambutan({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Warna.latar,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, ukuran) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: ConstrainedBox(
              // isi didorong ke bawah kalau layarnya tinggi, bisa digulir kalau pendek
              constraints: BoxConstraints(minHeight: ukuran.maxHeight - 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // mosaik ngisi sisa tinggi layar, tombol tetep di bawah kayak di figma
                  SizedBox(
                    height: (ukuran.maxHeight - 420).clamp(200, 440),
                    child: const _MosaikFoto(),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Makanan enak yang belum sempat habis.',
                    style: TextStyle(
                      fontSize: 26,
                      height: 36 / 30,
                      letterSpacing: -0.6,
                      fontWeight: FontWeight.w800,
                      color: Warna.teks,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Ambil sisa dapur hotel, resto, dan bakery di Samarinda dengan harga separuh, sebelum mereka tutup.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 22 / 15,
                      color: Warna.teksPendukung,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.push(Rute.daftar),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Buat akun'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.push(Rute.masuk),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Warna.teks,
                      backgroundColor: Warna.kartu,
                      side: BorderSide(color: Warna.garisKontrol),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Masuk'),
                  ),
                  if (context.read<AkunCubit>().bisaGoogle) ...[
                    const SizedBox(height: 12),
                    const TombolGoogle(),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    // tamu bisa lihat paket, baru diminta masuk pas checkout
                    onPressed: () =>
                        context.read<AkunCubit>().lihatSebagaiTamu(),
                    style: TextButton.styleFrom(
                      foregroundColor: Warna.hijau,
                      minimumSize: const Size.fromHeight(48),
                      textStyle: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Lihat paket dulu'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// empat foto makanan disusun mosaik, foto pertama ada label jam ambil
class _MosaikFoto extends StatelessWidget {
  const _MosaikFoto();

  static const _folder = 'assets/images/paket';

  Widget _kotak(String foto, {Widget? label}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('$_folder/$foto.jpg', fit: BoxFit.cover),
          if (label != null) Positioned(left: 12, bottom: 12, child: label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: _kotak(
                    'buffet_hotel',
                    label: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule, size: 16, color: Warna.mendesak),
                          SizedBox(width: 6),
                          Text(
                            'Ambil 17.00–19.00',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Warna.mendesak,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(flex: 2, child: _kotak('croissant')),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Expanded(flex: 2, child: _kotak('sushi')),
                const SizedBox(height: 8),
                Expanded(flex: 3, child: _kotak('sirloin')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
