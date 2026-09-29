import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/cubit/paket_cubit.dart';
import 'package:sisa_rasa/screens/cari.dart';
import 'package:sisa_rasa/theme/teks.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';
import 'package:sisa_rasa/widgets/kartu_paket.dart';
import 'package:sisa_rasa/widgets/kartu_paket_besar.dart';

/// landing page, paketnya dikelompokin per jam buka
class Beranda extends StatefulWidget {
  const Beranda({required this.onBukaPaket, super.key});

  final ValueChanged<Map<String, dynamic>> onBukaPaket;

  @override
  State<Beranda> createState() => _BerandaState();
}

class _BerandaState extends State<Beranda> {
  final kategori = [
    'Semua',
    'Nasi & lauk',
    'Roti & kue',
    'Buffet hotel',
    'Minuman',
  ];
  String kategoriDipilih = 'Semua';

  @override
  Widget build(BuildContext context) {
    // context.watch: ambil daftar paket dari PaketCubit, kalau stoknya berubah beranda ikut digambar ulang
    final daftarPaket = context.watch<PaketCubit>().state;

    // paket yg udah tutup ga ditampilin, terus disaring sesuai chip kategori
    final tampil = daftarPaket.where((paket) {
      return paket['tutup'] > jamSekarang &&
          (kategoriDipilih == 'Semua' || paket['kategori'] == kategoriDipilih);
    }).toList();

    // yg udah buka masuk "Sekarang", sisanya dikelompokin per jam mulainya
    final sekarang = <Map<String, dynamic>>[];
    final nanti = <int, List<Map<String, dynamic>>>{};
    for (final paket in tampil) {
      if (sudahBuka(paket)) {
        sekarang.add(paket);
      } else {
        final jamMulai = paket['mulai'] ~/ 60 * 60;
        nanti[jamMulai] = [...?nanti[jamMulai], paket];
      }
    }
    sekarang.sort((a, b) => a['tutup'].compareTo(b['tutup']));
    final urutanJam = nanti.keys.toList()..sort();

    var totalPorsi = 0;
    for (final paket in tampil) {
      totalPorsi += paket['sisaPorsi'] as int;
    }
    final jumlahDapur = tampil.map((paket) => paket['mitra']).toSet().length;

    // SafeArea: biar ga ketutup status bar
    return SafeArea(
      // ListView: list yg bisa discroll ke bawah
      child: ListView(
        // bawahnya dikasih jarak gede biar kartu terakhir ga ketutup bar keranjang
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: [
          // Row: nyusun widget ke samping (horizontal)
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 20),
              const SizedBox(width: 6),
              // Text: nampilin tulisan
              const Text(
                'Samarinda Ulu',
                style: TextStyle(
                  fontSize: Teks.tombol,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down),
              // Spacer: ngisi ruang kosong, jadi tombol di kanannya kedorong ke ujung
              const Spacer(),
              // IconButton: icon cari, pindah ke halaman cari
              IconButton(
                tooltip: 'Cari paket',
                icon: const Icon(Icons.search),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          Cari(onBukaPaket: widget.onBukaPaket),
                    ),
                  );
                },
              ),
              // icon favorit, halamannya belum ada
              IconButton(
                tooltip: 'Mitra favorit',
                icon: const Icon(Icons.favorite_border),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    // SnackBar: pesan kecil yg muncul sebentar di bawah layar
                    const SnackBar(
                      content: Text(
                        'Mitra favorit belum tersedia di versi ini',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          // judul ikut jam, sebelum jam 6 sore "Sore ini"
          Text(
            jamSekarang < 18 * 60 ? 'Sore ini' : 'Malam ini',
            style: const TextStyle(
              fontSize: Teks.judulBesar,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$totalPorsi porsi dari $jumlahDapur dapur di sekitarmu, siap diambil sebelum mereka tutup.',
            style: const TextStyle(
              fontSize: Teks.isi,
              height: 1.45,
              color: Warna.teksPendukung,
            ),
          ),
          const SizedBox(height: 16),

          // SingleChildScrollView: chip kategori bisa digeser ke samping
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final nama in kategori) ...[
                  GestureDetector(
                    onTap: () => setState(() => kategoriDipilih = nama),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: nama == kategoriDipilih
                            ? Warna.gelap
                            : Colors.white,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: nama == kategoriDipilih
                              ? Warna.gelap
                              : Warna.garis,
                        ),
                      ),
                      child: Text(
                        nama,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: nama == kategoriDipilih
                              ? Colors.white
                              : Warna.teks,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // kalau kategori yg dipilih ga ada paketnya
          if (tampil.isEmpty)
            // Padding: ngasih jarak di sekeliling child nya
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              // Column: nyusun widget ke bawah (vertical)
              child: Column(
                children: [
                  const Icon(
                    Icons.restaurant_outlined,
                    size: 56,
                    color: Warna.teksPendukung,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada paket ${kategoriDipilih.toLowerCase()} sore ini',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: Teks.nama,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Paket biasanya muncul menjelang sore, setelah mitra menghitung sisa jualannya.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Warna.teksPendukung),
                  ),
                  const SizedBox(height: 16),
                  // OutlinedButton: tombol yg cuma ada garis pinggirnya
                  OutlinedButton(
                    onPressed: () => setState(() => kategoriDipilih = 'Semua'),
                    child: const Text('Lihat semua kategori'),
                  ),
                ],
              ),
            ),

          // kelompok "Sekarang" pake kartu gede
          if (sekarang.isNotEmpty) ...[
            _HeaderJam(
              judul: 'Sekarang',
              keterangan: 'Tutup paling cepat ${jam(sekarang.first['tutup'])}',
              sudahBuka: true,
            ),
            for (final paket in sekarang) ...[
              KartuPaketBesar(
                paket: paket,
                onTap: () => widget.onBukaPaket(paket),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
          ],

          // kelompok per jam pake kartu kecil
          for (final jamMulai in urutanJam) ...[
            _HeaderJam(
              judul: jam(jamMulai),
              keterangan:
                  'Buka ${sisaWaktu(nanti[jamMulai]!.first['mulai'])} lagi',
            ),
            for (final paket in nanti[jamMulai]!) ...[
              KartuPaket(paket: paket, onTap: () => widget.onBukaPaket(paket)),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// judul tiap kelompok: jamnya gede di kiri, keterangan di kanan
class _HeaderJam extends StatelessWidget {
  const _HeaderJam({
    required this.judul,
    required this.keterangan,
    this.sudahBuka = false,
  });

  final String judul;
  final String keterangan;
  final bool sudahBuka;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            judul,
            style: const TextStyle(
              fontSize: Teks.subjudul,
              fontWeight: FontWeight.w800,
            ),
          ),
          // titik ijo tanda udah buka
          if (sudahBuka) ...[
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Warna.hijau,
                shape: BoxShape.circle,
              ),
            ),
          ],
          const SizedBox(width: 12),
          // Expanded biar keterangannya turun baris kalau layarnya sempit
          Expanded(
            child: Text(
              keterangan,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: Teks.keterangan,
                fontWeight: FontWeight.w600,
                color: sudahBuka ? Warna.mendesak : Warna.teksPendukung,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
