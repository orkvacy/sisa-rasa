import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/presentation/widgets/tombol_jumlah.dart';
import 'package:sisa_rasa/presentation/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/presentation/cubit/akun_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/paket_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/saldo_cubit.dart';
import 'package:sisa_rasa/domain/aturan/status_pesanan.dart';
import 'package:sisa_rasa/presentation/router.dart';
import 'package:sisa_rasa/core/theme/warna.dart';
import 'package:sisa_rasa/core/utils/format.dart';
import 'package:sisa_rasa/domain/repositories/layanan_admin.dart';
import 'package:sisa_rasa/presentation/widgets/gambar_paket.dart';

/// ruang bawah daftar mitra: isi tab berhenti di atas navigasi,
/// tapi tombol pindai nongol ke atas sedikit
const ruangBawahMitra = 40.0;

/// pesanan milik mitra yg lagi masuk, dari semua pembeli
List<Map<String, dynamic>> pesananMitra(BuildContext context, String mitra) {
  return [
    for (final p in context.watch<PesananBloc>().state)
      if (p['mitra'] == mitra) p,
  ];
}

/// dasbor mitra (figma v3: mitra/dasbor, F-21, F-44, F-51)
class Dasbor extends StatelessWidget {
  const Dasbor({super.key});

  @override
  Widget build(BuildContext context) {
    // sesaat abis keluar, layar ini masih sempet digambar sekali sebelum router pindah
    final nama = context.watch<AkunCubit>().state['nama'];
    if (nama == null) return const SizedBox.shrink();
    final paketCubit = context.watch<PaketCubit>();
    final semuaPesanan = pesananMitra(context, nama);

    final paket = [
      for (final p in paketCubit.state)
        if (p['mitra'] == nama &&
            p['tutup'] > jamSekarang &&
            p['nonaktif'] != true)
          p,
    ];
    final jenis = paket.isEmpty ? 'Mitra' : paket.first['jenisMitra'];
    final buka = paketCubit.geraiBuka(nama);

    // ringkasan hari ini (F-21): porsi dari pesanan yg udah diambil,
    // pendapatan bersih = dana masuk hari ini di riwayat saldo (F-48),
    // jadi angkanya sama kayak di tab Saldo
    var porsi = 0;
    for (final p in semuaPesanan) {
      if (p['status'] == StatusPesanan.selesai) porsi += p['porsi'] as int;
    }
    final pendapatan = context
        .watch<SaldoCubit>()
        .riwayat(nama, context.watch<PesananBloc>().state)
        .where(
          (e) =>
              e['jenis'] == 'masuk' &&
              kelompokTanggal(e['waktu']) == 'Hari ini',
        )
        .fold<int>(0, (n, e) => n + (e['jumlah'] as int));
    final antrean = [
      for (final p in semuaPesanan)
        if (p['status'] == StatusPesanan.disiapkan ||
            p['status'] == StatusPesanan.siapDiambil)
          p,
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, ruangBawahMitra),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => context.push(Rute.mitraProfilUsaha),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.storefront_outlined,
                              size: 16,
                              color: Warna.teksPendukung,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '$nama · $jenis',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Warna.teksPendukung,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: Warna.teksPendukung,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      jamSekarang < 18 * 60
                          ? 'Dapur sore ini'
                          : 'Dapur malam ini',
                      style: const TextStyle(
                        fontSize: 22,
                        height: 34 / 28,
                        letterSpacing: -0.4,
                        fontWeight: FontWeight.w800,
                        color: Warna.teks,
                      ),
                    ),
                  ],
                ),
              ),
              // avatar: buka halaman akun (ganti akun, keluar)
              Semantics(
                button: true,
                label: 'Akun',
                child: InkWell(
                  key: const Key('akun-mitra'),
                  onTap: () => context.push(Rute.mitraAkun),
                  customBorder: const CircleBorder(),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Warna.softGreen,
                    child: Text(
                      inisial(nama),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Warna.hijau,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _BannerVerifikasi(),

          // gerai buka / tutup sementara (F-51)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Warna.garis),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: buka ? Warna.hijau : Warna.garisKontrol,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            buka ? 'Gerai buka' : 'Gerai tutup sementara',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Warna.teks,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        buka
                            ? 'Paketmu tampil untuk pembeli'
                            : 'Paketmu disembunyikan dari pembeli',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Warna.teksPendukung,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: buka,
                  activeTrackColor: Warna.hijau,
                  onChanged: (nilai) =>
                      context.read<PaketCubit>().aturGerai(nama, buka: nilai),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // kartu ringkasan hari ini (F-21): putih, cuma angka porsinya yg hijau
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Warna.kartu,
              border: Border.all(color: Warna.garis),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '$porsi',
                      style: const TextStyle(
                        fontSize: 30,
                        height: 44 / 40,
                        fontWeight: FontWeight.w800,
                        color: Warna.hijau,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'porsi terselamatkan hari ini',
                        style: TextStyle(fontSize: 14, color: Warna.teks),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28, color: Warna.garis),
                Row(
                  children: [
                    Expanded(
                      child: _Angka(
                        nilai:
                            '${paket.where((p) => p['sisaPorsi'] > 0).length}',
                        label: 'paket aktif',
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _Angka(
                        nilai: rupiah(pendapatan),
                        label: 'pendapatan bersih',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // antrean ambil: pesanan yg udah dibayar, belum diambil
          _JudulBagian(
            judul: 'Antrean ambil',
            aksi: 'Semua (${antrean.length})',
            onAksi: () => context.go(Rute.mitraPesanan),
          ),
          const SizedBox(height: 10),
          _Kartu(
            children: antrean.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Belum ada pesanan yang perlu disiapkan.',
                        style: TextStyle(color: Warna.teksPendukung),
                      ),
                    ),
                  ]
                : [
                    for (final p in antrean.take(3)) ...[
                      _BarisAntrean(
                        pesanan: p,
                        onTap: () =>
                            context.push(Rute.mitraDetailPesanan(p['id'])),
                      ),
                      if (p != antrean.take(3).last)
                        const Divider(height: 1, color: Warna.garis),
                    ],
                  ],
          ),
          const SizedBox(height: 20),

          // paket aktif: sisa porsi bisa diubah langsung (F-44)
          _JudulBagian(
            judul: 'Paket aktif',
            aksi: 'Kelola',
            onAksi: () => context.go(Rute.mitraPaket),
          ),
          const SizedBox(height: 10),
          _Kartu(
            children: paket.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Belum ada paket aktif hari ini.',
                        style: TextStyle(color: Warna.teksPendukung),
                      ),
                    ),
                  ]
                : [
                    for (final p in paket) ...[
                      _BarisPaket(paket: p),
                      if (p != paket.last)
                        const Divider(height: 1, color: Warna.garis),
                    ],
                  ],
          ),
        ],
      ),
    );
  }
}

