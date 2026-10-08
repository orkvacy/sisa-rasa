import 'package:flutter/foundation.dart';
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
            _Kepala(onKembali: () => context.pop()),
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
                        _BagianIsi(pesanan: pesanan),
                        const SizedBox(height: 8),
                        _BagianRincian(pesanan: pesanan),
                        const SizedBox(height: 8),
                        _BagianInfo(pesanan: pesanan),
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

class _Kepala extends StatelessWidget {
  const _Kepala({required this.onKembali});

  final VoidCallback onKembali;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Warna.momen,
      padding: EdgeInsets.fromLTRB(
        8,
        MediaQuery.of(context).padding.top,
        16,
        16,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Kembali',
            onPressed: onKembali,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Text(
            'Detail pesanan',
            style: TextStyle(
              fontSize: 16,
              height: 22 / 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// blok putih satu bagian, judulnya opsional
class _Blok extends StatelessWidget {
  const _Blok({required this.children, this.judul, this.kanan});

  final String? judul;
  final Widget? kanan;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (judul != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    judul!,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 22 / 16,
                      fontWeight: FontWeight.w700,
                      color: Warna.teks,
                    ),
                  ),
                ),
                ?kanan,
              ],
            ),
            const SizedBox(height: 12),
          ],
          ...children,
        ],
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

    return _Blok(
      children: [
        if (!batal) ...[_Tahapan(status: status), const SizedBox(height: 16)],
        switch (status) {
          StatusPesanan.menungguBayar => _KotakMenungguBayar(pesanan: pesanan),
          StatusPesanan.disiapkan ||
          StatusPesanan.siapDiambil => _KotakKode(pesanan: pesanan),
          StatusPesanan.dibatalkan => _KotakKeterangan(
            latar: Warna.merahLembut,
            warnaJudul: Warna.merah,
            judul: 'Pesanan dibatalkan',
            teks: pesanan['dibayarPada'] == null
                ? '${pesanan['alasan']} Tidak ada dana yang terpotong.'
                : '${pesanan['alasan']} Dana ${rupiah(pesanan['total'])} dikembalikan ke ${MetodeBayar.nama(pesanan['metode'])}.',
          ),
          StatusPesanan.tidakDiambil => _KotakKeterangan(
            latar: Warna.garis,
            warnaJudul: Warna.teks,
            judul: 'Tidak diambil',
            teks:
                'Pesanan tidak diambil sampai ${jam(pesanan['tutup'])}, jadi dana tidak dikembalikan.',
          ),
          _ => _KotakKeterangan(
            latar: Warna.softGreen,
            warnaJudul: Warna.hijau,
            judul: 'Pesanan sudah diambil',
            teks:
                '${pesanan['porsi']} porsi terselamatkan dari tempat sampah. Terima kasih!',
          ),
        },
        // kDebugMode: tombol ganti status cuma ada pas testing, gantiin aplikasi mitra
        if (kDebugMode &&
            (status == StatusPesanan.disiapkan ||
                status == StatusPesanan.siapDiambil)) ...[
          const SizedBox(height: 8),
          _ModeUji(pesanan: pesanan),
        ],
      ],
    );
  }
}

