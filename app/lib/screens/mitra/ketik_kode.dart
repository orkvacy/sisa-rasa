import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/bloc/pesanan_event.dart';
import 'package:sisa_rasa/cubit/akun_cubit.dart';
import 'package:sisa_rasa/data/dummy_akun.dart';
import 'package:sisa_rasa/data/pembayaran.dart';
import 'package:sisa_rasa/data/status_pesanan.dart';
import 'package:sisa_rasa/router.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';

/// "7k4q", "SR-7K4Q", atau isi QR -> "SR-7K4Q"
String rapikanKode(String mentah) {
  final kode = mentah.trim().toUpperCase();
  return kode.startsWith('SR-') ? kode : 'SR-$kode';
}

/// cari pesanan mitra ini yg kodenya cocok dan masih nunggu diambil (F-20, F-46).
/// balikin pesanannya, atau pesan galat buat ditampilin
({Map<String, dynamic>? pesanan, String? galat}) cariKode(
  BuildContext context,
  String mentah,
) {
  final kode = rapikanKode(mentah);
  final mitra = context.read<AkunCubit>().state['nama'];
  final pesanan = context
      .read<PesananBloc>()
      .state
      .where((p) => p['kode'] == kode && p['mitra'] == mitra)
      .firstOrNull;

  final status = pesanan?['status'];
  if (pesanan == null || status == StatusPesanan.selesai) {
    return (
      pesanan: null,
      galat:
          'Kode $kode tidak ditemukan atau sudah dipakai. Cek lagi kode di HP pembeli.',
    );
  }
  if (status == StatusPesanan.dibatalkan) {
    return (pesanan: null, galat: 'Pesanan $kode sudah dibatalkan.');
  }
  if (status != StatusPesanan.disiapkan &&
      status != StatusPesanan.siapDiambil) {
    return (
      pesanan: null,
      galat: 'Pesanan $kode ${StatusPesanan.label(status).toLowerCase()}.',
    );
  }
  return (pesanan: pesanan, galat: null);
}

/// lembar "Kode cocok" (figma v3: mitra/scan qr - kode cocok).
/// balikin true kalau mitra nyerahin pesanannya
Future<bool> konfirmasiSerahkan(
  BuildContext context,
  Map<String, dynamic> pesanan,
) async {
  final List isi = pesanan['isi'];
  final serahkan = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Warna.softGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Warna.hijau, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kode cocok',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Warna.hijau,
                        ),
                      ),
                      Text(
                        pesanan['kode'],
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Warna.teks,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Warna.softGreen,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Lunas · ${MetodeBayar.isVa(pesanan['metode']) ? 'VA' : MetodeBayar.nama(pesanan['metode'])}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Warna.hijau,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Warna.latar,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _Baris('Pembeli', namaPembeli(pesanan['idAkun'])),
                  const SizedBox(height: 8),
                  _Baris(
                    'Isi',
                    [
                      for (final item in isi)
                        '${item['jumlah']}× ${item['nama']}',
                    ].join('\n'),
                  ),
                  const SizedBox(height: 8),
                  _Baris(
                    'Penerimaan bersih',
                    rupiah(penerimaanBersih(pesanan)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.pop(sheetContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Warna.hijau,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Serahkan dan selesaikan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(sheetContext, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Warna.teks,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Pindai kode lain',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return serahkan == true;
}

/// pesanan diserahin ke pembeli: selesai diambil (F-20)
void selesaikanPesanan(BuildContext context, Map<String, dynamic> pesanan) {
  context.read<PesananBloc>().add(
    StatusPesananDiubah(pesanan['id'], StatusPesanan.selesai),
  );
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text('${pesanan['kode']} selesai diambil')),
    );
}

class _Baris extends StatelessWidget {
  const _Baris(this.label, this.nilai);

  final String label;
  final String nilai;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Warna.teksPendukung),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            nilai,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Warna.teks,
            ),
          ),
        ),
      ],
    );
  }
}

/// ketik kode ambil manual kalau QR ga kebaca (figma v3: mitra/scan qr - ketik kode, F-46)
class KetikKode extends StatefulWidget {
  const KetikKode({super.key});

  @override
  State<KetikKode> createState() => _KetikKodeState();
}

class _KetikKodeState extends State<KetikKode> {
  final kolom = TextEditingController();
  final fokus = FocusNode();
  String? galat;

  @override
  void initState() {
    super.initState();
    kolom.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    kolom.dispose();
    fokus.dispose();
    super.dispose();
  }

  Future<void> cek() async {
    final hasil = cariKode(context, kolom.text);
    if (hasil.pesanan == null) {
      setState(() => galat = hasil.galat);
      return;
    }
    setState(() => galat = null);
    fokus.unfocus();
    final serahkan = await konfirmasiSerahkan(context, hasil.pesanan!);
    if (!mounted) return;
    if (serahkan) {
      selesaikanPesanan(context, hasil.pesanan!);
      context.pop();
    } else {
      // pindai kode lain: kosongin kolomnya
      kolom.clear();
      fokus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final teks = kolom.text;
    final lengkap = teks.length == 4;

    return Scaffold(
      backgroundColor: Warna.latar,
      appBar: AppBar(
        backgroundColor: Warna.latar,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 4,
        title: const Text(
          'Ketik kode ambil',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Warna.teks,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const Text(
            'Ketik 4 karakter setelah SR- yang tampil di HP pembeli.',
            style: TextStyle(fontSize: 14, color: Warna.teksPendukung),
          ),
          const SizedBox(height: 20),
          // satu kolom isian yg ga keliatan, kotak-kotaknya cuma nampilin hurufnya
          GestureDetector(
            onTap: () => fokus.requestFocus(),
            child: Stack(
              children: [
                Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: kolom,
                    focusNode: fokus,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                      LengthLimitingTextInputFormatter(4),
                      TextInputFormatter.withFunction(
                        (lama, baru) =>
                            baru.copyWith(text: baru.text.toUpperCase()),
                      ),
                    ],
                    onChanged: (_) => setState(() => galat = null),
                    onSubmitted: (_) => lengkap ? cek() : null,
                  ),
                ),
                Row(
                  children: [
                    const Text(
                      'SR-',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Warna.teksPendukung,
                      ),
                    ),
                    const SizedBox(width: 8),
                    for (var i = 0; i < 4; i++) ...[
                      Expanded(
                        child: Container(
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: galat != null
                                  ? Warna.merah
                                  : (i == teks.length
                                        ? Warna.hijau
                                        : Warna.garisKontrol),
                              width: i == teks.length || galat != null ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            i < teks.length ? teks[i] : '',
                            style: const TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Warna.teks,
                            ),
                          ),
                        ),
                      ),
                      if (i < 3) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (galat != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, size: 18, color: Warna.merah),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    galat!,
                    style: const TextStyle(fontSize: 13, color: Warna.merah),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: lengkap ? cek : null,
              style: FilledButton.styleFrom(
                backgroundColor: Warna.hijau,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                galat == null ? 'Cek kode' : 'Cek ulang',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () => context.pushReplacement(Rute.mitraScan),
              icon: const Icon(Icons.qr_code_scanner, size: 20),
              label: const Text('Pindai pakai kamera'),
              style: TextButton.styleFrom(
                foregroundColor: Warna.hijau,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
