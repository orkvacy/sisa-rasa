import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/cubit/paket_cubit.dart';
import 'package:sisa_rasa/router.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';
import 'package:sisa_rasa/widgets/navigasi_melayang.dart';

/// beranda pembeli (figma v3: pembeli/beranda - mitra).
/// isinya daftar mitra, bukan paket: Flash sale buat yg tutup kurang dari 1 jam (F-53),
/// sisanya di Mitra sekitar, diurutin dari jam tutup terdekat (F-01)
class Beranda extends StatefulWidget {
  const Beranda({required this.onBukaMitra, super.key});

  final ValueChanged<String> onBukaMitra;

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

  void _segeraHadir(String fitur) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$fitur belum tersedia di versi ini')),
      );
  }

  @override
  Widget build(BuildContext context) {
    // context.watch: kalau stok paket berubah, beranda ikut digambar ulang (F-28)
    final daftarPaket = context.watch<PaketCubit>().state;

    // paket yg masih bisa dipesan: belum lewat jam tutup, masih ada porsinya (F-25),
    // terus disaring sesuai chip kategori (F-03)
    final tampil = daftarPaket.where((paket) {
      return paket['tutup'] > jamSekarang &&
          (paket['sisaPorsi'] as int) > 0 &&
          // gerai yg lagi ditutup mitra ga ditampilin (F-51)
          paket['geraiTutup'] != true &&
          (kategoriDipilih == 'Semua' || paket['kategori'] == kategoriDipilih);
    }).toList();

    final semuaMitra = _kelompokkanMitra(tampil)
      ..sort((a, b) => a.tutup.compareTo(b.tutup));
    // F-53: tutup kurang dari 1 jam lagi masuk Flash sale, ga diulang di bawah
    final flashSale = [
      for (final mitra in semuaMitra)
        if (mitra.tutup - jamSekarang < 60) mitra,
    ];
    final sekitar = [
      for (final mitra in semuaMitra)
        if (mitra.tutup - jamSekarang >= 60) mitra,
    ];

    var totalPorsi = 0;
    for (final paket in tampil) {
      totalPorsi += paket['sisaPorsi'] as int;
    }

    return SafeArea(
      child: ListView(
        // bawahnya dikasih jarak gede biar item terakhir ga ketutup navigasi + bar keranjang
        padding: const EdgeInsets.only(
          bottom: NavigasiMelayang.ruangBawahKeranjang,
        ),
        children: [
          // bilah atas: area ambil + favorit
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 8, 0),
            child: Row(
              children: [
                InkWell(
                  onTap: () => _segeraHadir('Pilih area'),
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.place_outlined, size: 20, color: Warna.teks),
                        SizedBox(width: 6),
                        Text(
                          'Samarinda Ulu',
                          style: TextStyle(
                            fontSize: 16,
                            height: 22 / 16,
                            fontWeight: FontWeight.w700,
                            color: Warna.teks,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: Warna.teks,
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Mitra favorit',
                  icon: const Icon(Icons.favorite_border, color: Warna.teks),
                  onPressed: () => _segeraHadir('Mitra favorit'),
                ),
              ],
            ),
          ),

          // kolom cari + tombol saring
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Warna.garisKontrol),
                    ),
                    clipBehavior: Clip.antiAlias,
                    // diketuk langsung pindah ke halaman cari (F-04)
                    child: InkWell(
                      onTap: () => context.push(Rute.cari),
                      child: const SizedBox(
                        height: 48,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              Icon(Icons.search, size: 20, color: Warna.teks),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Cari paket, mitra, atau menu',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Warna.teksPendukung,
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
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    tooltip: 'Urutkan dan saring',
                    onPressed: () => _segeraHadir('Urutkan dan saring'),
                    icon: const Icon(Icons.tune, size: 22, color: Warna.teks),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Warna.garisKontrol),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // pembuka: "Sore ini" + ringkasan porsi dan dapur
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    jamSekarang < 18 * 60 ? 'Sore ini' : 'Malam ini',
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 36,
                      height: 40 / 36,
                      letterSpacing: -1.26,
                      fontWeight: FontWeight.w800,
                      color: Warna.teks,
                    ),
                  ),
                ),
                Text(
                  '$totalPorsi porsi · ${semuaMitra.length} dapur',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w500,
                    color: Warna.teksPendukung,
                  ),
                ),
              ],
            ),
          ),

          // chip kategori, bisa digeser ke samping (F-03)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
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

          if (semuaMitra.isEmpty) _kosong(),

          // Flash sale: kartu geser mendatar, disembunyiin kalau ga ada (F-53)
          if (flashSale.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.bolt, size: 26, color: Warna.teks),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Flash sale',
                      style: TextStyle(
                        fontSize: 26,
                        height: 32 / 26,
                        letterSpacing: -0.78,
                        fontWeight: FontWeight.w800,
                        color: Warna.teks,
                      ),
                    ),
                  ),
                  Text(
                    'Tutup kurang dari 1 jam',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Warna.mendesak,
                    ),
                  ),
                ],
              ),
            ),
            // rel geser mendatar, tingginya ngikutin kartu biar ga kepotong
            // kalau hurufnya diperbesar (NF-01). mitranya cuma sedikit, jadi Row cukup
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, mitra) in flashSale.indexed) ...[
                    if (i > 0) const SizedBox(width: 12),
                    _KartuFlashSale(
                      mitra: mitra,
                      onTap: () => widget.onBukaMitra(mitra.nama),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Mitra sekitar, urut dari jam tutup terdekat (F-01)
          if (sekitar.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      'Mitra sekitar',
                      style: TextStyle(
                        fontSize: 26,
                        height: 32 / 26,
                        letterSpacing: -0.78,
                        fontWeight: FontWeight.w800,
                        color: Warna.teks,
                      ),
                    ),
                  ),
                  Text(
                    'Tutup terdekat',
                    style: TextStyle(
                      fontSize: 13,
                      height: 18 / 13,
                      fontWeight: FontWeight.w600,
                      color: Warna.teksPendukung,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (final mitra in sekitar)
                    _BarisMitra(
                      mitra: mitra,
                      onTap: () => widget.onBukaMitra(mitra.nama),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kosong() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
      child: Column(
        children: [
          const Icon(
            Icons.restaurant_outlined,
            size: 56,
            color: Warna.teksPendukung,
          ),
          const SizedBox(height: 12),
          Text(
            kategoriDipilih == 'Semua'
                ? 'Belum ada paket sore ini'
                : 'Belum ada paket ${kategoriDipilih.toLowerCase()} sore ini',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Paket biasanya muncul menjelang sore, setelah mitra menghitung sisa jualannya.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Warna.teksPendukung),
          ),
          if (kategoriDipilih != 'Semua') ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => setState(() => kategoriDipilih = 'Semua'),
              child: const Text('Lihat semua kategori'),
            ),
          ],
        ],
      ),
    );
  }
}

