import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sisa_rasa/data/status_pesanan.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';

// bagian-bagian detail pesanan yg dipake bareng layar pembeli sama layar mitra

/// kepala hijau tua di atas detail pesanan: tombol kembali + judul
class KepalaHijau extends StatelessWidget {
  const KepalaHijau({required this.judul, required this.onKembali, super.key});

  final String judul;
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
          Text(
            judul,
            style: const TextStyle(
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
class BlokPutih extends StatelessWidget {
  const BlokPutih({required this.children, this.judul, this.kanan, super.key});

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

/// tiga lingkaran: Dibayar, Disiapkan, Siap diambil
class TahapanPesanan extends StatelessWidget {
  const TahapanPesanan({required this.status, super.key});

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

class KotakKeterangan extends StatelessWidget {
  const KotakKeterangan({
    required this.latar,
    required this.warnaJudul,
    required this.judul,
    required this.teks,
    super.key,
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
class TombolBesar extends StatelessWidget {
  const TombolBesar({
    required this.teks,
    required this.onPressed,
    this.ikon,
    super.key,
  });

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

class BarisIkon extends StatelessWidget {
  const BarisIkon({
    required this.ikon,
    required this.judul,
    required this.teks,
    this.kanan,
    super.key,
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

class BagianIsiPesanan extends StatelessWidget {
  const BagianIsiPesanan({required this.pesanan, super.key});

  final Map<String, dynamic> pesanan;

  @override
  Widget build(BuildContext context) {
    final List isi = pesanan['isi'];
    return BlokPutih(
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

class BarisNilai extends StatelessWidget {
  const BarisNilai({
    required this.label,
    required this.nilai,
    this.warnaNilai = Warna.teks,
    this.kanan,
    super.key,
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

class BagianInfoPesanan extends StatelessWidget {
  const BagianInfoPesanan({required this.pesanan, super.key});

  final Map<String, dynamic> pesanan;

  @override
  Widget build(BuildContext context) {
    final DateTime? dibayar = pesanan['dibayarPada'];
    final nomor = '#${pesanan['nomor']}';

    return BlokPutih(
      children: [
        BarisNilai(
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
        BarisNilai(
          label: 'Waktu pembayaran',
          nilai: dibayar == null ? '—' : tanggalLengkap(dibayar),
        ),
        const SizedBox(height: 10),
        const BarisNilai(label: 'Cara pemesanan', nilai: 'Ambil sendiri'),
      ],
    );
  }
}
