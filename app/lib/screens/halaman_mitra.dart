import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/cubit/keranjang_cubit.dart';
import 'package:sisa_rasa/cubit/paket_cubit.dart';
import 'package:sisa_rasa/router.dart';
import 'package:sisa_rasa/utils/aksi_mitra.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';
import 'package:sisa_rasa/widgets/bar_keranjang.dart';
import 'package:sisa_rasa/widgets/konfirmasi_ganti_mitra.dart';

/// halaman satu mitra (figma v3: pembeli/halaman mitra, F-54).
/// isinya info gerai sama semua paket aktifnya, jadi pembeli bisa ambil
/// lebih dari satu paket dari mitra yg sama
class HalamanMitra extends StatelessWidget {
  const HalamanMitra({required this.nama, super.key});

  final String nama;

  Future<void> _tambah(BuildContext context, Map<String, dynamic> paket) async {
    final keranjangCubit = context.read<KeranjangCubit>();
    // keranjang isi mitra lain: tanya dulu (F-07)
    final gantiMitra = await cekGantiMitra(context, paket);
    if (gantiMitra == null) return;
    keranjangCubit.tambah(paket, 1, gantiMitra: gantiMitra);
  }

  @override
  Widget build(BuildContext context) {
    final semua = context.watch<PaketCubit>().state;
    final keranjang = context.watch<KeranjangCubit>().state;

    // paket mitra ini yg belum lewat jam tutup (F-25), yg habis tetap tampil dengan tanda Habis
    final daftar = [
      for (final paket in semua)
        if (paket['mitra'] == nama && paket['tutup'] > jamSekarang) paket,
    ]..sort((a, b) => a['tutup'].compareTo(b['tutup']));

    // mitranya udah ga punya paket aktif (misal kebuka dari link lama)
    if (daftar.isEmpty) {
      return Scaffold(
        backgroundColor: Warna.latar,
        appBar: AppBar(backgroundColor: Warna.latar, title: Text(nama)),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Paket dari mitra ini sudah habis untuk hari ini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Warna.teksPendukung),
            ),
          ),
        ),
      );
    }

    final pertama = daftar.first;
    final tutup = daftar.map((p) => p['tutup'] as int).reduce(max);
    // label halal muncul kalau mitranya ngisi (F-02), higiene selalu, soalnya
    // mitra yg belum diverifikasi admin ga bisa nawarin paket (F-37)
    final halal = daftar.any((p) => p['halal'] == true);

    // ringkasan keranjang buat bar melayang di bawah
    var porsiKeranjang = 0;
    var totalKeranjang = 0;
    for (final id in keranjang.keys) {
      final paket = context.read<PaketCubit>().cari(id);
      porsiKeranjang += keranjang[id]!;
      totalKeranjang += keranjang[id]! * (paket['hargaDiskon'] as int);
    }

    return Scaffold(
      backgroundColor: Warna.latar,
      // Stack: daftar di belakang, bar keranjang ngambang di depan
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.only(bottom: porsiKeranjang > 0 ? 96 : 24),
            children: [
              _Sampul(foto: pertama['foto'], onKembali: () => context.pop()),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nama,
                      style: const TextStyle(
                        fontSize: 26,
                        height: 32 / 26,
                        letterSpacing: -0.78,
                        fontWeight: FontWeight.w800,
                        color: Warna.teks,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${pertama['jenisMitra']} · ${pertama['alamat']} · ${pertama['jarak']}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Warna.teksPendukung,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (halal)
                          const _Lencana(
                            ikon: Icons.check,
                            teks: 'Halal bersertifikat',
                          ),
                        const _Lencana(
                          ikon: Icons.verified_user_outlined,
                          teks: 'Higiene terverifikasi',
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _KartuTutup(
                      tutup: tutup,
                      onPetunjukArah: () =>
                          bukaPeta(context, pertama['alamat']),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Paket hari ini',
                        style: TextStyle(
                          fontSize: 18,
                          letterSpacing: -0.27,
                          fontWeight: FontWeight.w800,
                          color: Warna.teks,
                        ),
                      ),
                    ),
                    Text(
                      '${daftar.length} paket',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
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
                    for (final paket in daftar)
                      _BarisPaketMitra(
                        paket: paket,
                        jumlah: keranjang[paket['id']] ?? 0,
                        onTap: () => context.push(Rute.paket(paket['id'])),
                        onTambah: () => _tambah(context, paket),
                        onUbah: (baru) {
                          final cubit = context.read<KeranjangCubit>();
                          if (baru == 0) {
                            cubit.hapus(paket['id']);
                          } else {
                            cubit.ubahJumlah(paket['id'], baru);
                          }
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
          // bar keranjang yg sama kayak di beranda, muncul kalau keranjang ada isinya
          if (porsiKeranjang > 0)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12 + MediaQuery.of(context).padding.bottom,
              child: BarKeranjang(
                foto: context.read<PaketCubit>().cari(
                  keranjang.keys.first,
                )['foto'],
                jumlahPorsi: porsiKeranjang,
                total: totalKeranjang,
                onTap: () => context.push(Rute.keranjang),
              ),
            ),
        ],
      ),
    );
  }
}

/// foto sampul 188 tinggi, tombol kembali sama favorit numpuk di atasnya
class _Sampul extends StatelessWidget {
  const _Sampul({required this.foto, required this.onKembali});

  final String foto;
  final VoidCallback onKembali;

