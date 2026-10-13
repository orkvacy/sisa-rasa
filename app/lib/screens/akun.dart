import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/theme/teks.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';

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

    // SafeArea: biar isi ga ketutup status bar hp
    return SafeArea(
      // ListView: isi halaman akun bisa di scroll
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // judul halaman
          const Text(
            'Akun',
            style: TextStyle(fontSize: Teks.judul, fontWeight: FontWeight.w800),
          ),
          // jarak
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
                // inisial nama di avatar
                child: Text(
                  'RA',
                  style: TextStyle(
                    fontSize: Teks.nama,
                    fontWeight: FontWeight.w800,
                    color: Warna.hijau,
                  ),
                ),
              ),
              // nama user
              title: const Text(
                'Rani Amelia',
                style: TextStyle(
                  fontSize: Teks.nama,
                  fontWeight: FontWeight.w800,
                ),
              ),
              // Column: email sama label peran disusun ke bawah
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // email user
                  const Text('rani.amelia@gmail.com'),
                  // jarak
                  const SizedBox(height: 4),
                  // Container: label kecil peran akun
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Warna.softGreen,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    // tulisan peran
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
              // panah ke kanan
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          // jarak
          const SizedBox(height: 12),

          // kartu dampak, dihitung dari pesanan yg udah dibuat
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Warna.momen,
              borderRadius: BorderRadius.circular(20),
            ),
            // Column: isi kotak dampak disusun ke bawah
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row: icon daun + judul kotak dampak
                const Row(
                  children: [
                    // icon daun
                    Icon(Icons.eco_outlined, size: 18, color: Colors.white),
                    // jarak
                    SizedBox(width: 8),
                    // judul kotak dampak
                    Text(
                      'Dampakmu hari ini',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                // jarak
                const SizedBox(height: 12),
                // Row: porsi sama hemat sebelahan
                Row(
                  children: [
                    // Expanded: bagi lebar rata, kiri porsi
                    Expanded(
                      // angka porsi + keterangannya
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // jumlah porsi
                          Text(
                            '$porsi',
                            style: const TextStyle(
                              fontSize: Teks.subjudul,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          // keterangan porsi
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
                    // Expanded: kanan buat total hemat
                    Expanded(
                      // angka hemat + keterangannya
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // total hemat
                          Text(
                            rupiah(hemat),
                            style: const TextStyle(
                              fontSize: Teks.subjudul,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          // keterangan hemat
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
          // jarak
          const SizedBox(height: 20),

          // Padding: jarak judul bagian
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
            // judul bagian akun
            child: Text(
              'Akun',
              style: TextStyle(
                fontSize: Teks.keterangan,
                fontWeight: FontWeight.w700,
                color: Warna.teksPendukung,
              ),
            ),
          ),
          // Material: latar putih buat menu akun
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            // Column: daftar menu akun
            child: const Column(
              children: [
                // menu profil
                _BarisMenu(ikon: Icons.person_outline, judul: 'Profil'),
                // menu email
                _BarisMenu(
                  ikon: Icons.mail_outline,
                  judul: 'Email',
                  nilai: 'Terverifikasi',
                ),
                // menu kata sandi
                _BarisMenu(ikon: Icons.lock_outline, judul: 'Kata sandi'),
              ],
            ),
          ),
          // jarak
          const SizedBox(height: 16),
          // jarak judul bagian
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
            // judul bagian preferensi
            child: Text(
              'Preferensi',
              style: TextStyle(
                fontSize: Teks.keterangan,
                fontWeight: FontWeight.w700,
                color: Warna.teksPendukung,
              ),
            ),
          ),
          // latar putih buat menu preferensi
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            // daftar menu preferensi
            child: const Column(
              children: [
                // menu tampilan
                _BarisMenu(
                  ikon: Icons.dark_mode_outlined,
                  judul: 'Tampilan',
                  nilai: 'Ikuti sistem',
                ),
                // menu mitra favorit
                _BarisMenu(
                  ikon: Icons.favorite_border,
                  judul: 'Mitra favorit',
                  nilai: '3',
                ),
              ],
            ),
          ),
          // jarak
          const SizedBox(height: 16),
          // jarak judul bagian
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
            // judul bagian lainnya
            child: Text(
              'Lainnya',
              style: TextStyle(
                fontSize: Teks.keterangan,
                fontWeight: FontWeight.w700,
                color: Warna.teksPendukung,
              ),
            ),
          ),
          // latar putih buat menu lainnya
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            // daftar menu lainnya
            child: const Column(
              children: [
                // menu bantuan
                _BarisMenu(ikon: Icons.help_outline, judul: 'Bantuan'),
                // menu ketentuan
                _BarisMenu(
                  ikon: Icons.description_outlined,
                  judul: 'Ketentuan & privasi',
                ),
                // menu keluar
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
      // SnackBar: notif kecil di bawah, menu nya belum ada
      SnackBar(content: Text('$menu belum tersedia di versi ini')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ListTile: satu baris menu, icon kiri + judul + panah kanan
    return ListTile(
      // icon menu
      leading: Icon(ikon, color: Warna.teks),
      // nama menu
      title: Text(judul),
      // Row: nilai + panah di kanan
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (nilai != null)
            // nilai pilihan nya
            Text(nilai!, style: const TextStyle(color: Warna.teksPendukung)),
          // panah kanan
          const Icon(Icons.chevron_right, color: Warna.teksPendukung),
        ],
      ),
      onTap: () => segeraHadir(context, judul),
    );
  }
}
