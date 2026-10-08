import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/bloc/pesanan_event.dart';
import 'package:sisa_rasa/data/pembayaran.dart';
import 'package:sisa_rasa/data/status_pesanan.dart';
import 'package:sisa_rasa/router.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/aksi_mitra.dart';
import 'package:sisa_rasa/utils/format.dart';
import 'package:sisa_rasa/widgets/bagian_pesanan.dart';
import 'package:sisa_rasa/widgets/hitung_mundur.dart';

/// detail satu pesanan (figma v3: pembeli/status pesanan, F-41).
/// kepala hijau, tahapan Dibayar -> Disiapkan -> Siap diambil, lalu rinciannya
class DetailPesanan extends StatelessWidget {
  const DetailPesanan({required this.idPesanan, super.key});

  final String idPesanan;

  @override
  Widget build(BuildContext context) {
    final pesanan = context.select<PesananBloc, Map<String, dynamic>?>(
      (bloc) => bloc.cari(idPesanan),
    );
    // pesanannya ga ketemu (misal kebuka dari link lama)
    if (pesanan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Pesanan tidak ditemukan')),
      );
    }

    // AnnotatedRegion: ikon status bar dibikin putih, soalnya kepalanya hijau tua
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Warna.latar,
        // kepala diem di atas, cuma lembarnya yg digulir, jadi tombol kembali selalu kepencet
        body: Column(
          children: [
            KepalaHijau(
              judul: 'Detail pesanan',
              onKembali: () => context.pop(),
            ),
            Expanded(
              // latar hijau di belakang sudut lembar yg membulat
              child: ColoredBox(
                color: Warna.momen,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: ColoredBox(
                    color: Warna.latar,
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _BagianStatus(pesanan: pesanan),
                        const SizedBox(height: 8),
                        _BagianLokasi(pesanan: pesanan),
                        const SizedBox(height: 8),
                        BagianIsiPesanan(pesanan: pesanan),
                        const SizedBox(height: 8),
                        _BagianRincian(pesanan: pesanan),
                        const SizedBox(height: 8),
                        BagianInfoPesanan(pesanan: pesanan),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            8,
                            16,
                            24 + MediaQuery.of(context).padding.bottom,
                          ),
                          child: TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Bantuan belum tersedia di versi ini',
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              'Butuh bantuan?',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Warna.hijau,
                              ),
                            ),
                          ),
                        ),
                      ],
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

/// tahapan + kotak status, isinya beda tiap status
class _BagianStatus extends StatelessWidget {
  const _BagianStatus({required this.pesanan});

  final Map<String, dynamic> pesanan;

  @override
  Widget build(BuildContext context) {
    final String status = pesanan['status'];
    final batal = status == StatusPesanan.dibatalkan;

    return BlokPutih(
      children: [
        if (!batal) ...[
          TahapanPesanan(status: status),
          const SizedBox(height: 16),
        ],
        switch (status) {
          StatusPesanan.menungguBayar => _KotakMenungguBayar(pesanan: pesanan),
          StatusPesanan.disiapkan ||
          StatusPesanan.siapDiambil => _KotakKode(pesanan: pesanan),
          StatusPesanan.dibatalkan => KotakKeterangan(
            latar: Warna.merahLembut,
            warnaJudul: Warna.merah,
            judul: 'Pesanan dibatalkan',
            teks: pesanan['dibayarPada'] == null
                ? '${pesanan['alasan']} Tidak ada dana yang terpotong.'
                : '${pesanan['alasan']} Dana ${rupiah(pesanan['total'])} dikembalikan ke ${MetodeBayar.nama(pesanan['metode'])}.',
          ),
          StatusPesanan.tidakDiambil => KotakKeterangan(
            latar: Warna.garis,
            warnaJudul: Warna.teks,
            judul: 'Tidak diambil',
            teks:
                'Pesanan tidak diambil sampai ${jam(pesanan['tutup'])}, jadi dana tidak dikembalikan.',
          ),
          _ => KotakKeterangan(
            latar: Warna.softGreen,
            warnaJudul: Warna.hijau,
            judul: 'Pesanan sudah diambil',
            teks:
                '${pesanan['porsi']} porsi terselamatkan dari tempat sampah. Terima kasih!',
          ),
        },
      ],
    );
  }
}

/// belum dibayar: hitung mundur batas bayar (F-40) + tombol bayar
class _KotakMenungguBayar extends StatelessWidget {
  const _KotakMenungguBayar({required this.pesanan});

  final Map<String, dynamic> pesanan;

