import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/core/theme/teks.dart';
import 'package:sisa_rasa/core/theme/warna.dart';
import 'package:sisa_rasa/core/utils/format.dart';
import 'package:sisa_rasa/presentation/cubit/akun_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/paket_cubit.dart';

/// Layar 9a: Informasi Profil Usaha Mitra (SRS F-64).
/// Menampilkan informasi gerai mitra terdaftar secara read-only (F-64).
class ProfilUsaha extends StatelessWidget {
  const ProfilUsaha({super.key});

  @override
  Widget build(BuildContext context) {
    final akun = context.watch<AkunCubit>().state;
    final nama = akun['nama'] ?? 'Mitra Usaha';
    final paket = context.watch<PaketCubit>().state;
    final dataMitra = paket.where((p) => p['mitra'] == nama).firstOrNull;

    final jenis = dataMitra?['jenisMitra'] ?? 'Restoran';
    final alamat = dataMitra?['alamat'] ?? 'Samarinda';
    // jam ambil paket hari ini, disimpan dalam menit (17 * 60 = 17.00)
    final buka = dataMitra?['mulai'] is int ? jam(dataMitra!['mulai']) : '-';
    final tutup = dataMitra?['tutup'] is int ? jam(dataMitra!['tutup']) : '-';

    return Scaffold(
      backgroundColor: Warna.latar,
      appBar: AppBar(
        backgroundColor: Warna.latar,
        title: const Text(
          'Profil Usaha',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Kartu Ringkasan Gerai
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Warna.garis),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Warna.softGreen,
                    child: Icon(Icons.storefront, color: Warna.hijau, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nama,
                          style: const TextStyle(
                            fontSize: Teks.nama,
                            fontWeight: FontWeight.w800,
                            color: Warna.teks,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Kategori: $jenis',
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
            ),
            const SizedBox(height: 20),

            const Text(
              'Informasi Gerai',
              style: TextStyle(
                fontSize: Teks.keterangan,
                fontWeight: FontWeight.w700,
                color: Warna.teksPendukung,
              ),
            ),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Warna.garis),
              ),
              child: Column(
                children: [
                  _InfoItem(
                    ikon: Icons.business_outlined,
                    label: 'Nama Usaha / Gerai',
                    nilai: nama,
                  ),
                  const Divider(height: 1, indent: 52, color: Warna.garis),
                  _InfoItem(
                    ikon: Icons.category_outlined,
                    label: 'Jenis Usaha',
                    nilai: jenis,
                  ),
                  const Divider(height: 1, indent: 52, color: Warna.garis),
                  _InfoItem(
                    ikon: Icons.place_outlined,
                    label: 'Alamat Gerai',
                    nilai: alamat,
                  ),
                  const Divider(height: 1, indent: 52, color: Warna.garis),
                  _InfoItem(
                    ikon: Icons.access_time_outlined,
                    label: 'Jam Pengambilan Paket',
                    nilai: '$buka - $tutup',
                  ),
                  const Divider(height: 1, indent: 52, color: Warna.garis),
                  const _InfoItem(
                    ikon: Icons.verified_outlined,
                    label: 'Status Kemitraan',
                    nilai: 'Terverifikasi Aktif',
                    nilaiColor: Warna.hijau,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Catatan info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Warna.softGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 20, color: Warna.hijau),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Nama usaha dan data gerai dicocokkan dengan katalog paket serta rekening mitra. Untuk pengajuan perubahan data, hubungi tim operasional Sisa Rasa.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Warna.hijau,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.ikon,
    required this.label,
    required this.nilai,
    this.nilaiColor,
  });

  final IconData ikon;
  final String label;
  final String nilai;
  final Color? nilaiColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: 20, color: Warna.teksPendukung),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: Teks.kecil,
                    color: Warna.teksPendukung,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  nilai,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: nilaiColor ?? Warna.teks,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
