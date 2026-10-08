import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/cubit/keranjang_cubit.dart';
import 'package:sisa_rasa/cubit/paket_cubit.dart';
import 'package:sisa_rasa/theme/teks.dart';
import 'package:sisa_rasa/theme/warna.dart';

/// F-07: satu pesanan cuma boleh dari satu mitra.
/// dipanggil sebelum nambah [paket] ke keranjang dari mana aja
/// (detail paket, halaman mitra, tombol + di beranda).
///
/// hasilnya:
/// - null  = pembeli batal, jangan ditambah
/// - false = boleh langsung ditambah (keranjang kosong / mitranya sama)
/// - true  = boleh ditambah, tapi keranjang lama dikosongin dulu
Future<bool?> cekGantiMitra(
  BuildContext context,
  Map<String, dynamic> paket,
) async {
  final keranjang = context.read<KeranjangCubit>().state;
  if (keranjang.isEmpty) return false;

  final mitraKeranjang = context.read<PaketCubit>().cari(
    keranjang.keys.first,
  )['mitra'];
  if (mitraKeranjang == paket['mitra']) return false;

  final ganti = await showModalBottomSheet<bool>(
    context: context,
    // di atas navigasi melayang juga, kalau dibuka dari tab beranda
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ganti isi keranjang?',
            style: TextStyle(
              fontSize: Teks.subjudul,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Keranjangmu berisi paket dari $mitraKeranjang. Satu pesanan hanya bisa dari satu mitra karena diambil langsung di tempat.',
            style: const TextStyle(
              fontSize: Teks.isi,
              height: 1.45,
              color: Warna.teksPendukung,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            // bottom sheet bukan rute halaman, jadi nutupnya pake Navigator.pop sambil ngirim jawaban
            child: FilledButton(
              onPressed: () => Navigator.pop(sheetContext, true),
              style: FilledButton.styleFrom(backgroundColor: Warna.merah),
              child: const Text('Kosongkan & tambah'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(sheetContext, false),
              child: const Text('Batal'),
            ),
          ),
        ],
      ),
    ),
  );
  return ganti == true ? true : null;
}