/// tiga lingkaran: Dibayar, Disiapkan, Siap diambil
class _Tahapan extends StatelessWidget {
  const _Tahapan({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    // tahap yg lagi berjalan, 3 = semuanya lewat
    final sekarang = switch (status) {
      StatusPesanan.menungguBayar => 0,
      StatusPesanan.disiapkan => 1,
      StatusPesanan.siapDiambil => 2,
      _ => 3,
    };
    final menunggu = status == StatusPesanan.menungguBayar;
    const nama = ['Dibayar', 'Disiapkan', 'Siap diambil'];
    final ikon = [
      menunggu ? Icons.schedule : Icons.check,
      Icons.inventory_2_outlined,
      Icons.qr_code_2,
    ];

    return Stack(
      children: [
        // garis penghubung di belakang lingkaran, sejajar titik tengahnya
        Positioned(
          left: 0,
          right: 0,
          top: 22 + 24 - 1,
          child: Row(
            children: [
              const Spacer(),
              for (var i = 0; i < 2; i++) ...[
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Container(
                      height: 2,
                      color: i + 1 <= sekarang ? Warna.hijau : Warna.garis,
                    ),
                  ),
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
        Row(
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Column(
                  children: [
                    Text(
                      nama[i],
                      style: TextStyle(
                        fontSize: 12,
                        height: 16 / 12,
                        letterSpacing: 0.1,
                        fontWeight: i == sekarang
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: i <= sekarang ? Warna.teks : Warna.teksPendukung,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _Lingkaran(
                      ikon: ikon[i],
                      lewat: i < sekarang,
                      aktif: i == sekarang,
                      mendesak: menunggu && i == 0,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Lingkaran extends StatelessWidget {
  const _Lingkaran({
    required this.ikon,
    required this.lewat,
    required this.aktif,
    required this.mendesak,
  });

  final IconData ikon;
  final bool lewat;
  final bool aktif;
  // tahap bayar yg belum dibayar, warnanya oren
  final bool mendesak;

  @override
  Widget build(BuildContext context) {
    final terisi = lewat || aktif;
    final warna = mendesak ? Warna.mendesak : Warna.hijau;

    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // halo muda cuma di tahap yg lagi berjalan
        color: aktif
            ? (mendesak ? Warna.mendesakLembut : Warna.softGreen)
            : Colors.white,
      ),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: terisi ? warna : Colors.white,
          border: terisi ? null : Border.all(color: Warna.garisKontrol),
        ),
        child: Icon(
          ikon,
          size: 18,
          color: terisi ? Colors.white : Warna.teksPendukung,
        ),
      ),
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
          _TombolBesar(
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
          _TombolBesar(
            ikon: Icons.qr_code_2,
            teks: 'Tampilkan QR',
            onPressed: () => context.push(Rute.kodeAmbil(pesanan['kode'])),
          ),
        ],
      ),
    );
  }
}

class _KotakKeterangan extends StatelessWidget {
  const _KotakKeterangan({
    required this.latar,
    required this.warnaJudul,
    required this.judul,
    required this.teks,
  });

  final Color latar;
  final Color warnaJudul;
  final String judul;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            judul,
            style: TextStyle(
              fontSize: 16,
              height: 22 / 16,
              fontWeight: FontWeight.w700,
              color: warnaJudul,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            teks,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              height: 16 / 12,
              letterSpacing: 0.1,
              fontWeight: FontWeight.w500,
              color: Warna.teksPendukung,
            ),
          ),
        ],
      ),
    );
  }
}

/// tombol utama hijau tua 52 tinggi, radius 16 (komponen Tombol di figma)
class _TombolBesar extends StatelessWidget {
  const _TombolBesar({required this.teks, required this.onPressed, this.ikon});

  final String teks;
  final VoidCallback onPressed;
  final IconData? ikon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Warna.hijau,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ikon != null) ...[
              Icon(ikon, size: 20),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                teks,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// pengganti aplikasi mitra selama testing: ubah tahapan pesanan (F-43, F-20)
class _ModeUji extends StatelessWidget {
  const _ModeUji({required this.pesanan});

  final Map<String, dynamic> pesanan;

  @override
  Widget build(BuildContext context) {
    final siap = pesanan['status'] == StatusPesanan.siapDiambil;
    return Center(
      child: TextButton.icon(
        onPressed: () => context.read<PesananBloc>().add(
          StatusPesananDiubah(
            pesanan['id'],
            siap ? StatusPesanan.selesai : StatusPesanan.siapDiambil,
          ),
        ),
        icon: const Icon(Icons.bug_report_outlined, size: 18),
        label: Text(
          siap
              ? 'Mode uji: tandai sudah diambil'
              : 'Mode uji: tandai siap diambil',
        ),
        style: TextButton.styleFrom(foregroundColor: Warna.teksPendukung),
      ),
    );
  }
}

class _BagianLokasi extends StatelessWidget {
  const _BagianLokasi({required this.pesanan});

  final Map<String, dynamic> pesanan;

  @override
  Widget build(BuildContext context) {
    return _Blok(
      judul: 'Lokasi pengambilan',
      children: [
        _BarisIkon(
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
        _BarisIkon(
          ikon: Icons.schedule,
          judul: 'Ambil sendiri',
          teks: 'Hari ini, ${jam(pesanan['mulai'])} – ${jam(pesanan['tutup'])}',
        ),
      ],
    );
  }
}

class _BarisIkon extends StatelessWidget {
  const _BarisIkon({
    required this.ikon,
    required this.judul,
    required this.teks,
    this.kanan,
  });

  final IconData ikon;
  final String judul;
  final String teks;
  final Widget? kanan;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Warna.softGreen,
            shape: BoxShape.circle,
          ),
          child: Icon(ikon, size: 20, color: Warna.hijau),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                judul,
                style: const TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  fontWeight: FontWeight.w700,
                  color: Warna.teks,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                teks,
                style: const TextStyle(
                  fontSize: 12,
                  height: 16 / 12,
                  letterSpacing: 0.1,
                  fontWeight: FontWeight.w500,
                  color: Warna.teksPendukung,
                ),
              ),
            ],
          ),
        ),
        ?kanan,
      ],
    );
  }
}

