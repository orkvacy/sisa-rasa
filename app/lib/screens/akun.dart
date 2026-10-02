import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/theme/teks.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';
import 'package:sisa_rasa/widgets/navigasi_melayang.dart';

/// tab akun: profil, kartu dampak, sama menu setelan
class Akun extends StatelessWidget {
  const Akun({super.key});

  @override
  Widget build(BuildContext context) {
    final daftarPesanan = context.watch<PesananBloc>().state;
    var porsi = 0;
    var hemat = 0;
    for (final pesanan in daftarPesanan) {
      porsi += pesanan['porsi'] as int;
      hemat += pesanan['hemat'] as int;
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          NavigasiMelayang.ruangBawah,
        ),
        children: [
          const Text(
            'Akun',
            style: TextStyle(fontSize: Teks.judul, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          // Material dipake buat latar kartu, soalnya kalau Container berwarna efek pencet ListTile nya ketutup
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            // ListTile: baris siap pakai, ada leading (kiri), title, subtitle, trailing (kanan)
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              onTap: () => _BarisMenu.segeraHadir(context, 'Profil'),
              // CircleAvatar: lingkaran isi inisial nama, gantiin foto profil
              leading: const CircleAvatar(
                radius: 28,
                backgroundColor: Warna.softGreen,
                child: Text(
                  'RA',
                  style: TextStyle(
                    fontSize: Teks.nama,
                    fontWeight: FontWeight.w800,
                    color: Warna.hijau,
                  ),
                ),
              ),
              title: const Text(
                'Rani Amelia',
                style: TextStyle(
                  fontSize: Teks.nama,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('rani.amelia@gmail.com'),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Warna.softGreen,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'Pembeli',
                      style: TextStyle(
                        fontSize: Teks.kecil,
                        fontWeight: FontWeight.w700,
                        color: Warna.hijau,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 12),

          // kartu dampak, dihitung dari pesanan yg udah dibuat
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Warna.momen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.eco_outlined, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Dampakmu hari ini',
                      style: TextStyle(color: Colors.white),
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
                          Text(
                            '$porsi',
                            style: const TextStyle(
                              fontSize: Teks.subjudul,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const Text(
                            'porsi terselamatkan',
                            style: TextStyle(
                              fontSize: Teks.kecil,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rupiah(hemat),
                            style: const TextStyle(
                              fontSize: Teks.subjudul,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const Text(
                            'kamu hemat',
                            style: TextStyle(
                              fontSize: Teks.kecil,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              'Akun',
              style: TextStyle(
                fontSize: Teks.keterangan,
                fontWeight: FontWeight.w700,
                color: Warna.teksPendukung,
              ),
            ),
          ),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: const Column(
              children: [
                _BarisMenu(ikon: Icons.person_outline, judul: 'Profil'),
                _BarisMenu(
                  ikon: Icons.mail_outline,
                  judul: 'Email',
                  nilai: 'Terverifikasi',
                ),
                _BarisMenu(ikon: Icons.lock_outline, judul: 'Kata sandi'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              'Preferensi',
              style: TextStyle(
                fontSize: Teks.keterangan,
                fontWeight: FontWeight.w700,
                color: Warna.teksPendukung,
              ),
            ),
          ),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: const Column(
              children: [
                _BarisMenu(
                  ikon: Icons.dark_mode_outlined,
                  judul: 'Tampilan',
                  nilai: 'Ikuti sistem',
                ),
                _BarisMenu(
                  ikon: Icons.favorite_border,
                  judul: 'Mitra favorit',
                  nilai: '3',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              'Lainnya',
              style: TextStyle(
                fontSize: Teks.keterangan,
                fontWeight: FontWeight.w700,
                color: Warna.teksPendukung,
              ),
            ),
          ),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: const Column(
              children: [
                _BarisMenu(ikon: Icons.help_outline, judul: 'Bantuan'),
                _BarisMenu(
                  ikon: Icons.description_outlined,
                  judul: 'Ketentuan & privasi',
                ),
                _BarisMenu(ikon: Icons.logout, judul: 'Keluar'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// satu baris menu, halamannya belum ada jadi cuma munculin snackbar
class _BarisMenu extends StatelessWidget {
  const _BarisMenu({required this.ikon, required this.judul, this.nilai});

  final IconData ikon;
  final String judul;
  final String? nilai;

  static void segeraHadir(BuildContext context, String menu) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$menu belum tersedia di versi ini')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(ikon, color: Warna.teks),
      title: Text(judul),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (nilai != null)
            Text(nilai!, style: const TextStyle(color: Warna.teksPendukung)),
          const Icon(Icons.chevron_right, color: Warna.teksPendukung),
        ],
      ),
      onTap: () => segeraHadir(context, judul),
    );
  }
}