class _Angka extends StatelessWidget {
  const _Angka({required this.nilai, required this.label});

  final String nilai;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            nilai,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Warna.teks,
            ),
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Warna.teksPendukung),
        ),
      ],
    );
  }
}

class _JudulBagian extends StatelessWidget {
  const _JudulBagian({
    required this.judul,
    required this.aksi,
    required this.onAksi,
  });

  final String judul;
  final String aksi;
  final VoidCallback onAksi;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            judul,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Warna.teks,
            ),
          ),
        ),
        TextButton(
          onPressed: onAksi,
          child: Text(
            aksi,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Warna.hijau,
            ),
          ),
        ),
      ],
    );
  }
}

class _Kartu extends StatelessWidget {
  const _Kartu({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Warna.garis),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// satu pesanan di antrean: inisial pembeli, isi, kode, status
class _BarisAntrean extends StatelessWidget {
  const _BarisAntrean({required this.pesanan, required this.onTap});

  final Map<String, dynamic> pesanan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pembeli = pesanan['namaPembeli'];
    final List isi = pesanan['isi'];
    final siap = pesanan['status'] == StatusPesanan.siapDiambil;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Warna.softGreen,
              child: Text(
                inisial(pembeli.replaceAll('.', '')),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Warna.hijau,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pembeli,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Warna.teks,
                    ),
                  ),
                  Text(
                    '${isi[0]['jumlah']}× ${isi[0]['nama']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Warna.teksPendukung,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  pesanan['kode'],
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Warna.teks,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: siap ? Warna.softGreen : Warna.mendesakLembut,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    siap ? 'Siap diambil' : 'Perlu disiapkan',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: siap ? Warna.hijau : Warna.mendesak,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// satu paket aktif dengan tombol - sisa + (F-44)
class _BarisPaket extends StatelessWidget {
  const _BarisPaket({required this.paket});

  final Map<String, dynamic> paket;

  @override
  Widget build(BuildContext context) {
    final int sisa = paket['sisaPorsi'];
    final cubit = context.read<PaketCubit>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GambarPaket(
              paket['foto'],
              width: 52,
              height: 52,
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Warna.teks,
                  ),
                ),
                Text(
                  '${jam(paket['mulai'])} – ${jam(paket['tutup'])}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Warna.teksPendukung,
                  ),
                ),
              ],
            ),
          ),
          PengaturJumlah(
            jumlah: sisa,
            labelKurang: 'Kurangi sisa ${paket['nama']}',
            labelTambah: 'Tambah sisa ${paket['nama']}',
            onKurang: sisa > 0
                ? () => cubit.ubahSisa(paket['id'], sisa - 1)
                : null,
            onTambah: () => cubit.ubahSisa(paket['id'], sisa + 1),
          ),
        ],
      ),
    );
  }
}

