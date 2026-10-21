import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/core/theme/warna.dart';
import 'package:sisa_rasa/presentation/cubit/akun_cubit.dart';

/// aplikasi dibuka pas ga ada internet / server ga bisa dihubungi, padahal
/// sesi masih tersimpan. daripada dilempar ke layar masuk, tunggu di sini
/// sampai koneksinya balik. dicoba ulang sendiri tiap 10 detik
class TanpaKoneksi extends StatefulWidget {
  const TanpaKoneksi({super.key});

  @override
  State<TanpaKoneksi> createState() => _TanpaKoneksiState();
}

class _TanpaKoneksiState extends State<TanpaKoneksi> {
  Timer? _ulang;
  bool memuat = false;

  @override
  void initState() {
    super.initState();
    _ulang = Timer.periodic(const Duration(seconds: 10), (_) => cobaLagi());
  }

  @override
  void dispose() {
    _ulang?.cancel();
    super.dispose();
  }

  /// berhasil = router langsung pindah ke beranda / dasbor
  Future<void> cobaLagi() async {
    if (memuat) return;
    setState(() => memuat = true);
    await context.read<AkunCubit>().pulihkan();
    if (mounted) setState(() => memuat = false);
  }

  @override
  Widget build(BuildContext context) {
    final pesan =
        context.watch<AkunCubit>().state['pesan'] ??
        'Cek koneksi internetmu lalu coba lagi.';
    return Scaffold(
      backgroundColor: Warna.latar,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.wifi_off, size: 56, color: Warna.teksPendukung),
              const SizedBox(height: 20),
              Text(
                'Tidak ada koneksi',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Warna.teks,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                pesan,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 22 / 15,
                  color: Warna.teksPendukung,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Kamu tetap masuk, tidak perlu login ulang.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Warna.teksPendukung),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                key: const Key('coba-lagi'),
                onPressed: memuat ? null : cobaLagi,
                icon: memuat
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh),
                label: Text(memuat ? 'Menyambungkan…' : 'Coba lagi'),
                style: FilledButton.styleFrom(
                  backgroundColor: Warna.hijau,
                  disabledBackgroundColor: Warna.hijau.withValues(alpha: 0.6),
                  disabledForegroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