  @override
  Widget build(BuildContext context) {
    const gaya = TextStyle(
      fontSize: 16,
      height: 22 / 16,
      fontWeight: FontWeight.w700,
      color: Warna.teks,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Warna.mendesakLembut,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              const Text('Selesaikan pembayaran dalam ', style: gaya),
              HitungMundur(
                batas: pesanan['batasBayar'],
                onHabis: () => context.read<PesananBloc>().add(
                  PesananDibatalkan(
                    pesanan['id'],
                    alasan: 'Tidak dibayar dalam $menitBatasBayar menit.',
                    otomatis: true,
                  ),
                ),
                style: gaya.copyWith(color: Warna.mendesak),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Porsimu disimpan sampai ${jam(pesanan['batasMenit'])}. Lewat dari itu, pesanan batal otomatis dan porsinya dilepas.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              height: 16 / 12,
              letterSpacing: 0.1,
              fontWeight: FontWeight.w500,
              color: Warna.teksPendukung,
            ),
          ),
          const SizedBox(height: 12),
          TombolBesar(
            teks: 'Bayar sekarang · ${MetodeBayar.nama(pesanan['metode'])}',
            onPressed: () => context.push(Rute.pembayaran(pesanan['id'])),
          ),
        ],
      ),
    );
  }
}

/// sudah dibayar: kode ambil sama tombol tampilkan QR
class _KotakKode extends StatelessWidget {
  const _KotakKode({required this.pesanan});

  final Map<String, dynamic> pesanan;

  @override
  Widget build(BuildContext context) {
    final siap = pesanan['status'] == StatusPesanan.siapDiambil;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Warna.softGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            siap ? 'Pesananmu siap diambil!' : 'Pesananmu sedang disiapkan',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              height: 22 / 16,
              fontWeight: FontWeight.w700,
              color: Warna.hijau,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            siap
                ? 'Tunjukkan kode ini di kasir ${pesanan['mitra']} sebelum ${jam(pesanan['tutup'])}.'
                : 'Ambil di kasir ${pesanan['mitra']} mulai ${jam(pesanan['mulai'])}, sebelum ${jam(pesanan['tutup'])}.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              height: 16 / 12,
              letterSpacing: 0.1,
              fontWeight: FontWeight.w500,
              color: Warna.teksPendukung,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            pesanan['kode'],
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 30,
              height: 48 / 30,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: Warna.teks,
            ),
          ),
          const SizedBox(height: 6),
          TombolBesar(
            ikon: Icons.qr_code_2,
            teks: 'Tampilkan QR',
            onPressed: () => context.push(Rute.kodeAmbil(pesanan['kode'])),
          ),
        ],
      ),
    );
  }
}

class _BagianLokasi extends StatelessWidget {
  const _BagianLokasi({required this.pesanan});

  final Map<String, dynamic> pesanan;

  @override
  Widget build(BuildContext context) {
    return BlokPutih(
      judul: 'Lokasi pengambilan',
      children: [
        BarisIkon(
          ikon: Icons.storefront_outlined,
          judul: pesanan['mitra'],
          teks: pesanan['alamat'],
          kanan: TextButton(
            onPressed: () => bukaPeta(context, pesanan['alamat']),
            child: const Text(
              'Peta',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Warna.hijau,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        BarisIkon(
          ikon: Icons.schedule,
          judul: 'Ambil sendiri',
          teks: 'Hari ini, ${jam(pesanan['mulai'])} – ${jam(pesanan['tutup'])}',
        ),
      ],
    );
  }
}

class _BagianRincian extends StatelessWidget {
  const _BagianRincian({required this.pesanan});

  final Map<String, dynamic> pesanan;

  @override
  Widget build(BuildContext context) {
    final lunas = pesanan['dibayarPada'] != null;
    final batal = pesanan['status'] == StatusPesanan.dibatalkan;
    final int biaya = pesanan['biayaLayanan'];

    return BlokPutih(
      judul: 'Rincian pembayaran',
      children: [
        BarisNilai(
          label: 'Harga normal',
          nilai: rupiah(pesanan['hargaNormal']),
        ),
        const SizedBox(height: 10),
        BarisNilai(
          label: 'Kamu hemat',
          nilai: '−${rupiah(pesanan['hemat'])}',
          warnaNilai: Warna.hijau,
        ),
        if (biaya > 0) ...[
          const SizedBox(height: 10),
          BarisNilai(label: 'Biaya layanan', nilai: rupiah(biaya)),
        ],
        const Divider(height: 21, color: Warna.garis),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Total pembayaran',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Warna.teks,
                ),
              ),
            ),
            Text(
              rupiah(pesanan['total']),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Warna.teks,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: Warna.garis),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                switch (pesanan['metode']) {
                  final m when MetodeBayar.isVa(m) =>
                    Icons.account_balance_outlined,
                  MetodeBayar.gopay => Icons.account_balance_wallet_outlined,
                  _ => Icons.qr_code_2,
                },
                size: 18,
                color: Warna.teks,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                MetodeBayar.nama(pesanan['metode']),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Warna.teksPendukung,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: lunas
                    ? Warna.softGreen
                    : (batal ? Warna.garis : Warna.mendesakLembut),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                lunas ? 'Lunas' : (batal ? 'Tidak dibayar' : 'Belum dibayar'),
                style: TextStyle(
                  fontSize: 12,
                  height: 16 / 12,
                  letterSpacing: 0.1,
                  fontWeight: FontWeight.w700,
                  color: lunas
                      ? Warna.hijau
                      : (batal ? Warna.teksPendukung : Warna.mendesak),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