/// F-37: mitra yang belum diverifikasi admin dikasih tau kenapa paketnya
/// belum keliatan pembeli. dicek ulang tiap daftar paket dimuat ulang (20 detik),
/// jadi begitu admin nyetujuin bannernya ilang sendiri
class _BannerVerifikasi extends StatefulWidget {
  const _BannerVerifikasi();

  @override
  State<_BannerVerifikasi> createState() => _BannerVerifikasiState();
}

class _BannerVerifikasiState extends State<_BannerVerifikasi> {
  Map<String, dynamic>? _status;
  late final StreamSubscription<Object?> _paket;

  @override
  void initState() {
    super.initState();
    final paket = context.read<PaketCubit>();
    _paket = paket.stream.listen((_) => _cek(paket));
    _cek(paket);
  }

  Future<void> _cek(PaketCubit paket) async {
    final status = await paket.statusGerai();
    if (mounted && status != null) setState(() => _status = status);
  }

  @override
  void dispose() {
    _paket.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status?['status'];
    if (status == null || status == StatusGerai.terverifikasi) {
      return const SizedBox.shrink();
    }
    final alasan = _status?['alasan'] as String?;
    final menunggu = status == StatusGerai.menunggu;
    final (judul, isi) = switch (status) {
      StatusGerai.menunggu => (
        'Akunmu sedang diverifikasi',
        'Tim Sisa Rasa memeriksa data usahamu. Paket yang kamu buat '
            'baru tampil ke pembeli setelah terverifikasi.',
      ),
      StatusGerai.ditolak => (
        'Pendaftaran belum disetujui',
        'Hubungi admin Sisa Rasa untuk memperbaiki datamu.',
      ),
      _ => (
        'Akunmu dinonaktifkan',
        'Paketmu tidak tampil ke pembeli. Hubungi admin Sisa Rasa.',
      ),
    };
    return Container(
      key: const Key('banner-verifikasi'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: menunggu ? Warna.mendesakLembut : Warna.merahLembut,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            menunggu ? Icons.hourglass_top : Icons.error_outline,
            size: 20,
            color: menunggu ? Warna.mendesak : Warna.merah,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  judul,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Warna.teks,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [isi, if (alasan != null) 'Alasan: $alasan'].join('\n'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Warna.teksPendukung,
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
