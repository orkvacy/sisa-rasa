import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/bloc/pesanan_event.dart';
import 'package:sisa_rasa/cubit/akun_cubit.dart';
import 'package:sisa_rasa/data/dummy_akun.dart';
import 'package:sisa_rasa/data/pembayaran.dart';
import 'package:sisa_rasa/data/status_pesanan.dart';
import 'package:sisa_rasa/router.dart';
import 'package:sisa_rasa/screens/mitra/dasbor.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';

/// pesanan masuk mitra (figma v3: mitra/pesanan, F-19, F-20, F-43, F-47)
class PesananMasuk extends StatefulWidget {
  const PesananMasuk({super.key});

  @override
  State<PesananMasuk> createState() => _PesananMasukState();
}

class _PesananMasukState extends State<PesananMasuk> {
  static const _segmen = [
    StatusPesanan.disiapkan,
    StatusPesanan.siapDiambil,
    StatusPesanan.selesai,
  ];
  String segmen = StatusPesanan.disiapkan;

  @override
  Widget build(BuildContext context) {
    final mitra = context.watch<AkunCubit>().state['nama']!;
    final semua = pesananMitra(context, mitra);

    List<Map<String, dynamic>> dengan(String status) => [
      for (final p in semua)
        if (p['status'] == status) p,
    ];
    final daftar = dengan(segmen);
    final menungguBayar = dengan(StatusPesanan.menungguBayar).length;

    // rekap hari ini (F-47): pesanan selesai + penerimaan bersihnya
    final selesai = dengan(StatusPesanan.selesai);
    final bersih = selesai.fold<int>(0, (a, p) => a + penerimaanBersih(p));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, ruangBawahMitra),
        children: [
          const Text(
            'Pesanan masuk',
            style: TextStyle(
              fontSize: 28,
              height: 34 / 28,
              letterSpacing: -0.4,
              fontWeight: FontWeight.w800,
              color: Warna.teks,
            ),
          ),
          const SizedBox(height: 20),
          // rel krem tiga pilihan, yg aktif pil gelap + jumlahnya
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Warna.kraft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                for (final status in _segmen)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: segmen == status,
                      child: Material(
                        color: segmen == status
                            ? Warna.gelap
                            : Colors.transparent,
                        shape: const StadiumBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => setState(() => segmen = status),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 9,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    StatusPesanan.label(status),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: segmen == status
                                          ? Colors.white
                                          : Warna.teksPendukung,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: segmen == status
                                          ? Colors.white
                                          : Warna.latar,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '${dengan(status).length}',
                                      key: Key('jumlah-mitra-$status'),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Warna.teks,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (menungguBayar > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.schedule,
                  size: 16,
                  color: Warna.teksPendukung,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$menungguBayar pesanan lagi menunggu dibayar pembeli',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Warna.teksPendukung,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (daftar.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                switch (segmen) {
                  StatusPesanan.disiapkan =>
                    'Belum ada pesanan yang perlu disiapkan.',
                  StatusPesanan.siapDiambil =>
                    'Belum ada pesanan yang menunggu diambil.',
                  _ => 'Belum ada pesanan selesai hari ini.',
                },
                textAlign: TextAlign.center,
                style: const TextStyle(color: Warna.teksPendukung),
              ),
            ),
          for (final p in daftar) ...[
            _KartuPesanan(
              pesanan: p,
              onTap: () => context.push(Rute.mitraDetailPesanan(p['id'])),
            ),
            const SizedBox(height: 12),
          ],
          // rekap hari ini (F-47)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Warna.kraft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.bar_chart, color: Warna.teks),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rekap hari ini',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Warna.teks,
                        ),
                      ),
                      Text(
                        '${selesai.length} pesanan selesai · ${rupiah(bersih)} bersih',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Warna.teksPendukung,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// kartu satu pesanan: kode besar, isi, penerimaan bersih, tombol tahap berikutnya
class _KartuPesanan extends StatelessWidget {
  const _KartuPesanan({required this.pesanan, required this.onTap});

  final Map<String, dynamic> pesanan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String status = pesanan['status'];
    final List isi = pesanan['isi'];
    final bloc = context.read<PesananBloc>();

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Warna.garis),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pesanan['kode'],
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 22,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                        color: Warna.teks,
                      ),
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
                    child: const Text(
                      'Lunas',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Warna.hijau,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      pesanan['foto'],
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${isi[0]['jumlah']}× ${isi[0]['nama']}'
                          '${isi.length > 1 ? ' +${isi.length - 1} lainnya' : ''}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Warna.teks,
                          ),
                        ),
                        Text(
                          status == StatusPesanan.selesai &&
                                  pesanan['diambilPada'] != null
                              ? '${namaPembeli(pesanan['idAkun'])} · diambil ${tanggalSingkat(pesanan['diambilPada'])}'
                              : '${namaPembeli(pesanan['idAkun'])} · ambil ${jam(pesanan['mulai'])} – ${jam(pesanan['tutup'])}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Warna.teksPendukung,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Penerimaan bersih',
                          style: TextStyle(
                            fontSize: 12,
                            color: Warna.teksPendukung,
                          ),
                        ),
                        Text(
                          rupiah(penerimaanBersih(pesanan)),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Warna.teks,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (status != StatusPesanan.selesai)
                    SizedBox(
                      height: 48,
                      child: FilledButton.tonal(
                        onPressed: () => bloc.add(
                          StatusPesananDiubah(
                            pesanan['id'],
                            status == StatusPesanan.disiapkan
                                ? StatusPesanan.siapDiambil
                                : StatusPesanan.selesai,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Warna.softGreen,
                          foregroundColor: Warna.hijau,
                          // tema bikin tombol selebar layar, di sini seukuran isinya
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          status == StatusPesanan.disiapkan
                              ? 'Tandai siap'
                              : 'Sudah diambil',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
