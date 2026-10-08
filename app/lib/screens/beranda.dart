import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/cubit/keranjang_cubit.dart';
import 'package:sisa_rasa/cubit/paket_cubit.dart';
import 'package:sisa_rasa/router.dart';
import 'package:sisa_rasa/theme/tema.dart';
import 'package:sisa_rasa/utils/format.dart';
import 'package:sisa_rasa/widgets/baris_paket.dart';
import 'package:sisa_rasa/widgets/kartu_paket_besar.dart';
import 'package:sisa_rasa/widgets/konfirmasi_ganti_mitra.dart';
import 'package:sisa_rasa/widgets/navigasi_melayang.dart';

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

  void bukaCari() {
    // context.push: buka halaman cari, rutenya diatur di router.dart
    context.push(Rute.cari);
  }

  /// tombol + di baris paket: tambah 1 porsi langsung tanpa buka detail
  Future<void> tambahCepat(Map<String, dynamic> paket) async {
    final keranjangCubit = context.read<KeranjangCubit>();
    // satu pesanan cuma boleh dari satu mitra, kalau beda ditanya dulu (F-07)
    final gantiMitra = await cekGantiMitra(context, paket);
    if (gantiMitra == null || !mounted) return;

    keranjangCubit.tambah(paket, 1, gantiMitra: gantiMitra);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${paket['nama']} masuk keranjang')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    // context.watch: ambil daftar paket dari PaketCubit, kalau stoknya berubah beranda ikut digambar ulang
    final daftarPaket = context.watch<PaketCubit>().state;
    // keranjang ikut dipantau biar tombol + nonaktif kalau porsinya udah mentok
    final keranjang = context.watch<KeranjangCubit>().state;

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

    Widget baris(Map<String, dynamic> paket) {
      return BarisPaket(
        paket: paket,
        onTap: () => widget.onBukaPaket(paket),
        onTambah: () => tambahCepat(paket),
        bisaTambah: (keranjang[paket['id']] ?? 0) < (paket['sisaPorsi'] as int),
      );
    }

    // SafeArea: biar ga ketutup status bar
    return SafeArea(
      // ListView: list yg bisa discroll ke bawah
      child: ListView(
        // bawahnya dikasih jarak gede biar item terakhir ga ketutup navigasi + bar keranjang
        padding: const EdgeInsets.fromLTRB(
          16,
          8,
          16,
          NavigasiMelayang.ruangBawahKeranjang,
        ),
        children: [
          // Row: nyusun widget ke samping (horizontal)
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 20),
              const SizedBox(width: 6),
              // Text: nampilin tulisan
              Text(
                'Samarinda Ulu',
                style: teks.labelLarge?.copyWith(fontSize: 15),
              ),
              const Icon(Icons.keyboard_arrow_down),
              // Spacer: ngisi ruang kosong, jadi tombol di kanannya kedorong ke ujung
              const Spacer(),
              // IconButton: icon favorit, halamannya belum ada
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
            maxLines: 1,
            style: teks.displaySmall,
          ),
          const SizedBox(height: 6),
          Text(
            '$totalPorsi porsi dari $jumlahDapur dapur di sekitarmu, siap diambil sebelum mereka tutup.',
            style: teks.bodyMedium?.copyWith(
              height: 1.45,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // TextField: kolom cari selalu tampil, diketuk langsung pindah ke halaman cari
          TextField(
            readOnly: true,
            onTap: bukaCari,
            decoration: const InputDecoration(
              hintText: 'Cari paket atau mitra',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),

          // SingleChildScrollView: chip kategori bisa digeser ke samping
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final nama in kategori) ...[
                  ChoiceChip(
                    label: Text(nama),
                    selected: nama == kategoriDipilih,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => kategoriDipilih = nama),
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
                  Icon(
                    Icons.restaurant_outlined,
                    size: 56,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada paket ${kategoriDipilih.toLowerCase()} sore ini',
                    textAlign: TextAlign.center,
                    style: teks.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Paket biasanya muncul menjelang sore, setelah mitra menghitung sisa jualannya.',
                    textAlign: TextAlign.center,
                    style: teks.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
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

          // kelompok "Sekarang": satu kartu besar, sisanya baris tenang
          if (sekarang.isNotEmpty) ...[
            _HeaderJam(
              judul: 'Sekarang',
              keterangan: 'Tutup paling cepat ${jam(sekarang.first['tutup'])}',
              sudahBuka: true,
            ),
            KartuPaketBesar(
              paket: sekarang.first,
              onTap: () => widget.onBukaPaket(sekarang.first),
            ),
            const SizedBox(height: 4),
            for (final paket in sekarang.skip(1)) baris(paket),
            const SizedBox(height: 16),
          ],

          // kelompok per jam pake baris tenang
          for (final jamMulai in urutanJam) ...[
            _HeaderJam(
              judul: jam(jamMulai),
              keterangan:
                  'Buka ${sisaWaktu(nanti[jamMulai]!.first['mulai'])} lagi',
            ),
            for (final paket in nanti[jamMulai]!) baris(paket),
            const SizedBox(height: 16),
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
    final cs = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;
    final warna = SisaRasaColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            judul,
            style: teks.headlineSmall?.copyWith(
              fontFeatures: SisaRasaText.tabular,
            ),
          ),
          // titik ijo tanda udah buka
          if (sudahBuka) ...[
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: cs.primary,
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
              style: teks.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: sudahBuka ? warna.urgent : cs.onSurfaceVariant,
                fontFeatures: SisaRasaText.tabular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
