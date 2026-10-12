import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/cubit/akun_cubit.dart';
import 'package:sisa_rasa/cubit/paket_cubit.dart';
import 'package:sisa_rasa/router.dart';
import 'package:sisa_rasa/screens/mitra/dasbor.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';

/// status satu paket dari sisi mitra
String statusPaket(Map<String, dynamic> paket) {
  if (paket['nonaktif'] == true) return 'Nonaktif';
  // F-25: lewat jam tutup tetep tampil di daftar mitra, tapi kedaluwarsa
  if (paket['tutup'] <= jamSekarang) return 'Kedaluwarsa';
  if (paket['sisaPorsi'] == 0) return 'Habis';
  return 'Aktif';
}

/// kelola paket mitra (figma v3: mitra/paket, F-14, F-44, F-45)
class PaketMitra extends StatefulWidget {
  const PaketMitra({super.key});

  @override
  State<PaketMitra> createState() => _PaketMitraState();
}

class _PaketMitraState extends State<PaketMitra> {
  static const _saring = ['Semua', 'Aktif', 'Habis', 'Nonaktif'];
  String saring = 'Semua';
  String cari = '';

  @override
  Widget build(BuildContext context) {
    final mitra = context.watch<AkunCubit>().state['nama']!;
    final semua = [
      for (final p in context.watch<PaketCubit>().state)
        if (p['mitra'] == mitra) p,
    ];

    int jumlah(String s) => s == 'Semua'
        ? semua.length
        : semua.where((p) => statusPaket(p) == s).length;

    final tampil = semua.where((p) {
      final cocokSaring = saring == 'Semua' || statusPaket(p) == saring;
      final cocokCari = (p['nama'] as String).toLowerCase().contains(
        cari.toLowerCase(),
      );
      return cocokSaring && cocokCari;
    }).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, ruangBawahMitra),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Paket',
                  style: TextStyle(
                    fontSize: 28,
                    height: 34 / 28,
                    letterSpacing: -0.4,
                    fontWeight: FontWeight.w800,
                    color: Warna.teks,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.push(Rute.mitraPaketBaru),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Paket baru'),
                style: FilledButton.styleFrom(
                  backgroundColor: Warna.hijau,
                  // tema bikin tombol selebar layar, di sini seukuran isinya
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (teks) => setState(() => cari = teks),
            decoration: const InputDecoration(
              hintText: 'Cari nama paket',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in _saring) ...[
                  ChoiceChip(
                    label: Text('$s ${jumlah(s)}'),
                    selected: saring == s,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => saring = s),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (tampil.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                semua.isEmpty
                    ? 'Belum ada paket. Tekan Paket baru untuk mulai menjual sisa makanan hari ini.'
                    : 'Tidak ada paket yang cocok.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Warna.teksPendukung),
              ),
            ),
          for (final p in tampil) ...[
            _KartuPaket(
              paket: p,
              onTap: () => context.push(Rute.mitraUbahPaket(p['id'])),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _KartuPaket extends StatelessWidget {
  const _KartuPaket({required this.paket, required this.onTap});

  final Map<String, dynamic> paket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PaketCubit>();
    final status = statusPaket(paket);
    final nonaktif = status == 'Nonaktif';
    final int sisa = paket['sisaPorsi'];
    final int total = paket['totalPorsi'];

    final (Color latarPil, Color warnaPil) = switch (status) {
      'Aktif' => (Warna.softGreen, Warna.hijau),
      'Habis' => (Warna.gelap, Colors.white),
      'Kedaluwarsa' => (Warna.garis, Warna.teksPendukung),
      _ => (Warna.kraft, Warna.teksPendukung),
    };

    return Opacity(
      // paket nonaktif dipudarin
      opacity: nonaktif ? 0.55 : 1,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Warna.garis),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        paket['foto'],
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            paket['nama'],
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Warna.teks,
                            ),
                          ),
                          Text(
                            '${jam(paket['mulai'])} – ${jam(paket['tutup'])} · ${rupiah(paket['hargaDiskon'])}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Warna.teksPendukung,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: latarPil,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: warnaPil,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // aktif / nonaktif (F-45)
                    Switch(
                      value: !nonaktif,
                      activeTrackColor: Warna.hijau,
                      onChanged: (aktif) =>
                          cubit.aturAktif(paket['id'], aktif: aktif),
                    ),
                  ],
                ),
                const Divider(height: 24, color: Warna.garis),
                // sisa porsi langsung dari daftar (F-44)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sisa porsi',
                            style: TextStyle(
                              fontSize: 12,
                              color: Warna.teksPendukung,
                            ),
                          ),
                          Text(
                            '$sisa dari $total',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Warna.teks,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: sisa > 0
                          ? () => cubit.ubahSisa(paket['id'], 0)
                          : onTap,
                      style: TextButton.styleFrom(foregroundColor: Warna.hijau),
                      child: Text(sisa > 0 ? 'Set habis' : 'Ubah'),
                    ),
                    IconButton.outlined(
                      tooltip: 'Kurangi sisa ${paket['nama']}',
                      onPressed: sisa > 0
                          ? () => cubit.ubahSisa(paket['id'], sisa - 1)
                          : null,
                      icon: const Icon(Icons.remove, size: 18),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text(
                        '$sisa',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton.outlined(
                      tooltip: 'Tambah sisa ${paket['nama']}',
                      // ga boleh lebih dari jumlah porsi yg diterbitkan
                      onPressed: sisa < total
                          ? () => cubit.ubahSisa(paket['id'], sisa + 1)
                          : null,
                      icon: const Icon(Icons.add, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
