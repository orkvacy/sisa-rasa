import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/theme/teks.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';
import 'package:sisa_rasa/widgets/navigasi_melayang.dart';

/// tab pesanan, isinya pesanan aktif sama yg udah selesai
class Pesanan extends StatefulWidget {
  const Pesanan({
    required this.onBukaKode,
    required this.onCariPaket,
    super.key,
  });

  final ValueChanged<Map<String, dynamic>> onBukaKode;
  final VoidCallback onCariPaket;

  @override
  State<Pesanan> createState() => _PesananState();
}

class _PesananState extends State<Pesanan> {
  bool tabAktif = true;

  @override
  Widget build(BuildContext context) {
    // ambil daftar pesanan dari PesananBloc, tiap ada pesanan baru tab ini ikut update
    final daftarPesanan = context.watch<PesananBloc>().state;
    // semua pesanan di versi ini masih nunggu diambil, jadi masuknya ke aktif
    final daftar = tabAktif ? daftarPesanan : <Map<String, dynamic>>[];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          NavigasiMelayang.ruangBawah,
        ),
        children: [
          const Text(
            'Pesanan',
            style: TextStyle(fontSize: Teks.judul, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          // segmen aktif / selesai
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Warna.garis,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                for (final aktif in [true, false])
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => tabAktif = aktif),
                      child: Container(
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tabAktif == aktif
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          aktif ? 'Aktif · ${daftarPesanan.length}' : 'Selesai',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: tabAktif == aktif
                                ? Warna.teks
                                : Warna.teksPendukung,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // kalau belum ada pesanan
          if (daftar.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Column(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 56,
                    color: Warna.teksPendukung,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tabAktif
                        ? 'Belum ada pesanan aktif'
                        : 'Belum ada pesanan selesai',
                    style: const TextStyle(
                      fontSize: Teks.nama,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pesanan yang kamu buat akan muncul di sini beserta kode ambilnya.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Warna.teksPendukung),
                  ),
                  if (tabAktif) ...[
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: widget.onCariPaket,
                      child: const Text('Cari paket'),
                    ),
                  ],
                ],
              ),
            ),

          for (final pesanan in daftar) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          pesanan['foto'],
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pesanan['mitra'],
                              style: const TextStyle(
                                fontSize: Teks.keterangan,
                                color: Warna.teksPendukung,
                              ),
                            ),
                            Text(
                              '${pesanan['isi'][0]['jumlah']} × ${pesanan['isi'][0]['nama']}',
                              style: const TextStyle(
                                fontSize: Teks.tombol,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // langkah status: dipesan -> siap diambil -> selesai
                  Row(
                    children: [
                      _LangkahStatus(
                        nama: 'Dipesan',
                        waktu: jam(pesanan['dipesan']),
                        status: 'lewat',
                      ),
                      _LangkahStatus(
                        nama: 'Siap diambil',
                        waktu: jam(pesanan['mulai']),
                        status: 'berikutnya',
                      ),
                      const _LangkahStatus(
                        nama: 'Selesai',
                        waktu: '—',
                        status: 'belum',
                        terakhir: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Warna.latar,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pesanan['kode'],
                                style: const TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: Teks.kodeKecil,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                // kalau jam ambilnya udah mulai, yg ditampilin sisa waktu sampe tutup
                                sudahBuka(pesanan)
                                    ? '${jam(pesanan['mulai'])}–${jam(pesanan['tutup'])} · tutup ${sisaWaktu(pesanan['tutup'])} lagi'
                                    : '${jam(pesanan['mulai'])}–${jam(pesanan['tutup'])} · buka ${sisaWaktu(pesanan['mulai'])} lagi',
                                style: const TextStyle(
                                  fontSize: Teks.kecil,
                                  fontWeight: FontWeight.w600,
                                  color: Warna.mendesak,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          rupiah(pesanan['total']),
                          style: const TextStyle(
                            fontSize: Teks.nama,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    // buka lagi halaman kode ambil
                    child: FilledButton.icon(
                      onPressed: () => widget.onBukaKode(pesanan),
                      style: FilledButton.styleFrom(
                        backgroundColor: Warna.hijau,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text(
                        'Tampilkan kode',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (tabAktif && daftar.isNotEmpty)
            const Text(
              'Pesanan yang sudah diambil pindah ke Selesai.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: Teks.keterangan,
                color: Warna.teksPendukung,
              ),
            ),
        ],
      ),
    );
  }
}

/// satu langkah status: titik, garis ke langkah berikutnya, sama labelnya
class _LangkahStatus extends StatelessWidget {
  const _LangkahStatus({
    required this.nama,
    required this.waktu,
    required this.status,
    this.terakhir = false,
  });

  final String nama;
  final String waktu;
  // 'lewat', 'berikutnya', atau 'belum'
  final String status;
  final bool terakhir;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: status == 'lewat' ? Warna.hijau : Colors.white,
                  border: Border.all(
                    color: status == 'belum' ? Warna.garisKontrol : Warna.hijau,
                    width: 2,
                  ),
                ),
                child: status == 'lewat'
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              if (!terakhir)
                Expanded(
                  child: Container(
                    height: 2,
                    color: status == 'lewat' ? Warna.hijau : Warna.garis,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            nama,
            style: TextStyle(
              fontSize: Teks.kecil,
              fontWeight: FontWeight.w700,
              color: status == 'belum' ? Warna.teksPendukung : Warna.teks,
            ),
          ),
          Text(
            waktu,
            style: const TextStyle(
              fontSize: Teks.kecil,
              color: Warna.teksPendukung,
            ),
          ),
        ],
      ),
    );
  }
}
