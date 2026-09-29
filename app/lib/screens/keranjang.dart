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
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Warna.latar,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Keranjang',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            if (ids.isNotEmpty)
              TextButton(
                onPressed: () => context.read<KeranjangCubit>().kosongkan(),
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
            // keranjang kosong
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.shopping_bag_outlined,
                        size: 64,
                        color: Warna.teksPendukung,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Keranjang kosong',
                        style: TextStyle(
                          fontSize: Teks.nama,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pilih paket di Beranda, lalu ambil sendiri di jam yang ditentukan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Warna.teksPendukung),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cari paket'),
                      ),
                    ],
                  ),
                ),
              )
            // Stack: isi keranjang di belakang, bar tombol pesan nempel di bawah
            : Stack(
                children: [
                  ListView(
                    // bawahnya dikasih jarak biar isinya ga ketutup bar tombol
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.storefront_outlined, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    pertama['mitra'],
                                    style: const TextStyle(
                                      fontSize: Teks.tombol,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  pertama['jarak'],
                                  style: const TextStyle(
                                    color: Warna.teksPendukung,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            for (final id in ids) ...[
                              KartuKeranjang(
                                key: ValueKey(id),
                                paket: paketCubit.cari(id),
                                jumlah: keranjang[id]!,
                                onJumlahBerubah: (baru) => context
                                    .read<KeranjangCubit>()
                                    .ubahJumlah(id, baru),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Warna.latar,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: Warna.teksPendukung,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
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
                      const SizedBox(height: 12),
                      // kotak jam ambil
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Ambil hari ini',
                                    style: TextStyle(
                                      color: Warna.teksPendukung,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Warna.mendesakLembut,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
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
                            const SizedBox(height: 6),
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
                      const SizedBox(height: 12),
                      // ringkasan harga
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Harga normal · $porsi porsi',
                                    style: const TextStyle(
                                      color: Warna.teksPendukung,
                                    ),
                                  ),
                                ),
                                Text(rupiah(hargaNormal)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Kamu hemat',
                                    style: TextStyle(
                                      color: Warna.teksPendukung,
                                    ),
                                  ),
                                ),
                                Text(
                                  '−${rupiah(hargaNormal - total)}',
                                  style: const TextStyle(color: Warna.hijau),
                                ),
                              ],
                            ),
                            const Divider(height: 24, color: Warna.garis),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Bayar di tempat',
                                    style: TextStyle(
                                      color: Warna.teksPendukung,
                                    ),
                                  ),
                                ),
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              onPressed: pesan,
                              style: FilledButton.styleFrom(
                                backgroundColor: Warna.hijau,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'Pesan · ${rupiah(total)}',
                                style: const TextStyle(
                                  fontSize: Teks.tombol,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
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
