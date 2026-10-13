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

    // Scaffold: kerangka halaman kode ambil, latarnya ijo
    return Scaffold(
      backgroundColor: Warna.momen,
      // SafeArea: biar ga ketutup status bar
      body: SafeArea(
        // SingleChildScrollView: bisa di scroll kalau hp nya pendek
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          // Column: isi halaman disusun ke bawah
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Align: naruh child di posisi tertentu, di sini kanan
              Align(
                alignment: Alignment.centerRight,
                // Navigator.pop ngirim false, berarti ga pindah tab
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  // tulisan selesai
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
              // Row: icon centang + judul
              Row(
                children: [
                  // icon centang
                  const Icon(Icons.check_circle, color: Colors.white, size: 30),
                  // jarak
                  const SizedBox(width: 10),
                  // Expanded biar judulnya ga overflow
                  Expanded(
                    // judul, beda kalau pesanan baru
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
              // jarak
              const SizedBox(height: 8),
              // petunjuk tunjukin kode ke kasir
              Text(
                'Tunjukkan kode ini di kasir ${pesanan['mitra']} saat jam ambil. Bayar di tempat.',
                style: const TextStyle(
                  fontSize: Teks.isi,
                  height: 1.45,
                  color: Colors.white,
                ),
              ),
              // jarak
              const SizedBox(height: 20),

              // Stack: tiket putih di belakang, 2 lingkaran ijo di pinggir biar keliatan kayak sobekan
              Stack(
                children: [
                  // Container: tiket putih
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
                    // Column: bagian qr, garis sobekan, rincian
                    child: Column(
                      children: [
                        // SizedBox: tinggi bagian atas tiket, dipake buat posisi bolong
                        SizedBox(
                          height: tinggiAtas,
                          // Column: qr + kode di tengah
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // QrImageView: qr asli, isinya kode ambil jadi bisa di scan kasir
                              QrImageView(
                                data: pesanan['kode'],
                                size: 150,
                                backgroundColor: Colors.white,
                              ),
                              // jarak
                              const SizedBox(height: 8),
                              // kode ambil
                              Text(
                                pesanan['kode'],
                                style: const TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: Teks.kode,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 3,
                                ),
                              ),
                              // keterangan kode
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
                          // Row: titik2 garis sobekan
                          child: Row(
                            children: [
                              for (var i = 0; i < 30; i++)
                                // Expanded: tiap potongan garis lebarnya sama
                                Expanded(
                                  // Container: satu potongan garis
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
                        // Padding: jarak rincian pesanan
                        Padding(
                          padding: const EdgeInsets.all(20),
                          // Column: baris2 rincian
                          child: Column(
                            children: [
                              // baris rincian mitra
                              _BarisRincian(
                                label: 'Mitra',
                                nilai: pesanan['mitra'],
                              ),
                              // baris rincian jam ambil
                              _BarisRincian(
                                label: 'Ambil',
                                nilai:
                                    'Hari ini, ${jam(pesanan['mulai'])}–${jam(pesanan['tutup'])}',
                              ),
                              // baris rincian isi pesanan
                              _BarisRincian(
                                label: 'Isi',
                                nilai: isi
                                    .map(
                                      (item) =>
                                          '${item['jumlah']} × ${item['nama']}',
                                    )
                                    .join('\n'),
                              ),
                              // jarak
                              const SizedBox(height: 4),
                              // Row: total bayar
                              Row(
                                children: [
                                  // Expanded: dorong total ke kanan
                                  const Expanded(
                                    // label bayar
                                    child: Text(
                                      'Bayar di tempat',
                                      style: TextStyle(
                                        color: Warna.teksPendukung,
                                      ),
                                    ),
                                  ),
                                  // total bayar
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
                    // CircleAvatar: bulet warna latar, keliatan kayak bolong
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Warna.momen,
                    ),
                  ),
                  // Positioned: bolong kanan
                  const Positioned(
                    right: -12,
                    top: tinggiAtas - 11,
                    // bulet bolong kanan
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Warna.momen,
                    ),
                  ),
                ],
              ),
              // jarak
              const SizedBox(height: 16),
              // Row: icon daun + info porsi
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // icon daun
                  const Icon(Icons.eco_outlined, color: Colors.white),
                  // jarak
                  const SizedBox(width: 10),
                  // Expanded biar tulisannya turun baris
                  Expanded(
                    // info porsi ke berapa yg diselamatin
                    child: Text(
                      'Porsi ke-${1283 + (pesanan['porsi'] as int)} yang diselamatkan di Samarinda bulan ini.',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
              // jarak
              const SizedBox(height: 20),
              // SizedBox: tombol selebar layar
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
                  // tulisan tombol
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
    // Padding: jarak antar baris rincian
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      // Row: label kiri, nilai kanan
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SizedBox: lebar kolom label
          SizedBox(
            width: 72,
            // label rincian
            child: Text(
              label,
              style: const TextStyle(color: Warna.teksPendukung),
            ),
          ),
          // Expanded: nilai ngisi sisa lebar
          Expanded(
            // nilai rincian
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
