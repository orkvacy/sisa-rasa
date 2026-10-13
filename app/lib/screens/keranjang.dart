import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/bloc/pesanan_event.dart';
import 'package:sisa_rasa/cubit/keranjang_cubit.dart';
import 'package:sisa_rasa/cubit/paket_cubit.dart';
import 'package:sisa_rasa/screens/kode_ambil.dart';
import 'package:sisa_rasa/theme/teks.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';
import 'package:sisa_rasa/widgets/kartu_keranjang.dart';

/// halaman keranjang, dibuka dari bar keranjang
class Keranjang extends StatefulWidget {
  const Keranjang({super.key});

  @override
  State<Keranjang> createState() => _KeranjangState();
}

class _KeranjangState extends State<Keranjang> {
  void pesan() {
    final keranjang = context.read<KeranjangCubit>().state;
    final paketCubit = context.read<PaketCubit>();
    // bloc diubah lewat event: kirim event PesananDibuat, bloc yg ngurus sisanya
    context.read<PesananBloc>().add(
      PesananDibuat(keranjang: keranjang, daftarPaket: paketCubit.state),
    );
    // cubit cukup panggil fungsinya langsung
    paketCubit.kurangiStok(keranjang);
    context.read<KeranjangCubit>().kosongkan();
  }

  // dipanggil BlocListener di bawah pas pesanan baru udah masuk
  Future<void> bukaKodeAmbil(Map<String, dynamic> pesanan) async {
    // buka kode ambil, terus tunggu balikannya
    final lihatPesanan = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        // halaman kode ambil buat pesanan baru
        builder: (context) => KodeAmbil(pesanan: pesanan, pesananBaru: true),
      ),
    );
    if (!mounted) return;
    // keranjang ikut ditutup, jawabannya diterusin ke halaman utama
    Navigator.pop(context, lihatPesanan);
  }

  @override
  Widget build(BuildContext context) {
    // context.watch: tiap keranjang / stok berubah, halaman ini digambar ulang
    final keranjang = context.watch<KeranjangCubit>().state;
    final paketCubit = context.watch<PaketCubit>();
    final ids = keranjang.keys.toList();
    // paket pertama, dipake buat info mitra sama jam ambil
    final pertama = ids.isEmpty
        ? <String, dynamic>{}
        : paketCubit.cari(ids.first);

    var total = 0;
    var hargaNormal = 0;
    var porsi = 0;
    for (final id in ids) {
      final paket = paketCubit.cari(id);
      total += (paket['hargaDiskon'] as int) * keranjang[id]!;
      hargaNormal += (paket['hargaAsli'] as int) * keranjang[id]!;
      porsi += keranjang[id]!;
    }

    // BlocListener: ga gambar apa2, cuma "dengerin" PesananBloc.
    // pas jumlah pesanan nambah (berarti barusan pesen), buka halaman kode ambil
    return BlocListener<PesananBloc, List<Map<String, dynamic>>>(
      listenWhen: (lama, baru) => baru.length > lama.length,
      listener: (context, daftarPesanan) => bukaKodeAmbil(daftarPesanan.first),
      // Scaffold: kerangka halaman keranjang
      child: Scaffold(
        // AppBar: bar atas + tombol kosongkan
        appBar: AppBar(
          backgroundColor: Warna.latar,
          surfaceTintColor: Colors.transparent,
          // judul halaman
          title: const Text(
            'Keranjang',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            if (ids.isNotEmpty)
              // TextButton: tombol tulisan doang tanpa latar
              TextButton(
                onPressed: () => context.read<KeranjangCubit>().kosongkan(),
                // tulisan kosongkan
                child: const Text(
                  'Kosongkan',
                  style: TextStyle(
                    color: Warna.hijau,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        body: ids.isEmpty
            // Center: kalau keranjang kosong, isinya ditaruh di tengah layar
            ? Center(
                // Padding: jarak pinggir isi kosong
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  // Column: icon, tulisan, tombol disusun ke bawah
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // icon tas belanja
                      const Icon(
                        Icons.shopping_bag_outlined,
                        size: 64,
                        color: Warna.teksPendukung,
                      ),
                      // jarak
                      const SizedBox(height: 12),
                      // tulisan keranjang kosong
                      const Text(
                        'Keranjang kosong',
                        style: TextStyle(
                          fontSize: Teks.nama,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      // jarak
                      const SizedBox(height: 4),
                      // petunjuk cara pesan
                      const Text(
                        'Pilih paket di Beranda, lalu ambil sendiri di jam yang ditentukan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Warna.teksPendukung),
                      ),
                      // jarak
                      const SizedBox(height: 16),
                      // OutlinedButton: balik ke beranda
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        // tulisan tombol
                        child: const Text('Cari paket'),
                      ),
                    ],
                  ),
                ),
              )
            // Stack: isi keranjang di belakang, bar tombol pesan nempel di bawah
            : Stack(
                children: [
                  // ListView: isi keranjang bisa di scroll
                  ListView(
                    // bawahnya dikasih jarak biar isinya ga ketutup bar tombol
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
                    children: [
                      // Container: kotak putih isi keranjang
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        // Column: mitra, daftar paket, info disusun ke bawah
                        child: Column(
                          children: [
                            // Row: nama mitra + jarak
                            Row(
                              children: [
                                // icon toko
                                const Icon(Icons.storefront_outlined, size: 20),
                                // jarak
                                const SizedBox(width: 8),
                                // Expanded: dorong jarak ke kanan
                                Expanded(
                                  // nama mitra
                                  child: Text(
                                    pertama['mitra'],
                                    style: const TextStyle(
                                      fontSize: Teks.tombol,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                // jarak ke mitra
                                Text(
                                  pertama['jarak'],
                                  style: const TextStyle(
                                    color: Warna.teksPendukung,
                                  ),
                                ),
                              ],
                            ),
                            // jarak
                            const SizedBox(height: 14),
                            for (final id in ids) ...[
                              // satu kartu paket di keranjang
                              KartuKeranjang(
                                key: ValueKey(id),
                                paket: paketCubit.cari(id),
                                jumlah: keranjang[id]!,
                                onJumlahBerubah: (baru) => context
                                    .read<KeranjangCubit>()
                                    .ubahJumlah(id, baru),
                              ),
                              // jarak antar kartu
                              const SizedBox(height: 12),
                            ],
                            // Container: kotak info satu mitra
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Warna.latar,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              // Row: icon info + tulisan
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // icon info
                                  Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: Warna.teksPendukung,
                                  ),
                                  // jarak
                                  SizedBox(width: 8),
                                  // Expanded biar tulisannya turun baris
                                  Expanded(
                                    // info satu pesanan satu mitra
                                    child: Text(
                                      'Satu pesanan hanya dari satu mitra, karena diambil langsung di tempat.',
                                      style: TextStyle(
                                        fontSize: Teks.keterangan,
                                        color: Warna.teksPendukung,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // jarak
                      const SizedBox(height: 12),
                      // kotak jam ambil
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        // Column: isi kotak jam ambil
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Row: tulisan + pil hitung mundur
                            Row(
                              children: [
                                // Expanded: dorong pil ke kanan
                                const Expanded(
                                  // tulisan ambil hari ini
                                  child: Text(
                                    'Ambil hari ini',
                                    style: TextStyle(
                                      color: Warna.teksPendukung,
                                    ),
                                  ),
                                ),
                                // Container: pil hitung mundur
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Warna.mendesakLembut,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  // sisa waktu buka / tutup
                                  child: Text(
                                    sudahBuka(pertama)
                                        ? 'Tutup ${sisaWaktu(pertama['tutup'])} lagi'
                                        : 'Buka ${sisaWaktu(pertama['mulai'])} lagi',
                                    style: const TextStyle(
                                      fontSize: Teks.keterangan,
                                      fontWeight: FontWeight.w700,
                                      color: Warna.mendesak,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // jarak
                            const SizedBox(height: 6),
                            // jam ambil
                            Text(
                              '${jam(pertama['mulai'])} – ${jam(pertama['tutup'])}',
                              style: const TextStyle(
                                fontSize: Teks.judul,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // jarak
                      const SizedBox(height: 12),
                      // ringkasan harga
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        // Column: baris2 rincian harga
                        child: Column(
                          children: [
                            // Row: harga normal
                            Row(
                              children: [
                                // Expanded: dorong angka ke kanan
                                Expanded(
                                  // label harga normal
                                  child: Text(
                                    'Harga normal · $porsi porsi',
                                    style: const TextStyle(
                                      color: Warna.teksPendukung,
                                    ),
                                  ),
                                ),
                                // total harga normal
                                Text(rupiah(hargaNormal)),
                              ],
                            ),
                            // jarak
                            const SizedBox(height: 8),
                            // Row: hemat
                            Row(
                              children: [
                                // dorong angka ke kanan
                                const Expanded(
                                  // label hemat
                                  child: Text(
                                    'Kamu hemat',
                                    style: TextStyle(
                                      color: Warna.teksPendukung,
                                    ),
                                  ),
                                ),
                                // jumlah hemat
                                Text(
                                  '−${rupiah(hargaNormal - total)}',
                                  style: const TextStyle(color: Warna.hijau),
                                ),
                              ],
                            ),
                            // Divider: garis pemisah horizontal
                            const Divider(height: 24, color: Warna.garis),
                            // Row: total bayar
                            Row(
                              children: [
                                // dorong angka ke kanan
                                const Expanded(
                                  // label bayar
                                  child: Text(
                                    'Bayar di tempat',
                                    style: TextStyle(
                                      color: Warna.teksPendukung,
                                    ),
                                  ),
                                ),
                                // total yg dibayar
                                Text(
                                  rupiah(total),
                                  style: const TextStyle(
                                    fontSize: Teks.subjudul,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Positioned: bar tombol pesan nempel di bawah, kiri sampe kanan
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    // Container: latar putih bar tombol pesan
                    child: Container(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        12,
                        16,
                        12 + MediaQuery.of(context).padding.bottom,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        // BoxShadow: bayangan ke atas, sama kayak bar total di modul
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade300,
                            blurRadius: 10,
                            offset: const Offset(0, -3),
                          ),
                        ],
                      ),
                      // Column: tombol + catatan bayar
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // SizedBox: tombol selebar layar
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            // FilledButton: tombol pesan
                            child: FilledButton(
                              onPressed: pesan,
                              style: FilledButton.styleFrom(
                                backgroundColor: Warna.hijau,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              // tulisan tombol + total
                              child: Text(
                                'Pesan · ${rupiah(total)}',
                                style: const TextStyle(
                                  fontSize: Teks.tombol,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          // jarak
                          const SizedBox(height: 8),
                          // catatan bayar di kasir
                          const Text(
                            'Belum bayar sekarang. Bayar di kasir saat mengambil.',
                            style: TextStyle(
                              fontSize: Teks.kecil,
                              color: Warna.teksPendukung,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
