import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/presentation/cubit/lokasi_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/paket_cubit.dart';
import 'package:sisa_rasa/presentation/router.dart';
import 'package:sisa_rasa/core/theme/warna.dart';
import 'package:sisa_rasa/core/utils/format.dart';
import 'package:sisa_rasa/presentation/widgets/navigasi_bawah.dart';
import 'package:sisa_rasa/presentation/widgets/tombol_keranjang.dart';
import 'package:sisa_rasa/presentation/widgets/gambar_paket.dart';
import 'package:sisa_rasa/presentation/widgets/kerangka.dart';
import 'package:sisa_rasa/presentation/widgets/animasi.dart';

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
    'Hidangan utama',
    'Pastry & roti',
    'Buffet hotel',
    'Dessert',
    'Minuman',
  ];
  String kategoriDipilih = 'Semua';
  String urutanDipilih = 'Jam tutup terdekat';
  String hargaDipilih = 'Semua harga';
  // cuma paket yg jam ambilnya udah mulai, bisa langsung dijemput
  bool bisaSekarang = false;

  static const _urutan = [
    'Jam tutup terdekat',
    'Harga termurah',
    'Diskon terbesar',
    'Terdekat',
  ];

  /// rentang harga diskon per paket: (label, batas bawah, batas atas)
  static const _rentangHarga = [
    ('Semua harga', 0, 1 << 31),
    ('≤ Rp25rb', 0, 25000),
    ('Rp25–50rb', 25001, 50000),
    ('> Rp50rb', 50001, 1 << 31),
  ];

  bool get _adaSaringan =>
      kategoriDipilih != 'Semua' ||
      hargaDipilih != 'Semua harga' ||
      bisaSekarang;

  void _urutkanDanSaring(BuildContext context) {
    var tempUrutan = urutanDipilih;
    var tempHarga = hargaDipilih;
    var tempSekarang = bisaSekarang;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Warna.kartu,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Urutkan & Saring',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Warna.teks,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Urutkan berdasarkan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Warna.teks,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final opsi in _urutan)
                      ChoiceChip(
                        label: Text(opsi),
                        selected: tempUrutan == opsi,
                        onSelected: (val) {
                          if (val) setModalState(() => tempUrutan = opsi);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Saring paket',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Warna.teks,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (label, _, _) in _rentangHarga)
                      ChoiceChip(
                        label: Text(label),
                        selected: tempHarga == label,
                        onSelected: (val) {
                          if (val) setModalState(() => tempHarga = label);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bisa diambil sekarang'),
                  subtitle: const Text('Jam ambilnya sudah mulai'),
                  value: tempSekarang,
                  onChanged: (val) => setModalState(() => tempSekarang = val),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      urutanDipilih = tempUrutan;
                      // urut terdekat butuh lokasi: minta sekalian
                      final lokasi = this.context.read<LokasiCubit>();
                      if (tempUrutan == 'Terdekat' && !lokasi.aktif) {
                        lokasi.aktifkan();
                      }
                      hargaDipilih = tempHarga;
                      bisaSekarang = tempSekarang;
                    });
                    Navigator.pop(sheetContext);
                  },
                  child: const Text('Terapkan'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    // context.watch: kalau stok paket berubah, beranda ikut digambar ulang (F-28)
    final paketCubit = context.watch<PaketCubit>();
    final daftarPaket = paketCubit.state;

    // paket yg masih bisa dipesan: belum lewat jam tutup, masih ada porsinya (F-25),
    // terus disaring sesuai chip kategori (F-03), rentang harga, dan jam ambil
    final (_, hargaMin, hargaMaks) = _rentangHarga.firstWhere(
      (r) => r.$1 == hargaDipilih,
    );
    final tampil = daftarPaket.where((paket) {
      final cocokKategori =
          kategoriDipilih == 'Semua' || paket['kategori'] == kategoriDipilih;
      final harga = paket['hargaDiskon'] as int;
      final cocokHarga = harga >= hargaMin && harga <= hargaMaks;
      final cocokSekarang =
          !bisaSekarang || (paket['mulai'] as int) <= jamSekarang;
      return PaketCubit.tampilUntukPembeli(paket) &&
          (paket['sisaPorsi'] as int) > 0 &&
          cocokKategori &&
          cocokHarga &&
          cocokSekarang;
    }).toList();

    final lokasi = context.watch<LokasiCubit>();
    final semuaMitra = _kelompokkanMitra(tampil, lokasi);
    if (urutanDipilih == 'Terdekat' && lokasi.aktif) {
      // gerai yang belum punya titik ditaruh paling bawah
      semuaMitra.sort(
        (a, b) => (a.km ?? double.infinity).compareTo(b.km ?? double.infinity),
      );
    } else if (urutanDipilih == 'Harga termurah') {
      semuaMitra.sort((a, b) => a.hargaTermurah.compareTo(b.hargaTermurah));
    } else if (urutanDipilih == 'Diskon terbesar') {
      semuaMitra.sort((a, b) => b.diskonTerbesar.compareTo(a.diskonTerbesar));
    } else {
      semuaMitra.sort((a, b) => a.tutup.compareTo(b.tutup));
    }
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

    // tarik ke bawah = muat ulang paket
    return SafeArea(
      child: RefreshIndicator(
        color: Warna.hijau,
        onRefresh: paketCubit.muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          // bawahnya dikasih jarak biar item terakhir ga ketutup navigasi bawah
          padding: const EdgeInsets.only(bottom: NavigasiBawah.ruangBawah),
          children: [
            // bilah atas: area ambil + favorit
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 0),
              child: Row(
                children: [
                  // Flexible: teks lokasi kepotong rapi di layar sempit / huruf besar
                  const Flexible(child: _TombolLokasi()),
                  const Spacer(),
                  const TombolKeranjang(),
                  IconButton(
                    tooltip: 'Mitra favorit',
                    icon: Icon(Icons.favorite_border, color: Warna.teks),
                    onPressed: () => context.push(Rute.favorit),
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
                    // abu muda tanpa garis, kayak kolom cari Gojek
                    child: Material(
                      color: Warna.kraft,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      // diketuk langsung pindah ke halaman cari (F-04)
                      child: InkWell(
                        onTap: () => context.push(Rute.cari),
                        child: SizedBox(
                          height: 42,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.search,
                                  size: 20,
                                  color: Warna.teksPendukung,
                                ),
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
                    width: 42,
                    height: 42,
                    child: IconButton(
                      tooltip: 'Urutkan dan saring',
                      onPressed: () => _urutkanDanSaring(context),
                      icon: Icon(
                        Icons.tune,
                        size: 20,
                        // ada saringan aktif: ikonnya hijau
                        color: _adaSaringan || urutanDipilih != _urutan.first
                            ? Warna.hijau
                            : Warna.teks,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Warna.kraft,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
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
                      style: TextStyle(
                        fontSize: 24,
                        height: 40 / 36,
                        letterSpacing: -1.26,
                        fontWeight: FontWeight.w800,
                        color: Warna.teks,
                      ),
                    ),
                  ),
                  Text(
                    '$totalPorsi porsi · ${semuaMitra.length} dapur',
                    style: TextStyle(
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

            // ganti saringan: daftar lama memudar, yg baru masuk pelan
            GantiHalus(
              kunci:
                  '$kategoriDipilih|$hargaDipilih|$bisaSekarang|$urutanDipilih',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // jaringan lambat: kerangka dulu. gagal: tombol coba lagi
                  if (paketCubit.memuat)
                    const _KerangkaBeranda()
                  else if (paketCubit.gagalMuat != null)
                    GagalMuat(
                      judul: 'Paket belum bisa dimuat',
                      pesan: paketCubit.gagalMuat!,
                      onCobaLagi: paketCubit.muat,
                    )
                  else if (semuaMitra.isEmpty)
                    _kosong(),

                  // Flash sale: kartu geser mendatar, disembunyiin kalau ga ada (F-53)
                  if (flashSale.isNotEmpty) ...[
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Row(
                        children: [
                          Icon(Icons.bolt, size: 26, color: Warna.teks),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Flash sale',
                              style: TextStyle(
                                fontSize: 20,
                                height: 32 / 26,
                                letterSpacing: -0.78,
                                fontWeight: FontWeight.w800,
                                color: Warna.teks,
                              ),
                            ),
                          ),
                          // keterangan ngalah duluan kalau layarnya sempit
                          Text(
                            'Tutup < 1 jam',
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
                            MunculBertahap(
                              urutan: i,
                              child: TekanMengecil(
                                child: _KartuFlashSale(
                                  mitra: mitra,
                                  onTap: () => widget.onBukaMitra(mitra.nama),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // Mitra sekitar, urut dari jam tutup terdekat (F-01)
                  if (sekitar.isNotEmpty) ...[
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              'Mitra sekitar',
                              style: TextStyle(
                                fontSize: 20,
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
                          for (final (i, mitra) in sekitar.indexed)
                            MunculBertahap(
                              urutan: i,
                              child: TekanMengecil(
                                child: _BarisMitra(
                                  mitra: mitra,
                                  onTap: () => widget.onBukaMitra(mitra.nama),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kosong() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
      child: Column(
        children: [
          Icon(Icons.restaurant_outlined, size: 56, color: Warna.teksPendukung),
          const SizedBox(height: 12),
          Text(
            kategoriDipilih == 'Semua'
                ? 'Belum ada paket sore ini'
                : 'Belum ada paket ${kategoriDipilih.toLowerCase()} sore ini',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Paket biasanya muncul menjelang sore, setelah mitra menghitung sisa jualannya.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Warna.teksPendukung),
          ),
          if (_adaSaringan) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => setState(() {
                kategoriDipilih = 'Semua';
                hargaDipilih = 'Semua harga';
                bisaSekarang = false;
              }),
              child: const Text('Hapus semua saringan'),
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
    required this.km,
    required this.foto,
    required this.jumlahPaket,
    required this.hargaTermurah,
    required this.diskonTerbesar,
    required this.tutup,
  });

  final String nama;
  final String jenis;
  final String jarak;
  // km dari lokasi pembeli, null kalau lokasi belum aktif / gerai belum punya titik
  final double? km;
  final String foto;
  final int jumlahPaket;
  final int hargaTermurah;
  // persen diskon paling besar di antara paketnya
  final int diskonTerbesar;
  // jam tutup ambil paling akhir, lewat dari ini mitranya udah ga nawarin apa-apa
  final int tutup;
}

/// paket dikumpulin per nama mitra
List<_Mitra> _kelompokkanMitra(
  List<Map<String, dynamic>> paket,
  LokasiCubit lokasi,
) {
  final kelompok = <String, List<Map<String, dynamic>>>{};
  for (final p in paket) {
    kelompok.putIfAbsent(p['mitra'], () => []).add(p);
  }
  return [
    for (final MapEntry(key: nama, value: isi) in kelompok.entries)
      _Mitra(
        nama: nama,
        jenis: isi.first['jenisMitra'],
        jarak: lokasi.teks(isi.first),
        km: lokasi.km(isi.first),
        foto: isi.first['foto'],
        jumlahPaket: isi.length,
        hargaTermurah: isi.map((p) => p['hargaDiskon'] as int).reduce(min),
        diskonTerbesar: isi
            .map((p) => persenDiskon(p['hargaAsli'], p['hargaDiskon']))
            .reduce(max),
        tutup: isi.map((p) => p['tutup'] as int).reduce(max),
      ),
  ];
}

/// kartu 168 lebar di Flash sale
class _KartuFlashSale extends StatelessWidget {
  const _KartuFlashSale({required this.mitra, required this.onTap});

  final _Mitra mitra;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: Material(
        color: Warna.kartu,
        // latar putih: cukup garis tipis + bayangan halus, bukan bayangan tebal
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Warna.garis),
        ),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 96,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        GambarPaket(mitra.foto, fit: BoxFit.cover),
                        // cuma jam tutup, jumlah paket keliatan di halaman mitra
                        Positioned(
                          left: 8,
                          top: 8,
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
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${mitra.jenis} · ${mitra.jarak}',
                        style: TextStyle(
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
                        style: TextStyle(
                          fontSize: 14,
                          height: 22 / 17,
                          letterSpacing: -0.17,
                          fontWeight: FontWeight.w700,
                          color: Warna.teks,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Wrap: harga turun baris kalau hurufnya diperbesar (NF-01)
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          Text(
                            'mulai dari',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Warna.teksPendukung,
                            ),
                          ),
                          Text(
                            rupiah(mitra.hargaTermurah),
                            style: TextStyle(
                              fontSize: 14,
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
    final gayaMeta = TextStyle(
      fontSize: 13,
      height: 18 / 13,
      fontWeight: FontWeight.w600,
      color: Warna.teksPendukung,
    );

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Warna.garis)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: GambarPaket(
                mitra.foto,
                width: 64,
                height: 64,
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
                    style: TextStyle(
                      fontSize: 15,
                      height: 22 / 15,
                      fontWeight: FontWeight.w600,
                      color: Warna.teks,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${mitra.jenis} · ${mitra.jarak} · ${mitra.jumlahPaket} paket',
                    style: TextStyle(
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
                          Icon(
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

/// kerangka beranda selama paket pertama dimuat: 2 kartu flash sale + 4 baris mitra
class _KerangkaBeranda extends StatelessWidget {
  const _KerangkaBeranda();

  @override
  Widget build(BuildContext context) {
    return KilauKerangka(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Kerangka(lebar: 120, tinggi: 20),
            const SizedBox(height: 12),
            // dua kartu bagi rata lebar layar, biar muat di HP sempit
            const Row(
              children: [
                Expanded(child: _KerangkaKartu()),
                SizedBox(width: 12),
                Expanded(child: _KerangkaKartu()),
              ],
            ),
            const SizedBox(height: 24),
            const Kerangka(lebar: 140, tinggi: 20),
            for (var i = 0; i < 4; i++)
              const Padding(
                padding: EdgeInsets.only(top: 14),
                child: Row(
                  children: [
                    Kerangka(lebar: 64, tinggi: 64, radius: 10),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Kerangka(lebar: 140, tinggi: 14),
                          SizedBox(height: 8),
                          Kerangka(lebar: 100, tinggi: 12),
                          SizedBox(height: 8),
                          Kerangka(lebar: 170, tinggi: 12),
                        ],
                      ),
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

class _KerangkaKartu extends StatelessWidget {
  const _KerangkaKartu();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Kerangka(tinggi: 96, radius: 12),
        SizedBox(height: 10),
        Kerangka(lebar: 90, tinggi: 12),
        SizedBox(height: 8),
        Kerangka(lebar: 120, tinggi: 14),
      ],
    );
  }
}

/// bilah lokasi di kiri atas beranda (F-66). lokasi aktif = jarak ke gerai
/// dihitung dari GPS, kalau belum diminta / ditolak bisa diaktifin dari sini
class _TombolLokasi extends StatelessWidget {
  const _TombolLokasi();

  Future<void> _ketuk(BuildContext context) async {
    final lokasi = context.read<LokasiCubit>();
    if (lokasi.state['keSetelan'] == true) {
      final buka = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Izinkan lokasi'),
          content: Text(
            '${lokasi.state['pesan']}\n\nLokasimu cuma dipakai di HP untuk menghitung jarak, tidak dikirim ke server.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Nanti'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Buka setelan'),
            ),
          ],
        ),
      );
      if (buka == true) await lokasi.bukaSetelan();
      return;
    }
    await lokasi.aktifkan();
    if (!context.mounted) return;
    final pesan = context.read<LokasiCubit>().state['pesan'];
    if (pesan != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(pesan)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = context.watch<LokasiCubit>().state['status'];
    final (ikon, teks) = switch (status) {
      'aktif' => (Icons.my_location, 'Di sekitarmu'),
      'mencari' => (Icons.location_searching, 'Mencari lokasi…'),
      _ => (Icons.location_off_outlined, 'Aktifkan lokasi'),
    };
    final aktif = status == 'aktif';
    return InkWell(
      key: const Key('tombol-lokasi'),
      onTap: status == 'mencari' ? null : () => _ketuk(context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 20, color: aktif ? Warna.hijau : Warna.teks),
            const SizedBox(width: 6),
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  teks,
                  key: ValueKey(teks),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    height: 22 / 16,
                    fontWeight: FontWeight.w700,
                    color: Warna.teks,
                  ),
                ),
              ),
            ),
            if (!aktif) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: Warna.teks),
            ],
          ],
        ),
      ),
    );
  }
}