class _BagianIsi extends StatelessWidget {
  const _BagianIsi({required this.pesanan});

  final Map<String, dynamic> pesanan;

  @override
  Widget build(BuildContext context) {
    final List isi = pesanan['isi'];
    return _Blok(
      judul: 'Detail pesanan',
      kanan: Text(
        'Total item: ${pesanan['porsi']}',
        style: const TextStyle(
          fontSize: 12,
          letterSpacing: 0.1,
          fontWeight: FontWeight.w500,
          color: Warna.teksPendukung,
        ),
      ),
      children: [
        for (final item in isi) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  item['foto'] ?? pesanan['foto'],
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['nama'],
                      style: const TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        fontWeight: FontWeight.w600,
                        color: Warna.teks,
                      ),
                    ),
                    if (item['deskripsi'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item['deskripsi'],
                        style: const TextStyle(
                          fontSize: 12,
                          height: 16 / 12,
                          letterSpacing: 0.1,
                          fontWeight: FontWeight.w500,
                          color: Warna.teksPendukung,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    rupiah((item['harga'] as int) * (item['jumlah'] as int)),
                    style: const TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      fontWeight: FontWeight.w700,
                      color: Warna.teks,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item['jumlah']}×',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Warna.teksPendukung,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (item != isi.last) const SizedBox(height: 12),
        ],
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

    return _Blok(
      judul: 'Rincian pembayaran',
      children: [
        _BarisNilai(
          label: 'Harga normal',
          nilai: rupiah(pesanan['hargaNormal']),
        ),
        const SizedBox(height: 10),
        _BarisNilai(
          label: 'Kamu hemat',
          nilai: '−${rupiah(pesanan['hemat'])}',
          warnaNilai: Warna.hijau,
        ),
        if (biaya > 0) ...[
          const SizedBox(height: 10),
          _BarisNilai(label: 'Biaya layanan', nilai: rupiah(biaya)),
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
                  MetodeBayar.va => Icons.account_balance_outlined,
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

class _BarisNilai extends StatelessWidget {
  const _BarisNilai({
    required this.label,
    required this.nilai,
    this.warnaNilai = Warna.teks,
    this.kanan,
  });

  final String label;
  final String nilai;
  final Color warnaNilai;
  final Widget? kanan;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              height: 20 / 14,
              fontWeight: FontWeight.w500,
              color: Warna.teksPendukung,
            ),
          ),
        ),
        Text(
          nilai,
          style: TextStyle(
            fontSize: 14,
            height: 20 / 14,
            fontWeight: FontWeight.w600,
            color: warnaNilai,
          ),
        ),
        ?kanan,
      ],
    );
  }
}

class _BagianInfo extends StatelessWidget {
  const _BagianInfo({required this.pesanan});

  final Map<String, dynamic> pesanan;

  @override
  Widget build(BuildContext context) {
    final DateTime? dibayar = pesanan['dibayarPada'];
    final nomor = '#${pesanan['nomor']}';

    return _Blok(
      children: [
        _BarisNilai(
          label: 'ID pesanan',
          nilai: nomor,
          // salin nomor pesanan, berguna kalau perlu bantuan
          kanan: IconButton(
            tooltip: 'Salin ID pesanan',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: pesanan['nomor']));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ID pesanan disalin')),
              );
            },
            icon: const Icon(
              Icons.content_copy_outlined,
              size: 18,
              color: Warna.teks,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _BarisNilai(
          label: 'Waktu pembayaran',
          nilai: dibayar == null ? '—' : tanggalLengkap(dibayar),
        ),
        const SizedBox(height: 10),
        const _BarisNilai(label: 'Cara pemesanan', nilai: 'Ambil sendiri'),
      ],
    );
  }
}
