import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/cubit/akun_cubit.dart';
import 'package:sisa_rasa/cubit/paket_cubit.dart';
import 'package:sisa_rasa/data/dummy_akun.dart';
import 'package:sisa_rasa/data/pembayaran.dart';
import 'package:sisa_rasa/data/status_pesanan.dart';
import 'package:sisa_rasa/router.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';

/// ruang bawah daftar mitra biar item terakhir ga ketutup navigasi + tombol pindai
const ruangBawahMitra = 116.0;

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
    final akun = context.watch<AkunCubit>().state;
    final String nama = akun['nama']!;
    final paketCubit = context.watch<PaketCubit>();
    final semuaPesanan = pesananMitra(context, nama);

    final paket = [
      for (final p in paketCubit.state)
        if (p['mitra'] == nama && p['tutup'] > jamSekarang) p,
    ];
    final jenis = paket.isEmpty ? 'Mitra' : paket.first['jenisMitra'];
    final buka = paketCubit.geraiBuka(nama);

    // ringkasan hari ini (F-21): porsi dari pesanan yg udah diambil,
    // pendapatan bersih dari yg selesai / tidak diambil (F-48)
    var porsi = 0;
    var pendapatan = 0;
    for (final p in semuaPesanan) {
      if (p['status'] == StatusPesanan.selesai) porsi += p['porsi'] as int;
      if (p['status'] == StatusPesanan.selesai ||
          p['status'] == StatusPesanan.tidakDiambil) {
        pendapatan += penerimaanBersih(p);
      }
    }
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
                    Row(
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
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      jamSekarang < 18 * 60
                          ? 'Dapur sore ini'
                          : 'Dapur malam ini',
                      style: const TextStyle(
                        fontSize: 28,
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

          // gerai buka / tutup sementara (F-51)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Warna.garis),
              borderRadius: BorderRadius.circular(20),
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

          // kartu hijau: ringkasan hari ini (F-21)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Warna.momen,
              borderRadius: BorderRadius.circular(24),
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
                        fontSize: 40,
                        height: 44 / 40,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'porsi terselamatkan hari ini',
                        style: TextStyle(fontSize: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28, color: Colors.white24),
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
              color: Colors.white,
            ),
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
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
        borderRadius: BorderRadius.circular(20),
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
    final pembeli = namaPembeli(pesanan['idAkun']);
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
            child: Image.asset(
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
                color: Warna.teks,
              ),
            ),
          ),
          IconButton.outlined(
            tooltip: 'Tambah sisa ${paket['nama']}',
            onPressed: () => cubit.ubahSisa(paket['id'], sisa + 1),
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}
