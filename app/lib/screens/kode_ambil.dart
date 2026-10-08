import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sisa_rasa/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/cubit/akun_cubit.dart';
import 'package:sisa_rasa/data/status_pesanan.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';

/// kode QR layar penuh buat dipindai kasir (figma v3: pembeli/pesanan - kode qr).
/// kalau ada beberapa pesanan aktif, bisa digeser ke kode pesanan lain
class KodeAmbil extends StatefulWidget {
  const KodeAmbil({required this.kode, super.key});

  /// kode yg dibuka pertama kali
  final String kode;

  @override
  State<KodeAmbil> createState() => _KodeAmbilState();
}

class _KodeAmbilState extends State<KodeAmbil> {
  late final PageController halaman;
  late final List<Map<String, dynamic>> daftar;
  var posisi = 0;

  @override
  void initState() {
    super.initState();
    // pesanan yg udah dibayar tapi belum diambil, punya akun yg lagi dipake.
    // diambil sekali aja biar urutan halamannya ga loncat pas statusnya berubah
    daftar = [
      for (final pesanan in PesananBloc.milik(
        context.read<PesananBloc>().state,
        context.read<AkunCubit>().state['id']!,
      ))
        if (pesanan['kode'] != null &&
            StatusPesanan.berlangsung(pesanan['status']))
          pesanan,
    ];
    posisi = daftar.indexWhere((p) => p['kode'] == widget.kode);
    // kodenya ga ada di daftar aktif (misal udah selesai): tampilin kode itu aja
    if (posisi < 0) {
      daftar
        ..clear()
        ..addAll(
          context.read<PesananBloc>().state.where(
            (p) => p['kode'] == widget.kode,
          ),
        );
      posisi = 0;
    }
    halaman = PageController(initialPage: posisi);
  }

  @override
  void dispose() {
    halaman.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Tutup',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close),
        ),
        title: const Text(
          'Kode ambil',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Warna.teks,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: daftar.isEmpty
                  ? const Center(child: Text('Kode tidak ditemukan'))
                  : PageView(
                      controller: halaman,
                      onPageChanged: (i) => setState(() => posisi = i),
                      children: [
                        for (final pesanan in daftar) _Kode(pesanan: pesanan),
                      ],
                    ),
            ),
            if (daftar.length > 1) ...[
              // titik halaman, yg aktif lebih panjang
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < daftar.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == posisi ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == posisi ? Warna.teks : Warna.garis,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Geser untuk kode pesanan lain (${posisi + 1} dari ${daftar.length})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Warna.teksPendukung,
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Warna.teks,
                    side: const BorderSide(color: Warna.garisKontrol),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Selesai',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// satu halaman: QR, kode, isi pesanan sama jam ambil
class _Kode extends StatelessWidget {
  const _Kode({required this.pesanan});

  final Map<String, dynamic> pesanan;

  @override
  Widget build(BuildContext context) {
    final List isi = pesanan['isi'];
    // nama paket dipendekin biar chip nya muat satu baris
    final namaPaket = (isi[0]['nama'] as String).split(' ').take(2).join(' ');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 48),
          Text(
            'Tunjukkan ke kasir ${pesanan['mitra']}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Warna.teksPendukung,
            ),
          ),
          const SizedBox(height: 12),
          // QrImageView: qr asli, isinya kode ambil jadi bisa dipindai kasir
          QrImageView(
            data: pesanan['kode'],
            size: 240,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Warna.teks,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Warna.teks,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            pesanan['kode'],
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 34,
              letterSpacing: 4,
              fontWeight: FontWeight.w700,
              color: Warna.teks,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(
                ikon: Icons.inventory_2_outlined,
                teks:
                    '${isi[0]['jumlah']}× $namaPaket${isi.length > 1 ? ' +${isi.length - 1}' : ''}',
              ),
              _Chip(
                ikon: Icons.schedule,
                teks: '${jam(pesanan['mulai'])} – ${jam(pesanan['tutup'])}',
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.ikon, required this.teks});

  final IconData ikon;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Warna.latar,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 16, color: Warna.teks),
          const SizedBox(width: 6),
          Text(
            teks,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Warna.teks,
            ),
          ),
        ],
      ),
    );
  }
}
