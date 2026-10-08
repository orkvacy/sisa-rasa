import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sisa_rasa/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/bloc/pesanan_event.dart';
import 'package:sisa_rasa/data/pembayaran.dart';
import 'package:sisa_rasa/data/status_pesanan.dart';
import 'package:sisa_rasa/router.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';
import 'package:sisa_rasa/widgets/hitung_mundur.dart';
import 'package:sisa_rasa/widgets/pilih_metode.dart';

/// halaman bayar (figma v3): QR / nomor VA / GoPay plus hitung mundur batas bayar (F-10, F-40)
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

  Future<void> gantiMetode(BuildContext context, String aktif) async {
    final bloc = context.read<PesananBloc>();
    final baru = await pilihMetode(context, aktif: aktif);
    if (baru != null) bloc.add(MetodeDiganti(idPesanan, baru));
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
    final bisaDiubah = menunggu && !mengecek;

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
        backgroundColor: Warna.latar,
        appBar: AppBar(
          backgroundColor: Warna.latar,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 4,
          // layar ini modal penuh, jadi pakai tombol tutup (komponen App bar di figma)
          leading: IconButton(
            tooltip: 'Tutup',
            onPressed: () => context.pop(),
            icon: const Icon(Icons.close),
          ),
          title: Text(
            MetodeBayar.isVa(metode)
                ? MetodeBayar.nama(metode)
                : 'Bayar dengan ${MetodeBayar.nama(metode)}',
            style: const TextStyle(
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
            // batas bayar (F-40)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Warna.mendesakLembut,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Wrap: kalau ga muat (HP kecil / huruf diperbesar) turun ke baris bawah (NF-01)
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Selesaikan pembayaran dalam ',
                        style: _Gaya.isi,
                      ),
                      if (menunggu)
                        HitungMundur(
                          batas: pesanan['batasBayar'],
                          onHabis: () => batalkan(
                            context,
                            'Tidak dibayar dalam $menitBatasBayar menit.',
                            otomatis: true,
                          ),
                          style: _Gaya.isi.copyWith(
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
                    style: _Gaya.keterangan.copyWith(color: Warna.mendesak),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // kartu tagihan: QR / nomor VA / GoPay
            _Kartu(
              child: Column(
                children: [
                  Text(
                    '${MetodeBayar.isVa(metode) ? '${MetodeBayar.namaBank(metode)} Virtual Account' : MetodeBayar.nama(metode)} · Sisa Rasa – ${pesanan['mitra']}',
                    textAlign: TextAlign.center,
                    style: _Gaya.keterangan,
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
                    _IsiTagihan(metode: metode, tagihan: tagihan),
                  const SizedBox(height: 16),
                  const Text('Total bayar', style: _Gaya.keterangan),
                  const SizedBox(height: 2),
                  Text(
                    rupiah(pesanan['total']),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Warna.teks,
                    ),
                  ),
                  if (tagihan.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _AksiTagihan(pesanan: pesanan),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // cara bayar
            _Kartu(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cara bayar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Warna.teks,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final (i, langkah) in _langkah(pesanan).indexed) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: Warna.softGreen,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Warna.hijau,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(langkah, style: _Gaya.isi)),
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
                style: _Gaya.keterangan,
              ),
            ],
          ],
        ),
        // cek status, ganti metode, batalkan
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    // dikunci selama nunggu jawaban, biar ga kepencet berkali-kali
                    onPressed: !bisaDiubah || tagihan.isEmpty
                        ? null
                        : () => context.read<PesananBloc>().add(
                            PembayaranDicek(idPesanan),
                          ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Warna.teks,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Warna.garisKontrol),
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
                              color: Warna.hijau,
                            ),
                          )
                        : const Text(
                            'Saya sudah bayar · cek status',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                // Wrap: dua tautan turun baris kalau ga muat (NF-01)
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton(
                      onPressed: bisaDiubah
                          ? () => gantiMetode(context, metode)
                          : null,
                      style: TextButton.styleFrom(foregroundColor: Warna.hijau),
                      child: const Text(
                        'Ganti metode pembayaran',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    // F-55: selama belum dibayar, pembeli boleh batal sendiri
                    TextButton(
                      onPressed: bisaDiubah ? () => tanyaBatal(context) : null,
                      style: TextButton.styleFrom(foregroundColor: Warna.merah),
                      child: const Text(
                        'Batalkan pesanan',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<String> _langkah(Map<String, dynamic> pesanan) {
    final String metode = pesanan['metode'];
    return switch (metode) {
      MetodeBayar.qris => const [
        'Buka GoPay, OVO, DANA, ShopeePay, atau m-banking.',
        'Pindai QR di atas, atau unggah QR yang sudah disimpan.',
        'Bayar, lalu tekan "Saya sudah bayar".',
      ],
      MetodeBayar.gopay => const [
        'Tekan Buka GoPay, aplikasi Gojek akan terbuka.',
        'Periksa total, lalu konfirmasi pembayaran.',
        'Kembali ke sini dan tekan "Saya sudah bayar".',
      ],
      _ => [
        'Buka ${MetodeBayar.aplikasiBank(metode)}, lalu pilih transfer ke ${MetodeBayar.namaBank(metode)} Virtual Account.',
        'Masukkan nomor di atas. Pastikan nama penerima tertulis Sisa Rasa – ${pesanan['mitra']}.',
        'Bayar tepat sesuai total, lalu tekan "Saya sudah bayar".',
      ],
    };
  }
}

abstract final class _Gaya {
  static const keterangan = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: 0.1,
    fontWeight: FontWeight.w500,
    color: Warna.teksPendukung,
  );
  static const isi = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    color: Warna.teks,
  );
}

class _Kartu extends StatelessWidget {
  const _Kartu({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Warna.garis),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

/// isi kartu tagihan sesuai metode bayarnya
class _IsiTagihan extends StatelessWidget {
  const _IsiTagihan({required this.metode, required this.tagihan});

  final String metode;
  final Map<String, String> tagihan;

  @override
  Widget build(BuildContext context) {
    if (metode == MetodeBayar.qris) {
      // QrImageView: gambar QR dari isi tagihan
      return QrImageView(data: tagihan['isiQr']!, size: 190);
    }
    if (metode == MetodeBayar.gopay) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Icon(
          Icons.account_balance_wallet_outlined,
          size: 56,
          color: Warna.hijau,
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Warna.latar,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Text('Nomor virtual account', style: _Gaya.keterangan),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              tagihan['nomorVa']!,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Warna.teks,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// dua tombol di bawah total: simpan / salin + bagikan, atau buka GoPay
class _AksiTagihan extends StatelessWidget {
  const _AksiTagihan({required this.pesanan});

  final Map<String, dynamic> pesanan;

  String get _metode => pesanan['metode'];
  Map<String, String> get _tagihan => pesanan['tagihan'];

  void _kabar(BuildContext context, String pesan) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(pesan)));
  }

  /// QR digambar ulang jadi PNG berlatar putih (ada pinggiran), dipake buat simpan sama bagikan
  Future<Uint8List> _gambarQr() async {
    const sisi = 720.0;
    const tepi = 48.0;
    final painter = QrPainter(
      data: _tagihan['isiQr']!,
      version: QrVersions.auto,
      gapless: true,
    );
    final perekam = ui.PictureRecorder();
    final kanvas = Canvas(perekam)
      ..drawRect(
        const Rect.fromLTWH(0, 0, sisi, sisi),
        Paint()..color = Colors.white,
      )
      ..translate(tepi, tepi);
    painter.paint(kanvas, const Size(sisi - tepi * 2, sisi - tepi * 2));
    final gambar = await perekam.endRecording().toImage(
      sisi.toInt(),
      sisi.toInt(),
    );
    final data = await gambar.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> _simpanQr(BuildContext context) async {
    try {
      final gambar = await _gambarQr();
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      await Gal.putImageBytes(gambar, name: 'qris-${pesanan['nomor']}');
      if (context.mounted) _kabar(context, 'QR disimpan ke galeri');
    } on GalException {
      if (context.mounted) {
        _kabar(context, 'QR tidak bisa disimpan. Cek izin galeri.');
      }
    }
  }

  Future<void> _bagikan(BuildContext context) async {
    final teks =
        'Pembayaran Sisa Rasa – ${pesanan['mitra']}, total ${rupiah(pesanan['total'])}';
    if (_metode == MetodeBayar.qris) {
      final gambar = await _gambarQr();
      await SharePlus.instance.share(
        ShareParams(
          text: teks,
          files: [
            XFile.fromData(
              gambar,
              mimeType: 'image/png',
              name: 'qris-${pesanan['nomor']}.png',
            ),
          ],
        ),
      );
    } else {
      await SharePlus.instance.share(
        ShareParams(
          text: '$teks\n${MetodeBayar.nama(_metode)}: ${_tagihan['nomorVa']}',
        ),
      );
    }
  }

  Future<void> _salinNomor(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(text: _tagihan['nomorVa']!.replaceAll(' ', '')),
    );
    if (context.mounted) _kabar(context, 'Nomor virtual account disalin');
  }

  @override
  Widget build(BuildContext context) {
    if (_metode == MetodeBayar.gopay) {
      return _TombolGaris(
        teks: 'Buka GoPay',
        onPressed: () => _kabar(
          context,
          'Mode uji: aplikasi Gojek belum dibuka. Tekan "Saya sudah bayar".',
        ),
      );
    }
    final qris = _metode == MetodeBayar.qris;
    return Row(
      children: [
        Expanded(
          child: _TombolGaris(
            teks: qris ? 'Simpan QR' : 'Salin nomor',
            onPressed: () => qris ? _simpanQr(context) : _salinNomor(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TombolGaris(
            teks: 'Bagikan',
            onPressed: () => _bagikan(context),
          ),
        ),
      ],
    );
  }
}

class _TombolGaris extends StatelessWidget {
  const _TombolGaris({required this.teks, required this.onPressed});

  final String teks;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Warna.teks,
          side: const BorderSide(color: Warna.garisKontrol),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: FittedBox(
          child: Text(
            teks,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
