import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/core/theme/warna.dart';
import 'package:sisa_rasa/core/utils/format.dart';
import 'package:sisa_rasa/presentation/cubit/favorit_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/paket_cubit.dart';
import 'package:sisa_rasa/presentation/router.dart';
import 'package:sisa_rasa/presentation/widgets/animasi.dart';
import 'package:sisa_rasa/presentation/widgets/gambar_paket.dart';

/// daftar mitra favorit (figma v3: pembeli/mitra favorit).
/// mitra yang sore ini ga punya paket tetap tampil, tapi ga bisa dibuka
class MitraFavorit extends StatelessWidget {
  const MitraFavorit({super.key});

  @override
  Widget build(BuildContext context) {
    final favorit = context.watch<FavoritCubit>().state;
    final semuaPaket = context.watch<PaketCubit>().state;

    return Scaffold(
      backgroundColor: Warna.latar,
      appBar: AppBar(
        backgroundColor: Warna.latar,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 4,
        title: const Text(
          'Mitra favorit',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Warna.teks,
          ),
        ),
      ),
      body: favorit.isEmpty
          ? const _Kosong()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: favorit.length,
              itemBuilder: (context, i) {
                final mitra = favorit[i];
                final paket = [
                  for (final p in semuaPaket)
                    if (kunciMitra(p) == mitra['id'] &&
                        PaketCubit.tampilUntukPembeli(p) &&
                        (p['sisaPorsi'] as int) > 0)
                      p,
                ];
                return MunculBertahap(
                  key: ValueKey(mitra['id']),
                  urutan: i,
                  child: _BarisFavorit(mitra: mitra, paket: paket),
                );
              },
            ),
    );
  }
}

class _BarisFavorit extends StatelessWidget {
  const _BarisFavorit({required this.mitra, required this.paket});

  final Map<String, dynamic> mitra;
  final List<Map<String, dynamic>> paket;

  @override
  Widget build(BuildContext context) {
    final adaPaket = paket.isNotEmpty;
    final nama = mitra['nama'] as String;
    final keterangan = [
      mitra['jenis'],
      if (adaPaket) paket.first['jarak'],
      if (adaPaket) '${paket.length} paket',
    ].where((e) => e != null && '$e'.isNotEmpty).join(' · ');

    return InkWell(
      onTap: adaPaket ? () => context.push(Rute.mitra(nama)) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Warna.garis)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 64,
                child: adaPaket
                    ? GambarPaket(paket.first['foto'], fit: BoxFit.cover)
                    : const ColoredBox(
                        color: Warna.kraft,
                        child: Icon(
                          Icons.storefront_outlined,
                          color: Warna.teksPendukung,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nama,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Warna.teks,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    keterangan,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Warna.teksPendukung,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (adaPaket)
                    Text.rich(
                      TextSpan(
                        text:
                            'Tutup ${jam(paket.map((p) => p['tutup'] as int).reduce(max))}',
                        style: const TextStyle(color: Warna.teksPendukung),
                        children: [
                          const TextSpan(text: '  '),
                          TextSpan(
                            text:
                                'mulai ${rupiah(paket.map((p) => p['hargaDiskon'] as int).reduce(min))}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Warna.teks,
                            ),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 13),
                    )
                  else
                    const Text(
                      'Belum ada paket sore ini',
                      style: TextStyle(
                        fontSize: 13,
                        color: Warna.teksPendukung,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Hapus $nama dari favorit',
              onPressed: () => context.read<FavoritCubit>().ganti({
                'idMitra': mitra['id'],
                'mitra': nama,
                'jenisMitra': mitra['jenis'],
              }),
              icon: const Icon(Icons.favorite, color: Warna.merah, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.favorite_border,
              size: 40,
              color: Warna.teksPendukung,
            ),
            const SizedBox(height: 12),
            const Text(
              'Belum ada mitra favorit',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Warna.teks,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ketuk ikon hati di halaman mitra untuk menyimpannya di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Warna.teksPendukung),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.go(Rute.beranda),
              style: OutlinedButton.styleFrom(
                foregroundColor: Warna.hijau,
                side: const BorderSide(color: Warna.hijau),
                // tema bikin tombol outlined selebar layar, di sini seukuran isinya
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Cari mitra'),
            ),
          ],
        ),
      ),
    );
  }
}
