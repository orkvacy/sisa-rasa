import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/core/theme/warna.dart';
import 'package:sisa_rasa/domain/repositories/layanan_akun.dart';
import 'package:sisa_rasa/presentation/cubit/akun_cubit.dart';

/// F-30b "Lanjut dengan Google", khusus pembeli. ga digambar sama sekali
/// kalau Google belum diatur (mode tiruan / GOOGLE_CLIENT_ID kosong).
/// abis berhasil, router yg mindahin ke beranda / halaman yg tadi dituju
class TombolGoogle extends StatefulWidget {
  const TombolGoogle({this.onGagal, super.key});

  /// pesan galat ditampilin layar pemanggil. kosong = snackbar
  final ValueChanged<String>? onGagal;

  @override
  State<TombolGoogle> createState() => _TombolGoogleState();
}

class _TombolGoogleState extends State<TombolGoogle> {
  bool memuat = false;

  Future<void> masuk() async {
    setState(() => memuat = true);
    try {
      await context.read<AkunCubit>().masukGoogle();
    } on GagalAkun catch (e) {
      if (!mounted) return;
      if (widget.onGagal != null) {
        widget.onGagal!(e.pesan);
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.pesan)));
      }
    } finally {
      if (mounted) setState(() => memuat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    if (!context.read<AkunCubit>().bisaGoogle) return const SizedBox.shrink();
    return OutlinedButton(
      key: const Key('masuk-google'),
      onPressed: memuat ? null : masuk,
      style: OutlinedButton.styleFrom(
        foregroundColor: Warna.teks,
        backgroundColor: Warna.kartu,
        side: BorderSide(color: Warna.garisKontrol),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: memuat
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // huruf G sederhana, logo resmi Google belum dimasukin ke aset
                Text(
                  'G',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Warna.hijau,
                  ),
                ),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Lanjut dengan Google',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }
}
