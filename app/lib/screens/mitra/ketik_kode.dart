import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/bloc/pesanan_event.dart';
import 'package:sisa_rasa/cubit/akun_cubit.dart';
import 'package:sisa_rasa/data/status_pesanan.dart';
import 'package:sisa_rasa/theme/warna.dart';

/// kode ambil yg diketik kasir dicocokin ke pesanan mitra ini (F-46).
/// cocok + udah dibayar -> pesanan selesai diambil (F-20).
/// balikin pesan buat ditampilin, null kalau berhasil
String? cocokkanKode(BuildContext context, String ketikan) {
  final kode = ketikan.trim().toUpperCase();
  final lengkap = kode.startsWith('SR-') ? kode : 'SR-$kode';
  final mitra = context.read<AkunCubit>().state['nama'];
  final bloc = context.read<PesananBloc>();

  final pesanan = bloc.state
      .where((p) => p['kode'] == lengkap && p['mitra'] == mitra)
      .firstOrNull;
  if (pesanan == null) return 'Kode $lengkap tidak dikenali';

  final status = pesanan['status'];
  if (status == StatusPesanan.selesai) return 'Pesanan $lengkap sudah diambil';
  if (status != StatusPesanan.disiapkan &&
      status != StatusPesanan.siapDiambil) {
    return 'Pesanan $lengkap ${StatusPesanan.label(status).toLowerCase()}';
  }
  bloc.add(StatusPesananDiubah(pesanan['id'], StatusPesanan.selesai));
  return null;
}

/// lembar bawah buat ketik kode ambil, gantinya pindai QR sampai kamera dibikin
Future<void> bukaKetikKode(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheetContext) => const _LembarKetikKode(),
  );
}

class _LembarKetikKode extends StatefulWidget {
  const _LembarKetikKode();

  @override
  State<_LembarKetikKode> createState() => _LembarKetikKodeState();
}

class _LembarKetikKodeState extends State<_LembarKetikKode> {
  final kolom = TextEditingController();
  String? galat;

  @override
  void dispose() {
    kolom.dispose();
    super.dispose();
  }

  void cek() {
    final pesan = cocokkanKode(context, kolom.text);
    if (pesan != null) {
      setState(() => galat = pesan);
      return;
    }
    final kode = kolom.text.trim().toUpperCase();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${kode.startsWith('SR-') ? kode : 'SR-$kode'} cocok, pesanan selesai diambil',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // naik ikut keyboard
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ketik kode ambil',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Warna.teks,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Minta pembeli menyebutkan kodenya, lalu ketik di sini. Pindai QR lewat kamera menyusul.',
            style: TextStyle(fontSize: 13, color: Warna.teksPendukung),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: kolom,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9-]')),
              LengthLimitingTextInputFormatter(7),
            ],
            onSubmitted: (_) => cek(),
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 22,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(hintText: 'SR-7K4Q', errorText: galat),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: cek,
              style: FilledButton.styleFrom(
                backgroundColor: Warna.hijau,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Cocokkan kode',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
