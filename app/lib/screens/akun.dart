import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/cubit/akun_cubit.dart';
import 'package:sisa_rasa/cubit/keranjang_cubit.dart';
import 'package:sisa_rasa/data/dummy_akun.dart';
import 'package:sisa_rasa/theme/teks.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';
import 'package:sisa_rasa/widgets/navigasi_melayang.dart';

/// tab akun: profil, kartu dampak, sama menu setelan
class Akun extends StatelessWidget {
  const Akun({super.key});

  @override
  Widget build(BuildContext context) {
    final akun = context.watch<AkunCubit>().state;
    final daftarPesanan = PesananBloc.milik(
      context.watch<PesananBloc>().state,
      akun['id']!,
    );
    var porsi = 0;
    var hemat = 0;
    for (final pesanan in daftarPesanan) {
      // cuma yg udah dibayar (udah punya kode ambil), yg batal / belum bayar ga dihitung
      if (pesanan['kode'] == null) continue;
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
          Row(
            children: [
              // dibuka dari dasbor mitra (bukan tab), jadi perlu tombol kembali
              if (GoRouter.of(context).canPop())
                IconButton(
                  tooltip: 'Kembali',
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                ),
              const Expanded(
                child: Text(
                  'Akun',
                  style: TextStyle(
                    fontSize: Teks.judul,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              // kDebugMode: tombol ini cuma ada pas flutter run / test,
              // di build rilis (flutter build apk) otomatis ilang
              if (kDebugMode) const _TombolGantiAkun(),
            ],
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
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: Warna.softGreen,
                child: Text(
                  inisial(akun['nama']!),
                  style: const TextStyle(
                    fontSize: Teks.nama,
                    fontWeight: FontWeight.w800,
                    color: Warna.hijau,
                  ),
                ),
              ),
              title: Text(
                akun['nama']!,
                style: const TextStyle(
                  fontSize: Teks.nama,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(akun['email']!),
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
                    child: Text(
                      namaPeran(akun['peran']!),
                      style: const TextStyle(
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

          // kartu dampak, dihitung dari pesanan yg udah dibuat.
          // khusus pembeli, dampak mitra udah ada di dasbornya
          if (akun['peran'] == 'pembeli') ...[
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
          ] else
            const SizedBox(height: 8),

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

/// tombol pindah akun cepet selama testing, gantiin logout - login
class _TombolGantiAkun extends StatelessWidget {
  const _TombolGantiAkun();

  void _pilih(BuildContext context) {
    final aktif = context.read<AkunCubit>().state['id'];
    // showModalBottomSheet: lembar dari bawah, isinya daftar akun uji
    showModalBottomSheet<void>(
      context: context,
      // useRootNavigator: dibuka di atas navigasi melayang, kalau ga bawahnya ketutup
      useRootNavigator: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: Text(
                'Ganti akun',
                style: TextStyle(
                  fontSize: Teks.subjudul,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Khusus mode uji. Keranjang dikosongkan saat pindah akun.',
                style: TextStyle(
                  fontSize: Teks.keterangan,
                  color: Warna.teksPendukung,
                ),
              ),
            ),
            for (final akun in dummyAkun)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: CircleAvatar(
                  backgroundColor: Warna.softGreen,
                  child: Text(
                    inisial(akun['nama']!),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Warna.hijau,
                    ),
                  ),
                ),
                title: Text(
                  akun['nama']!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${namaPeran(akun['peran']!)} · ${akun['email']}',
                ),
                trailing: akun['id'] == aktif
                    ? const Icon(Icons.check_circle, color: Warna.hijau)
                    : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (akun['id'] == aktif) return;
                  // diambil dulu sebelum ganti akun: kalau perannya beda,
                  // router langsung pindah ke halaman peran baru dan layar ini ketutup
                  final messenger = ScaffoldMessenger.of(context);
                  final keranjang = context.read<KeranjangCubit>();
                  final akunCubit = context.read<AkunCubit>();
                  // halaman akun yg dibuka dari dasbor mitra ditutup dulu,
                  // biar ga sempet digambar ulang pake akun peran lain
                  if (GoRouter.of(context).canPop()) context.pop();
                  keranjang.kosongkan();
                  akunCubit.ganti(akun['id']!);
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(content: Text('Masuk sebagai ${akun['nama']}')),
                    );
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _pilih(context),
      icon: const Icon(Icons.swap_horiz, size: 18),
      label: const Text('Ganti akun'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Warna.hijau,
        side: const BorderSide(color: Warna.garisKontrol),
        // tema bikin tombol outlined selebar layar, di sini cukup seukuran isinya
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
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
