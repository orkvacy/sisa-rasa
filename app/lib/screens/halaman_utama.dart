import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sisa_rasa/data/dummy_deals.dart';
import 'package:sisa_rasa/screens/akun.dart';
import 'package:sisa_rasa/screens/beranda.dart';
import 'package:sisa_rasa/screens/detail_paket.dart';
import 'package:sisa_rasa/screens/keranjang.dart';
import 'package:sisa_rasa/screens/kode_ambil.dart';
import 'package:sisa_rasa/screens/pesanan.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';
import 'package:sisa_rasa/widgets/bar_keranjang.dart';

/// halaman induk, yg punya navigation bar (beranda, pesanan, akun)
/// data keranjang sama pesanan disimpen di sini biar semua halaman bisa pake
class HalamanUtama extends StatefulWidget {
  const HalamanUtama({super.key});

  @override
  State<HalamanUtama> createState() => _HalamanUtamaState();
}

class _HalamanUtamaState extends State<HalamanUtama> {
  // 0 beranda, 1 pesanan, 2 akun
  int tabAktif = 0;

  // isi keranjang: id paket -> jumlah porsi
  final keranjang = <String, int>{};
  final daftarPesanan = <Map<String, dynamic>>[];

  Map<String, dynamic> cariPaket(String id) {
    return dummyDeals.firstWhere((paket) => paket['id'] == id);
  }

  String? get mitraKeranjang {
    if (keranjang.isEmpty) return null;
    return cariPaket(keranjang.keys.first)['mitra'];
  }

  int get jumlahPorsi => keranjang.values.fold(0, (total, n) => total + n);

  int get totalKeranjang => keranjang.keys.fold(0, (total, id) {
    return total + (cariPaket(id)['hargaDiskon'] as int) * keranjang[id]!;
  });

  void tambahKeKeranjang(Map<String, dynamic> paket, int jumlah) {
    setState(() {
      // 1 pesanan cuma boleh dari 1 mitra, jadi yg lama dikosongin dulu
      if (mitraKeranjang != null && mitraKeranjang != paket['mitra']) {
        keranjang.clear();
      }
      final baru = (keranjang[paket['id']] ?? 0) + jumlah;
      final int sisa = paket['sisaPorsi'];
      keranjang[paket['id']] = baru.clamp(1, sisa);
    });
  }

  void ubahJumlah(String id, int jumlah) {
    setState(() => keranjang[id] = jumlah);
  }

  void kosongkanKeranjang() {
    setState(() => keranjang.clear());
  }

  Map<String, dynamic> buatPesanan() {
    // kode acak SR-xxxx, huruf O/I sama angka 0/1 dibuang biar ga ketuker pas dibaca
    const huruf = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // pake regex nanti
    final acak = Random();
    var kode = 'SR-';
    for (var i = 0; i < 4; i++) {
      kode += huruf[acak.nextInt(huruf.length)];
    }

    final pertama = cariPaket(keranjang.keys.first);
    final isi = <Map<String, dynamic>>[];
    var total = 0;
    var hargaNormal = 0;
    var porsi = 0;

    for (final id in keranjang.keys) {
      final paket = cariPaket(id);
      final jumlah = keranjang[id]!;
      isi.add({'nama': paket['nama'], 'jumlah': jumlah});
      total += (paket['hargaDiskon'] as int) * jumlah;
      hargaNormal += (paket['hargaAsli'] as int) * jumlah;
      porsi += jumlah;
      // stok berkurang sesuai yg dipesen
      paket['sisaPorsi'] -= jumlah;
    }

    final pesanan = {
      'kode': kode,
      'mitra': pertama['mitra'],
      'alamat': pertama['alamat'],
      'foto': pertama['foto'],
      'mulai': pertama['mulai'],
      'tutup': pertama['tutup'],
      'dipesan': jamSekarang,
      'isi': isi,
      'porsi': porsi,
      'total': total,
      'hemat': hargaNormal - total,
    };

    setState(() {
      daftarPesanan.insert(0, pesanan);
      keranjang.clear();
    });
    return pesanan;
  }

  void bukaDetail(Map<String, dynamic> paket) {
    // Navigator.push: buka halaman detail di atas halaman ini
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailPaket(
          paket: paket,
          mitraKeranjang: mitraKeranjang,
          onTambah: tambahKeKeranjang,
        ),
      ),
    );
  }

  Future<void> bukaKeranjang() async {
    // snackbar "masuk keranjang" ditutup dulu biar ga nutupin tombol pesan
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    // ditungguin, kalau balikannya true berarti pindah ke tab pesanan
    final lihatPesanan = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => Keranjang(
          keranjang: keranjang,
          cariPaket: cariPaket,
          onUbahJumlah: ubahJumlah,
          onKosongkan: kosongkanKeranjang,
          onPesan: buatPesanan,
        ),
      ),
    );
    if (lihatPesanan == true) setState(() => tabAktif = 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Stack: halaman tab di belakang, bar keranjang ngambang di depannya
      body: Stack(
        children: [
          // IndexedStack: cuma nampilin 1 tab, tapi tab lain ga di-reset (scroll nya tetep)
          IndexedStack(
            index: tabAktif,
            children: [
              Beranda(daftarPaket: dummyDeals, onBukaPaket: bukaDetail),
              Pesanan(
                daftarPesanan: daftarPesanan,
                onBukaKode: (pesanan) => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => KodeAmbil(pesanan: pesanan),
                  ),
                ),
                onCariPaket: () => setState(() => tabAktif = 0),
              ),
              Akun(daftarPesanan: daftarPesanan),
            ],
          ),
          // bar keranjang cuma muncul di beranda, itupun kalau keranjang ada isinya
          if (tabAktif == 0 && keranjang.isNotEmpty)
            // Positioned: nempelin bar keranjang di bawah, kiri kanan dikasih jarak
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: BarKeranjang(
                foto: cariPaket(keranjang.keys.first)['foto'],
                mitra: mitraKeranjang!,
                jumlahPorsi: jumlahPorsi,
                total: totalKeranjang,
                onTap: bukaKeranjang,
              ),
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
          NavigationDestination(
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
      ),
    );
  }
}
