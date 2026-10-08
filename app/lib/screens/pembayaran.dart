import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sisa_rasa/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/bloc/pesanan_event.dart';
import 'package:sisa_rasa/data/pembayaran.dart';
import 'package:sisa_rasa/data/status_pesanan.dart';
import 'package:sisa_rasa/router.dart';
import 'package:sisa_rasa/theme/teks.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';
import 'package:sisa_rasa/widgets/hitung_mundur.dart';

/// halaman bayar: QR / nomor VA / GoPay plus hitung mundur batas bayar (F-10, F-40)
class Pembayaran extends StatelessWidget {
  const Pembayaran({required this.idPesanan, super.key});

  final String idPesanan;

  String? _status(List<Map<String, dynamic>> daftar) {
    for (final pesanan in daftar) {
      if (pesanan['id'] == idPesanan) return pesanan['status'];
    }
    return null;
  }

  void batalkan(BuildContext context, String alasan, {bool otomatis = false}) {
    context.read<PesananBloc>().add(
      PesananDibatalkan(idPesanan, alasan: alasan, otomatis: otomatis),
    );
  }

  Future<void> tanyaBatal(BuildContext context) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan pesanan?'),
        content: const Text(
          'Porsinya dikembalikan ke mitra dan bisa dipesan orang lain. Belum ada dana yang ditarik.',
        ),
        actions: [
          // dialog bukan rute halaman, jadi nutupnya pake Navigator.pop
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kembali'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Warna.merah),
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
    if (yakin == true && context.mounted) {
      batalkan(context, 'Kamu membatalkan sebelum membayar.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.watch<PesananBloc>();
    final pesanan = bloc.cari(idPesanan);

    if (pesanan == null) {
      return const Scaffold(
        backgroundColor: Warna.latar,
        body: Center(child: Text('Pesanan tidak ditemukan')),
      );
    }

    final String metode = pesanan['metode'];
    final Map<String, String> tagihan = pesanan['tagihan'];
    final bool mengecek = pesanan['mengecek'];
    final bool menunggu = pesanan['status'] == StatusPesanan.menungguBayar;

    // BlocListener: dengerin perubahan status pesanan ini aja.
    // lunas -> detail pesanan, batal -> balik ke daftar pesanan.
    // pake go biar layar pembayaran ketutup dan ga bisa di-back lagi
    return BlocListener<PesananBloc, List<Map<String, dynamic>>>(
      listenWhen: (lama, baru) => _status(lama) != _status(baru),
      listener: (context, daftar) {
        final baru = context.read<PesananBloc>().cari(idPesanan)!;
        if (baru['status'] == StatusPesanan.disiapkan) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Pembayaran berhasil')));
          context.go(Rute.detailPesanan(idPesanan));
        } else if (baru['status'] == StatusPesanan.dibatalkan) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Pesanan dibatalkan. ${baru['alasan']}')),
          );
          context.go(Rute.pesanan);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Warna.latar,
          surfaceTintColor: Colors.transparent,
          title: Text(
            metode == MetodeBayar.va
                ? MetodeBayar.nama(metode)
                : 'Bayar dengan ${MetodeBayar.nama(metode)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 170),
          children: [
            // batas bayar (F-40)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Warna.mendesakLembut,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Wrap: kalau ga muat (HP kecil / huruf diperbesar) turun ke baris bawah, ga meluber (NF-01)
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Selesaikan pembayaran dalam ',
                        style: TextStyle(color: Warna.mendesak),
                      ),
                      if (menunggu)
                        HitungMundur(
                          batas: pesanan['batasBayar'],
                          onHabis: () => batalkan(
                            context,
                            'Tidak dibayar dalam $menitBatasBayar menit.',
                            otomatis: true,
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Warna.mendesak,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Porsimu disimpan sampai ${jam(pesanan['batasMenit'])}. Lewat dari itu, pesanan batal otomatis.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: Teks.keterangan,
                      color: Warna.mendesak,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // kartu tagihan: QR / nomor VA / GoPay
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    '${MetodeBayar.nama(metode)} · Sisa Rasa – ${pesanan['mitra']}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: Teks.keterangan,
                      color: Warna.teksPendukung,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (tagihan.isEmpty)
                    // tagihan belum dateng dari penyedia pembayaran
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: Warna.hijau),
                          SizedBox(height: 12),
                          Text(
                            'Menyiapkan tagihan…',
                            style: TextStyle(color: Warna.teksPendukung),
                          ),
                        ],
                      ),
                    )
                  else
                    _Tagihan(metode: metode, tagihan: tagihan),
                  const SizedBox(height: 16),
                  const Text(
                    'Total bayar',
                    style: TextStyle(color: Warna.teksPendukung),
                  ),
                  Text(
                    rupiah(pesanan['total']),
                    style: const TextStyle(
                      fontSize: Teks.judul,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // cara bayar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cara bayar',
                    style: TextStyle(
                      fontSize: Teks.nama,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final (i, langkah) in _langkah(metode).indexed) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: Warna.softGreen,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontSize: Teks.kecil,
                              fontWeight: FontWeight.w700,
                              color: Warna.hijau,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(langkah)),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            if (bloc.modeUji) ...[
              const SizedBox(height: 12),
              const Text(
                'Mode uji: pembayaran disimulasikan, tidak ada uang yang berpindah. Tekan "Saya sudah bayar" untuk melanjutkan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Teks.kecil,
                  color: Warna.teksPendukung,
                ),
              ),
            ],
          ],
        ),
        // tombol cek status + batalkan nempel di bawah
        bottomNavigationBar: Container(
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
                  // dikunci selama nunggu jawaban, biar ga kepencet berkali-kali
                  onPressed: !menunggu || mengecek || tagihan.isEmpty
                      ? null
                      : () => context.read<PesananBloc>().add(
                          PembayaranDicek(idPesanan),
                        ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Warna.hijau,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: mengecek
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Saya sudah bayar · cek status',
                          style: TextStyle(
                            fontSize: Teks.tombol,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              // F-55: selama belum dibayar, pembeli boleh batal sendiri
              TextButton(
                onPressed: menunggu && !mengecek
                    ? () => tanyaBatal(context)
                    : null,
                style: TextButton.styleFrom(foregroundColor: Warna.merah),
                child: const Text('Batalkan pesanan'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _langkah(String metode) => switch (metode) {
    MetodeBayar.qris => const [
      'Buka GoPay, OVO, DANA, ShopeePay, atau m-banking.',
      'Pindai QR di atas.',
      'Bayar, lalu tekan "Saya sudah bayar".',
    ],
    MetodeBayar.gopay => const [
      'Tekan Buka GoPay, aplikasi Gojek akan terbuka.',
      'Periksa total, lalu konfirmasi pembayaran.',
      'Kembali ke sini dan tekan "Saya sudah bayar".',
    ],
    _ => const [
      'Buka m-BCA, KlikBCA, atau ATM BCA, lalu pilih transfer ke BCA Virtual Account.',
      'Masukkan nomor di atas. Pastikan penerimanya Sisa Rasa.',
      'Bayar tepat sesuai total, lalu tekan "Saya sudah bayar".',
    ],
  };
}

/// isi kartu tagihan sesuai metode bayarnya
class _Tagihan extends StatelessWidget {
  const _Tagihan({required this.metode, required this.tagihan});

  final String metode;
  final Map<String, String> tagihan;

  @override
  Widget build(BuildContext context) {
    switch (metode) {
      case MetodeBayar.qris:
        // QrImageView: gambar QR dari isi tagihan
        return QrImageView(data: tagihan['isiQr']!, size: 190);
      case MetodeBayar.gopay:
        return Column(
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 56,
              color: Warna.hijau,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Mode uji: aplikasi Gojek belum dibuka. Tekan "Saya sudah bayar".',
                  ),
                ),
              ),
              child: const Text('Buka GoPay'),
            ),
          ],
        );
      default:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: Warna.latar,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Text(
                'Nomor virtual account',
                style: TextStyle(color: Warna.teksPendukung),
              ),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(
                  tagihan['nomorVa']!,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: Teks.subjudul,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(
                    ClipboardData(
                      text: tagihan['nomorVa']!.replaceAll(' ', ''),
                    ),
                  );
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Nomor VA disalin')),
                  );
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Salin nomor'),
              ),
            ],
          ),
        );
    }
  }
}
