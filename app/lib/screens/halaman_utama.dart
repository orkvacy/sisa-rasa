import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/cubit/keranjang_cubit.dart';
import 'package:sisa_rasa/cubit/paket_cubit.dart';
import 'package:sisa_rasa/screens/akun.dart';
import 'package:sisa_rasa/screens/beranda.dart';
import 'package:sisa_rasa/screens/detail_paket.dart';
import 'package:sisa_rasa/screens/keranjang.dart';
import 'package:sisa_rasa/screens/kode_ambil.dart';
import 'package:sisa_rasa/screens/pesanan.dart';
import 'package:sisa_rasa/widgets/bar_keranjang.dart';
import 'package:sisa_rasa/widgets/navigasi_melayang.dart';

/// halaman induk, yg punya navigation bar (beranda, pesanan, akun)
/// data paket, keranjang, pesanan udah pindah ke cubit/bloc (lihat main.dart)
/// di sini tinggal ngurus tab yg aktif sama pindah halaman
class HalamanUtama extends StatefulWidget {
  const HalamanUtama({super.key});

  @override
  State<HalamanUtama> createState() => _HalamanUtamaState();
}

class _HalamanUtamaState extends State<HalamanUtama> {
  static const _tabs = [
    TabNavigasi(
      label: 'Beranda',
      ikon: Icons.home_outlined,
      ikonAktif: Icons.home,
    ),
    TabNavigasi(
      label: 'Pesanan',
      ikon: Icons.receipt_long_outlined,
      ikonAktif: Icons.receipt_long,
    ),
    TabNavigasi(
      label: 'Akun',
      ikon: Icons.person_outline,
      ikonAktif: Icons.person,
    ),
  ];

  // 0 beranda, 1 pesanan, 2 akun
  // cuma dipake di halaman ini, jadi cukup setState, ga perlu cubit
  int tabAktif = 0;

  void bukaDetail(Map<String, dynamic> paket) {
    // Navigator.push: buka halaman detail di atas halaman ini
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DetailPaket(paket: paket)),
    );
  }

  Future<void> bukaKeranjang() async {
    // snackbar "masuk keranjang" ditutup dulu biar ga nutupin tombol pesan
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    // ditungguin, kalau balikannya true berarti pindah ke tab pesanan
    final lihatPesanan = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const Keranjang()),
    );
    if (lihatPesanan == true) setState(() => tabAktif = 1);
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold: kerangka halaman, ada body sama bottomNavigationBar
    return Scaffold(
      // extendBody: halaman tab nerusin sampe belakang navigasi melayang,
      // snackbar tetep muncul di atas navigasi karena navigasinya bottomNavigationBar
      extendBody: true,
      // IndexedStack: cuma nampilin 1 tab, tapi tab lain ga di-reset (scroll nya tetep)
      body: IndexedStack(
        index: tabAktif,
        children: [
          Beranda(onBukaPaket: bukaDetail),
          Pesanan(
            onBukaKode: (pesanan) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => KodeAmbil(pesanan: pesanan),
              ),
            ),
            onCariPaket: () => setState(() => tabAktif = 0),
          ),
          const Akun(),
        ],
      ),
      // bar keranjang sama navigasi melayang numpuk di bawah, latarnya transparan
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // BlocBuilder: cuma bagian ini yg digambar ulang tiap isi keranjang berubah
            BlocBuilder<KeranjangCubit, Map<String, int>>(
              builder: (context, keranjang) {
                // bar keranjang cuma muncul di beranda, itupun kalau keranjang ada isinya
                if (tabAktif != 0 || keranjang.isEmpty) {
                  // SizedBox: kotak ukuran tetap, .shrink() berarti ukurannya 0 jadi ga keliatan
                  return const SizedBox.shrink();
                }
                final paketCubit = context.read<PaketCubit>();
                final pertama = paketCubit.cari(keranjang.keys.first);
                var porsi = 0;
                var total = 0;
                for (final id in keranjang.keys) {
                  porsi += keranjang[id]!;
                  total +=
                      (paketCubit.cari(id)['hargaDiskon'] as int) *
                      keranjang[id]!;
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BarKeranjang(
                    foto: pertama['foto'],
                    jumlahPorsi: porsi,
                    total: total,
                    onTap: bukaKeranjang,
                  ),
                );
              },
            ),
<<<<<<< HEAD
            NavigasiMelayang(
              tabs: _tabs,
              tabAktif: tabAktif,
              onPilih: (index) => setState(() => tabAktif = index),
            ),
          ],
        ),
=======
          ),
        ],
      ),
      // NavigationBar: navigasi bawah buat pindah halaman utama
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        indicatorColor: Warna.softGreen,
        selectedIndex: tabAktif,
        onDestinationSelected: (index) => setState(() => tabAktif = index),
        destinations: const [
          // NavigationDestination: satu tombol tab di navigation bar
          NavigationDestination(
            // Icon: nampilin ikon bawaan material (Icons.xxx)
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Warna.hijau),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: Warna.hijau),
            label: 'Pesanan',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Warna.hijau),
            label: 'Akun',
          ),
        ],
>>>>>>> origin/main
      ),
    );
  }
}