  @override
  Widget build(BuildContext context) {
    final atas = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: 188 + atas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(foto, fit: BoxFit.cover),
          Positioned(
            top: atas + 12,
            left: 16,
            child: _TombolBulat(
              tooltip: 'Kembali',
              ikon: Icons.arrow_back,
              onPressed: onKembali,
            ),
          ),
          Positioned(
            top: atas + 12,
            right: 16,
            child: _TombolBulat(
              tooltip: 'Simpan mitra',
              ikon: Icons.favorite_border,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mitra favorit belum tersedia di versi ini'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TombolBulat extends StatelessWidget {
  const _TombolBulat({
    required this.tooltip,
    required this.ikon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData ikon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.white,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(ikon, size: 22, color: Warna.teks),
      ),
    );
  }
}

/// pil hijau muda: halal / higiene
class _Lencana extends StatelessWidget {
  const _Lencana({required this.ikon, required this.teks});

  final IconData ikon;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Warna.softGreen,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 14, color: Warna.hijau),
          const SizedBox(width: 4),
          Text(
            teks,
            style: const TextStyle(
              fontSize: 12,
              height: 16 / 12,
              letterSpacing: 0.1,
              fontWeight: FontWeight.w500,
              color: Warna.hijau,
            ),
          ),
        ],
      ),
    );
  }
}

/// kartu putih: jam tutup ambil + sisa waktu, sama tombol petunjuk arah
class _KartuTutup extends StatelessWidget {
  const _KartuTutup({required this.tutup, required this.onPetunjukArah});

  final int tutup;
  final VoidCallback onPetunjukArah;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Warna.garis),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 22, color: Warna.teks),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tutup ${jam(tutup)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Warna.mendesak,
                  ),
                ),
                Text(
                  '${sisaWaktu(tutup)} lagi',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Warna.teksPendukung,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onPetunjukArah,
            icon: const Icon(Icons.navigation_outlined, size: 18),
            label: const Text('Petunjuk arah'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Warna.teks,
              side: const BorderSide(color: Warna.garisKontrol),
              // tema bikin tombol outlined selebar layar, di sini seukuran isinya
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// satu paket: foto (pil sisa kalau tinggal dikit), nama, deskripsi, harga,
/// lalu tombol tambah / pengatur porsi / pil Habis (F-24, F-54)
class _BarisPaketMitra extends StatelessWidget {
  const _BarisPaketMitra({
    required this.paket,
    required this.jumlah,
    required this.onTap,
    required this.onTambah,
    required this.onUbah,
  });

  final Map<String, dynamic> paket;
  final int jumlah;
  final VoidCallback onTap;
  final VoidCallback onTambah;
  final ValueChanged<int> onUbah;

  @override
  Widget build(BuildContext context) {
    final int sisa = paket['sisaPorsi'];
    final habis = sisa == 0;
    final warnaTeks = habis ? Warna.teksPendukung : Warna.teks;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Warna.garis)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Opacity: foto paket yg habis dipudarin
            Opacity(
              opacity: habis ? 0.5 : 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(paket['foto'], fit: BoxFit.cover),
                      // pil sisa cuma muncul kalau porsinya tinggal dikit
                      if (!habis && sisa <= 3)
                        Positioned(
                          left: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Warna.mendesakLembut,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Sisa $sisa',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Warna.mendesak,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paket['nama'],
                    style: TextStyle(
                      fontSize: 15,
                      height: 20 / 15,
                      fontWeight: FontWeight.w600,
                      color: warnaTeks,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    paket['deskripsi'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      color: Warna.teksPendukung,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rupiah(paket['hargaDiskon']),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: warnaTeks,
                              ),
                            ),
                            Text(
                              rupiah(paket['hargaAsli']),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Warna.teksPendukung,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (habis)
                        const _PilHabis()
                      else if (jumlah == 0)
                        _TombolHijau(
                          tooltip: 'Tambah ${paket['nama']}',
                          ikon: Icons.add,
                          ukuran: 40,
                          latar: Warna.softGreen,
                          onPressed: onTambah,
                        )
                      else
                        _AturPorsi(jumlah: jumlah, sisa: sisa, onUbah: onUbah),
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

/// tombol ikon bulat. area sentuhnya tetap 48 lewat materialTapTargetSize di tema
class _TombolHijau extends StatelessWidget {
  const _TombolHijau({
    required this.tooltip,
    required this.ikon,
    required this.ukuran,
    required this.latar,
    required this.onPressed,
  });

  final String tooltip;
  final IconData ikon;
  final double ukuran;
  final Color latar;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(ikon, size: ukuran >= 40 ? 22 : 18),
      style: IconButton.styleFrom(
        backgroundColor: latar,
        foregroundColor: Warna.teks,
        disabledBackgroundColor: latar,
        fixedSize: Size(ukuran, ukuran),
        minimumSize: Size(ukuran, ukuran),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

/// pengatur porsi: pil hijau muda isi tombol - jumlah +.
/// minus di jumlah 1 berarti paketnya dikeluarin dari keranjang
class _AturPorsi extends StatelessWidget {
  const _AturPorsi({
    required this.jumlah,
    required this.sisa,
    required this.onUbah,
  });

  final int jumlah;
  final int sisa;
  final ValueChanged<int> onUbah;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Warna.softGreen,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TombolHijau(
            tooltip: jumlah == 1 ? 'Hapus dari keranjang' : 'Kurangi porsi',
            ikon: Icons.remove,
            ukuran: 32,
            latar: Colors.white,
            onPressed: () => onUbah(jumlah - 1),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$jumlah',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Warna.teks,
              ),
            ),
          ),
          _TombolHijau(
            tooltip: 'Tambah porsi',
            ikon: Icons.add,
            ukuran: 32,
            latar: Colors.white,
            onPressed: jumlah < sisa ? () => onUbah(jumlah + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _PilHabis extends StatelessWidget {
  const _PilHabis();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Warna.garis,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Habis',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Warna.teksPendukung,
        ),
      ),
    );
  }
}
