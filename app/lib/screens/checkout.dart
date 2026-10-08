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
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/aksi_mitra.dart';
import 'package:sisa_rasa/utils/format.dart';
import 'package:sisa_rasa/widgets/pilih_metode.dart';

/// halaman checkout (figma v3): cek isi pesanan, pilih cara bayar, lalu bayar
/// (F-09, F-10, F-56)
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

  /// baris VA: kalau belum VA langsung pilih BCA, kalau udah VA buka daftar bank
  Future<void> pilihVa() async {
    if (!MetodeBayar.isVa(metode)) {
      setState(() => metode = MetodeBayar.va);
      return;
    }
    final bank = await pilihMetode(context, aktif: metode, hanyaBank: true);
    if (bank != null && mounted) setState(() => metode = bank);
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
    final hemat = hargaNormal - subtotal;

    return Scaffold(
      backgroundColor: Warna.latar,
      appBar: AppBar(
        backgroundColor: Warna.latar,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 4,
        title: const Text(
          'Checkout',
          style: TextStyle(
            fontSize: 18,
            height: 24 / 18,
            letterSpacing: -0.18,
            fontWeight: FontWeight.w700,
            color: Warna.teks,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          // ambil sendiri: jam ambil + mitra
          _Kartu(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Warna.softGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.schedule,
                      size: 20,
                      color: Warna.hijau,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ambil hari ini', style: _Gaya.keterangan),
                        const SizedBox(height: 2),
                        Text(
                          '${jam(pertama['mulai'])} – ${jam(pertama['tutup'])}',
                          style: _Gaya.judul.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Warna.mendesakLembut,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      sudahBuka(pertama)
                          ? 'Tutup ${sisaWaktu(pertama['tutup'])} lagi'
                          : 'Buka ${sisaWaktu(pertama['mulai'])} lagi',
                      style: _Gaya.keterangan.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Warna.mendesak,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: Warna.garis),
              Row(
                children: [
                  const Icon(
                    Icons.storefront_outlined,
                    size: 20,
                    color: Warna.teks,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pertama['mitra'], style: _Gaya.tebal),
                        const SizedBox(height: 2),
                        Text(pertama['alamat'], style: _Gaya.keterangan),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => bukaPeta(context, pertama['alamat']),
                    child: const Text(
                      'Peta',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Warna.hijau,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // isi pesanan
          _Kartu(
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Pesananmu', style: _Gaya.judul)),
                  Text('$porsi porsi', style: _Gaya.keterangan),
                ],
              ),
              const SizedBox(height: 12),
              for (final id in ids) ...[
                _ItemPesanan(
                  paket: paketCubit.cari(id),
                  jumlah: keranjang[id]!,
                ),
                const SizedBox(height: 12),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Warna.softGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.eco_outlined,
                      size: 16,
                      color: Warna.hijau,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bawa wadah atau tas sendiri, ya. Mitra tidak selalu menyediakan kantong.',
                        style: _Gaya.keterangan.copyWith(color: Warna.hijau),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // metode bayar (F-10)
          _Kartu(
            children: [
              const Text('Metode pembayaran', style: _Gaya.judul),
              const SizedBox(height: 8),
              BarisMetode(
                metode: MetodeBayar.qris,
                dipilih: metode == MetodeBayar.qris,
                onTap: () => setState(() => metode = MetodeBayar.qris),
              ),
              const SizedBox(height: 8),
              BarisMetode(
                metode: MetodeBayar.gopay,
                dipilih: metode == MetodeBayar.gopay,
                onTap: () => setState(() => metode = MetodeBayar.gopay),
              ),
              const SizedBox(height: 8),
              // VA: banknya dipilih dari daftar, yg kepilih ditulis di keterangan
              BarisMetode(
                metode: MetodeBayar.isVa(metode) ? metode : MetodeBayar.va,
                dipilih: MetodeBayar.isVa(metode),
                judul: 'Virtual Account',
                keterangan: MetodeBayar.isVa(metode)
                    ? 'Bank ${MetodeBayar.namaBank(metode)} · ketuk untuk ganti bank'
                    : 'BCA, Mandiri, BRI, BNI',
                panah: true,
                onTap: pilihVa,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // rincian harga (F-09)
          _Kartu(
            children: [
              const Text('Rincian pembayaran', style: _Gaya.judul),
              const SizedBox(height: 10),
              _BarisRincian(
                label: 'Harga normal ($porsi porsi)',
                nilai: rupiah(hargaNormal),
              ),
              const SizedBox(height: 10),
              _BarisRincian(
                label: 'Kamu hemat',
                nilai: '−${rupiah(hemat)}',
                warna: Warna.hijau,
              ),
              // baris biaya layanan ilang sendiri kalau persennya 0
              if (biaya > 0) ...[
                const SizedBox(height: 10),
                _BarisRincian(
                  label: 'Biaya layanan $persenBiayaLayanan%',
                  nilai: rupiah(biaya),
                ),
              ],
              const Divider(height: 21, color: Warna.garis),
              Row(
                children: [
                  const Expanded(
                    child: Text('Total bayar', style: _Gaya.judul),
                  ),
                  Text(rupiah(total), style: _Gaya.harga),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _Jaminan(
            ikon: Icons.verified_user_outlined,
            teks: 'Dana kembali penuh kalau mitra membatalkan pesanan atau paketnya ternyata habis.',
          ),
          const SizedBox(height: 10),
          // F-56: aturan tidak diambil ditampilkan sebelum pembeli bayar
          _Jaminan(
            ikon: Icons.schedule,
            teks:
                'Ambil sebelum ${jam(pertama['tutup'])}. Pesanan yang tidak diambil sampai jam tutup menjadi Tidak diambil, dan dananya tidak dikembalikan.',
          ),
        ],
      ),
      // bilah bayar: total + tombol bayar
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Warna.garis)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total · ${MetodeBayar.isVa(metode) ? 'VA ${MetodeBayar.namaBank(metode)}' : MetodeBayar.nama(metode)}',
                    style: _Gaya.keterangan,
                  ),
                  Text(rupiah(total), style: _Gaya.harga),
                  Text(
                    'Hemat ${rupiah(hemat)}',
                    style: _Gaya.keterangan.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Warna.hijau,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 168,
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
                    : const FittedBox(
                        child: Text(
                          'Bayar sekarang',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// gaya teks yg dipake berulang di checkout (token figma v3)
abstract final class _Gaya {
  static const keterangan = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: 0.1,
    fontWeight: FontWeight.w500,
    color: Warna.teksPendukung,
  );
  static const judul = TextStyle(
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
    color: Warna.teks,
  );
  static const tebal = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w700,
    color: Warna.teks,
  );
  static const harga = TextStyle(
    fontSize: 20,
    height: 24 / 20,
    letterSpacing: -0.2,
    fontWeight: FontWeight.w800,
    color: Warna.teks,
  );
}

/// kartu putih bergaris tipis, radius 20
class _Kartu extends StatelessWidget {
  const _Kartu({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Warna.garis),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// satu paket di kartu Pesananmu: foto, nama, deskripsi, jumlah × harga
class _ItemPesanan extends StatelessWidget {
  const _ItemPesanan({required this.paket, required this.jumlah});

  final Map<String, dynamic> paket;
  final int jumlah;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            paket['foto'],
            width: 56,
            height: 56,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                paket['nama'],
                style: _Gaya.tebal.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                paket['deskripsi'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _Gaya.keterangan,
              ),
              const SizedBox(height: 2),
              Text(
                '$jumlah × ${rupiah(paket['hargaDiskon'])}',
                style: _Gaya.keterangan,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              rupiah((paket['hargaDiskon'] as int) * jumlah),
              style: _Gaya.tebal,
            ),
            const SizedBox(height: 2),
            Text(
              rupiah((paket['hargaAsli'] as int) * jumlah),
              style: _Gaya.keterangan.copyWith(
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BarisRincian extends StatelessWidget {
  const _BarisRincian({required this.label, required this.nilai, this.warna});

  final String label;
  final String nilai;
  // kalau diisi, label sama nilainya pake warna ini (baris "Kamu hemat")
  final Color? warna;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              height: 20 / 14,
              fontWeight: FontWeight.w500,
              color: warna ?? Warna.teksPendukung,
            ),
          ),
        ),
        Text(
          nilai,
          style: TextStyle(
            fontSize: 14,
            height: 20 / 14,
            fontWeight: FontWeight.w600,
            color: warna ?? Warna.teks,
          ),
        ),
      ],
    );
  }
}

/// baris ikon + keterangan kecil di bawah kartu (jaminan dana, aturan ambil)
class _Jaminan extends StatelessWidget {
  const _Jaminan({required this.ikon, required this.teks});

  final IconData ikon;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: 20, color: Warna.teksPendukung),
          const SizedBox(width: 10),
          Expanded(child: Text(teks, style: _Gaya.keterangan)),
        ],
      ),
    );
  }
}
