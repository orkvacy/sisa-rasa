import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/bloc/pesanan_event.dart';
import 'package:sisa_rasa/cubit/akun_cubit.dart';
import 'package:sisa_rasa/cubit/keranjang_cubit.dart';
import 'package:sisa_rasa/cubit/paket_cubit.dart';
import 'package:sisa_rasa/data/pembayaran.dart';
import 'package:sisa_rasa/router.dart';
import 'package:sisa_rasa/theme/teks.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';

/// halaman checkout: cek isi pesanan, pilih cara bayar, lalu bayar (F-09, F-10, F-56)
class Checkout extends StatefulWidget {
  const Checkout({super.key});

  @override
  State<Checkout> createState() => _CheckoutState();
}

class _CheckoutState extends State<Checkout> {
  String metode = MetodeBayar.qris;
  // tombol bayar dikunci selama pesanan dibikin, biar ga kepencet dua kali
  bool memproses = false;

  void bayar() {
    if (memproses) return;
    setState(() => memproses = true);
    // stok ditahan sama PesananBloc, layar ini cukup kirim event
    context.read<PesananBloc>().add(
      PesananDibuat(
        idAkun: context.read<AkunCubit>().state['id']!,
        keranjang: context.read<KeranjangCubit>().state,
        daftarPaket: context.read<PaketCubit>().state,
        metode: metode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keranjang = context.watch<KeranjangCubit>().state;
    final paketCubit = context.watch<PaketCubit>();

    // BlocListener: pas pesanannya udah masuk, keranjang dikosongin terus pindah ke pembayaran.
    // pake go, bukan push, biar checkout sama keranjang ketutup (pesanannya udah jadi)
    return BlocListener<PesananBloc, List<Map<String, dynamic>>>(
      listenWhen: (lama, baru) => baru.length > lama.length,
      listener: (context, daftarPesanan) {
        final keranjangCubit = context.read<KeranjangCubit>();
        context.go(Rute.pembayaran(daftarPesanan.first['id']));
        keranjangCubit.kosongkan();
      },
      child: keranjang.isEmpty
          // sekejap pas keranjang udah dikosongin tapi halamannya belum keganti
          ? const Scaffold(backgroundColor: Warna.latar)
          : _isi(context, keranjang, paketCubit),
    );
  }

  Widget _isi(
    BuildContext context,
    Map<String, int> keranjang,
    PaketCubit paketCubit,
  ) {
    final ids = keranjang.keys.toList();
    final pertama = paketCubit.cari(ids.first);

    var subtotal = 0;
    var hargaNormal = 0;
    var porsi = 0;
    for (final id in ids) {
      final paket = paketCubit.cari(id);
      subtotal += (paket['hargaDiskon'] as int) * keranjang[id]!;
      hargaNormal += (paket['hargaAsli'] as int) * keranjang[id]!;
      porsi += keranjang[id]!;
    }
    final biaya = biayaLayanan(subtotal);
    final total = subtotal + biaya;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Warna.latar,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Checkout',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      // Stack: isi checkout di belakang, bar tombol bayar nempel di bawah
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
            children: [
              // kartu jam ambil + alamat mitra
              _Kartu(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Ambil hari ini',
                            style: TextStyle(color: Warna.teksPendukung),
                          ),
                        ),
                        _Pil(
                          sudahBuka(pertama)
                              ? 'Tutup ${sisaWaktu(pertama['tutup'])} lagi'
                              : 'Buka ${sisaWaktu(pertama['mulai'])} lagi',
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
                    const Divider(height: 24, color: Warna.garis),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.storefront_outlined, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pertama['mitra'],
                                style: const TextStyle(
                                  fontSize: Teks.tombol,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                pertama['alamat'],
                                style: const TextStyle(
                                  fontSize: Teks.keterangan,
                                  color: Warna.teksPendukung,
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
              const SizedBox(height: 12),

              // isi pesanan
              _Kartu(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Pesananmu',
                            style: TextStyle(
                              fontSize: Teks.nama,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '$porsi porsi',
                          style: const TextStyle(color: Warna.teksPendukung),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (final id in ids) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  paketCubit.cari(id)['nama'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${keranjang[id]} × ${rupiah(paketCubit.cari(id)['hargaDiskon'])}',
                                  style: const TextStyle(
                                    fontSize: Teks.keterangan,
                                    color: Warna.teksPendukung,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            rupiah(
                              (paketCubit.cari(id)['hargaDiskon'] as int) *
                                  keranjang[id]!,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    _Catatan(
                      ikon: Icons.shopping_bag_outlined,
                      teks: 'Bawa wadah atau tas sendiri, ya. Tidak semua mitra menyediakan kemasan.',
                      latar: Warna.latar,
                      warna: Warna.teksPendukung,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // pilih cara bayar (F-10)
              _Kartu(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Metode pembayaran',
                      style: TextStyle(
                        fontSize: Teks.nama,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final pilihan in MetodeBayar.semua)
                      _PilihanMetode(
                        metode: pilihan,
                        dipilih: pilihan == metode,
                        onTap: memproses
                            ? null
                            : () => setState(() => metode = pilihan),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // rincian harga (F-09)
              _Kartu(
                child: Column(
                  children: [
                    _BarisRincian(
                      label: 'Harga normal · $porsi porsi',
                      nilai: rupiah(hargaNormal),
                    ),
                    const SizedBox(height: 8),
                    _BarisRincian(
                      label: 'Kamu hemat',
                      nilai: '−${rupiah(hargaNormal - subtotal)}',
                      warnaNilai: Warna.hijau,
                    ),
                    // baris biaya layanan ilang sendiri kalau biayanya 0
                    if (biaya > 0) ...[
                      const SizedBox(height: 8),
                      _BarisRincian(
                        label: 'Biaya layanan $persenBiayaLayanan%',
                        nilai: rupiah(biaya),
                      ),
                    ],
                    const Divider(height: 24, color: Warna.garis),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Total bayar',
                            style: TextStyle(fontWeight: FontWeight.w700),
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
              const SizedBox(height: 12),

              // F-56: aturan tidak diambil wajib keliatan sebelum bayar
              _Catatan(
                ikon: Icons.schedule,
                teks:
                    'Ambil sebelum ${jam(pertama['tutup'])}. Pesanan yang tidak diambil sampai jam tutup menjadi Tidak diambil, dan dananya tidak dikembalikan.',
                latar: Warna.mendesakLembut,
                warna: Warna.mendesak,
              ),
            ],
          ),
          // Positioned: bar tombol bayar nempel di bawah, kiri sampe kanan
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
                      onPressed: memproses ? null : bayar,
                      style: FilledButton.styleFrom(
                        backgroundColor: Warna.hijau,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: memproses
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Bayar · ${rupiah(total)}',
                              style: const TextStyle(
                                fontSize: Teks.tombol,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Porsimu ditahan $menitBatasBayar menit sampai dibayar.',
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
    );
  }
}

/// kartu putih sudut bulet, dipake berulang di checkout
class _Kartu extends StatelessWidget {
  const _Kartu({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

class _Pil extends StatelessWidget {
  const _Pil(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Warna.mendesakLembut,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        teks,
        style: const TextStyle(
          fontSize: Teks.keterangan,
          fontWeight: FontWeight.w700,
          color: Warna.mendesak,
        ),
      ),
    );
  }
}

/// kotak info kecil: ikon + teks, warnanya bisa diatur
class _Catatan extends StatelessWidget {
  const _Catatan({
    required this.ikon,
    required this.teks,
    required this.latar,
    required this.warna,
  });

  final IconData ikon;
  final String teks;
  final Color latar;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: 18, color: warna),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              teks,
              style: TextStyle(fontSize: Teks.keterangan, color: warna),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarisRincian extends StatelessWidget {
  const _BarisRincian({
    required this.label,
    required this.nilai,
    this.warnaNilai,
  });

  final String label;
  final String nilai;
  final Color? warnaNilai;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Warna.teksPendukung),
          ),
        ),
        Text(nilai, style: TextStyle(color: warnaNilai)),
      ],
    );
  }
}

/// satu pilihan metode bayar, bulet di kanan nandain yg dipilih
class _PilihanMetode extends StatelessWidget {
  const _PilihanMetode({
    required this.metode,
    required this.dipilih,
    required this.onTap,
  });

  final String metode;
  final bool dipilih;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ikon = switch (metode) {
      MetodeBayar.qris => Icons.qr_code_2,
      MetodeBayar.gopay => Icons.account_balance_wallet_outlined,
      _ => Icons.account_balance_outlined,
    };
    // InkWell: bikin baris bisa dipencet, ada efek riak pas disentuh
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Warna.latar,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(ikon, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    MetodeBayar.nama(metode),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    MetodeBayar.keterangan(metode),
                    style: const TextStyle(
                      fontSize: Teks.keterangan,
                      color: Warna.teksPendukung,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              dipilih
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: dipilih ? Warna.hijau : Warna.garisKontrol,
            ),
          ],
        ),
      ),
    );
  }
}
