import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/core/theme/warna.dart';
import 'package:sisa_rasa/domain/aturan/pembayaran.dart';

/// ketentuan dan kebijakan privasi (figma v3: umum/ketentuan dan privasi, F-65).
/// dibuka dari form daftar dan menu Akun
class Ketentuan extends StatelessWidget {
  const Ketentuan({super.key});

  static const _bagian = [
    (
      'Pesanan dan pembayaran',
      'Pesanan dibayar di aplikasi lewat QRIS, GoPay, atau Virtual Account. '
          'Harga yang tampil adalah harga final dari mitra, ditambah biaya layanan '
          '$persenBiayaLayanan% dari harga pesanan. Pesanan yang tidak dibayar dalam '
          '$menitBatasBayar menit batal otomatis. Bila mitra membatalkan pesanan, '
          'dana kembali penuh ke metode bayar semula.',
    ),
    (
      'Pengambilan',
      'Pesanan diambil sendiri di tempat mitra sebelum jam tutup ambil dengan '
          'menunjukkan kode ambil. Pesanan yang tidak diambil sampai jam tutup '
          'dianggap selesai dan dananya tidak dikembalikan.',
    ),
    (
      'Keamanan pangan',
      'Mitra hanya boleh menawarkan makanan yang dimasak hari itu dan wajib '
          'menyimpannya sesuai standar. Isi paket dan alergen ditulis oleh mitra. '
          'Admin dapat menonaktifkan mitra atau paket yang melanggar.',
    ),
    (
      'Data yang kami simpan',
      'Nama, email, foto profil, dan riwayat pesanan. Kata sandi disimpan sebagai '
          'hash dan tidak bisa dibaca siapa pun, termasuk kami. Data pembayaran '
          'diproses oleh penyedia pembayaran dan tidak disimpan di Sisa Rasa.',
    ),
    (
      'Menghapus akun',
      'Kamu bisa menghapus akun kapan saja dari Akun › Hapus akun. Data dihapus '
          'permanen dalam 30 hari, kecuali catatan transaksi yang wajib disimpan '
          'untuk pembukuan.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Warna.latar,
      appBar: AppBar(
        backgroundColor: Warna.latar,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Kembali',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        title: const Text(
          'Ketentuan & privasi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Warna.teks,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const Text(
            'Berlaku sejak 1 Oktober 2026',
            style: TextStyle(fontSize: 13, color: Warna.teksPendukung),
          ),
          for (final (i, (judul, isi)) in _bagian.indexed) ...[
            const SizedBox(height: 18),
            Text(
              '${i + 1}. $judul',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Warna.teks,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isi,
              style: const TextStyle(
                fontSize: 15,
                height: 24 / 15,
                color: Warna.teksPendukung,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
