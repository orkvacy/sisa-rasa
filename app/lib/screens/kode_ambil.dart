import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sisa_rasa/theme/teks.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';

/// halaman kode ambil, satu2nya layar yg full ijo
class KodeAmbil extends StatelessWidget {
  const KodeAmbil({required this.pesanan, this.pesananBaru = false, super.key});

  final Map<String, dynamic> pesanan;
  final bool pesananBaru;

  // tinggi bagian qr + kode, dipake juga buat posisi bolong sobekan tiketnya
  static const double tinggiAtas = 262;

  @override
  Widget build(BuildContext context) {
    final List isi = pesanan['isi'];

    return Scaffold(
      backgroundColor: Warna.momen,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Align: naruh child di posisi tertentu, di sini kanan
              Align(
                alignment: Alignment.centerRight,
                // Navigator.pop ngirim false, berarti ga pindah tab
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'Selesai',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: Teks.tombol,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      pesananBaru ? 'Pesanan dibuat' : 'Kode ambil',
                      style: const TextStyle(
                        fontSize: Teks.judul,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Tunjukkan kode ini di kasir ${pesanan['mitra']} saat jam ambil. Bayar di tempat.',
                style: const TextStyle(
                  fontSize: Teks.isi,
                  height: 1.45,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // Stack: tiket putih di belakang, 2 lingkaran ijo di pinggir biar keliatan kayak sobekan
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      // BoxShadow: biar tiketnya keliatan keangkat dari latar ijo
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: tinggiAtas,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // QrImageView: qr asli, isinya kode ambil jadi bisa di scan kasir
                              QrImageView(
                                data: pesanan['kode'],
                                size: 150,
                                backgroundColor: Colors.white,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                pesanan['kode'],
                                style: const TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: Teks.kode,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 3,
                                ),
                              ),
                              const Text(
                                'Atau sebutkan kode ini ke kasir',
                                style: TextStyle(
                                  fontSize: Teks.keterangan,
                                  color: Warna.teksPendukung,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // garis putus2 tempat sobekan
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              for (var i = 0; i < 30; i++)
                                Expanded(
                                  child: Container(
                                    height: 1.5,
                                    color: i.isEven
                                        ? Warna.garisKontrol
                                        : Colors.transparent,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              _BarisRincian(
                                label: 'Mitra',
                                nilai: pesanan['mitra'],
                              ),
                              _BarisRincian(
                                label: 'Ambil',
                                nilai:
                                    'Hari ini, ${jam(pesanan['mulai'])}–${jam(pesanan['tutup'])}',
                              ),
                              _BarisRincian(
                                label: 'Isi',
                                nilai: isi
                                    .map(
                                      (item) =>
                                          '${item['jumlah']} × ${item['nama']}',
                                    )
                                    .join('\n'),
                              ),
                              const SizedBox(height: 4),
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
                                    rupiah(pesanan['total']),
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
                  ),
                  // Positioned: bolong kiri, tengahnya pas di garis sobekan
                  const Positioned(
                    left: -12,
                    top: tinggiAtas - 11,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Warna.momen,
                    ),
                  ),
                  // Positioned: bolong kanan
                  const Positioned(
                    right: -12,
                    top: tinggiAtas - 11,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Warna.momen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.eco_outlined, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Porsi ke-${1283 + (pesanan['porsi'] as int)} yang diselamatkan di Samarinda bulan ini.',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                // Navigator.pop ngirim true, halaman utama pindah ke tab pesanan
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Warna.hijau,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Lihat pesanan saya',
                    style: TextStyle(
                      fontSize: Teks.tombol,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// satu baris rincian di tiket, label kiri nilai kanan
class _BarisRincian extends StatelessWidget {
  const _BarisRincian({required this.label, required this.nilai});

  final String label;
  final String nilai;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(color: Warna.teksPendukung),
            ),
          ),
          Expanded(
            child: Text(
              nilai,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