/// ringkasan satu mitra dari paket-paketnya yg masih tersedia
class _Mitra {
  _Mitra({
    required this.nama,
    required this.jenis,
    required this.jarak,
    required this.foto,
    required this.jumlahPaket,
    required this.hargaTermurah,
    required this.tutup,
  });

  final String nama;
  final String jenis;
  final String jarak;
  final String foto;
  final int jumlahPaket;
  final int hargaTermurah;
  // jam tutup ambil paling akhir, lewat dari ini mitranya udah ga nawarin apa-apa
  final int tutup;
}

/// paket dikumpulin per nama mitra
List<_Mitra> _kelompokkanMitra(List<Map<String, dynamic>> paket) {
  final kelompok = <String, List<Map<String, dynamic>>>{};
  for (final p in paket) {
    kelompok.putIfAbsent(p['mitra'], () => []).add(p);
  }
  return [
    for (final MapEntry(key: nama, value: isi) in kelompok.entries)
      _Mitra(
        nama: nama,
        jenis: isi.first['jenisMitra'],
        jarak: isi.first['jarak'],
        foto: isi.first['foto'],
        jumlahPaket: isi.length,
        hargaTermurah: isi.map((p) => p['hargaDiskon'] as int).reduce(min),
        tutup: isi.map((p) => p['tutup'] as int).reduce(max),
      ),
  ];
}

/// kartu besar 288 lebar di Flash sale
class _KartuFlashSale extends StatelessWidget {
  const _KartuFlashSale({required this.mitra, required this.onTap});

  final _Mitra mitra;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 288,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 176,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(mitra.foto, fit: BoxFit.cover),
                        Positioned(
                          left: 10,
                          top: 10,
                          child: _Pil(
                            teks: '${mitra.jumlahPaket} paket',
                            latar: Colors.white,
                            warna: Warna.teks,
                          ),
                        ),
                        Positioned(
                          right: 10,
                          top: 10,
                          child: _Pil(
                            teks: 'Tutup ${jam(mitra.tutup)}',
                            latar: Warna.mendesakLembut,
                            warna: Warna.mendesak,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${mitra.jenis} · ${mitra.jarak}',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 18 / 13,
                          fontWeight: FontWeight.w500,
                          color: Warna.teksPendukung,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mitra.nama,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          height: 22 / 17,
                          letterSpacing: -0.17,
                          fontWeight: FontWeight.w700,
                          color: Warna.teks,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Wrap: harga turun baris kalau hurufnya diperbesar (NF-01)
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          const Text(
                            'mulai dari',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Warna.teksPendukung,
                            ),
                          ),
                          Text(
                            rupiah(mitra.hargaTermurah),
                            style: const TextStyle(
                              fontSize: 20,
                              height: 24 / 20,
                              letterSpacing: -0.2,
                              fontWeight: FontWeight.w800,
                              color: Warna.teks,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// baris mitra di daftar Mitra sekitar
class _BarisMitra extends StatelessWidget {
  const _BarisMitra({required this.mitra, required this.onTap});

  final _Mitra mitra;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const gayaMeta = TextStyle(
      fontSize: 13,
      height: 18 / 13,
      fontWeight: FontWeight.w600,
      color: Warna.teksPendukung,
    );

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Warna.garis)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                mitra.foto,
                width: 76,
                height: 76,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mitra.nama,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 22 / 15,
                      fontWeight: FontWeight.w600,
                      color: Warna.teks,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${mitra.jenis} · ${mitra.jarak} · ${mitra.jumlahPaket} paket',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      letterSpacing: 0.1,
                      fontWeight: FontWeight.w500,
                      color: Warna.teksPendukung,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Wrap: jam tutup sama harga turun baris kalau ga muat (NF-01)
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 16,
                            color: Warna.teksPendukung,
                          ),
                          const SizedBox(width: 6),
                          Text('Tutup ${jam(mitra.tutup)}', style: gayaMeta),
                        ],
                      ),
                      Text(
                        'mulai ${rupiah(mitra.hargaTermurah)}',
                        style: gayaMeta.copyWith(color: Warna.teks),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pil extends StatelessWidget {
  const _Pil({required this.teks, required this.latar, required this.warna});

  final String teks;
  final Color latar;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        teks,
        style: TextStyle(
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w700,
          color: warna,
        ),
      ),
    );
  }
}
