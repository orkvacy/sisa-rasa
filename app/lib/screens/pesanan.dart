import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/theme/teks.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';

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

    // SafeArea: biar ga ketutup status bar
    return SafeArea(
      // ListView: daftar pesanan bisa di scroll
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // judul halaman
          const Text(
            'Pesanan',
            style: TextStyle(fontSize: Teks.judul, fontWeight: FontWeight.w800),
          ),
          // jarak
          const SizedBox(height: 16),
          // segmen aktif / selesai
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Warna.garis,
              borderRadius: BorderRadius.circular(14),
            ),
            // Row: dua tombol segmen sebelahan
            child: Row(
              children: [
                for (final aktif in [true, false])
                  // Expanded: lebar segmen dibagi rata
                  Expanded(
                    // GestureDetector: segmen bisa dipencet
                    child: GestureDetector(
                      onTap: () => setState(() => tabAktif = aktif),
                      // Container: bentuk segmen, warnanya ganti kalau aktif
                      child: Container(
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tabAktif == aktif
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        // nama segmen
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
          // jarak
          const SizedBox(height: 16),

          // kalau belum ada pesanan
          if (daftar.isEmpty)
            // Padding: jarak atas isi kosong
            Padding(
              padding: const EdgeInsets.only(top: 48),
              // Column: icon, tulisan, tombol disusun ke bawah
              child: Column(
                children: [
                  // icon struk
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 56,
                    color: Warna.teksPendukung,
                  ),
                  // jarak
                  const SizedBox(height: 12),
                  // pesan kalau belum ada pesanan
                  Text(
                    tabAktif
                        ? 'Belum ada pesanan aktif'
                        : 'Belum ada pesanan selesai',
                    style: const TextStyle(
                      fontSize: Teks.nama,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  // jarak
                  const SizedBox(height: 4),
                  // keterangan pesanan nanti muncul di sini
                  const Text(
                    'Pesanan yang kamu buat akan muncul di sini beserta kode ambilnya.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Warna.teksPendukung),
                  ),
                  if (tabAktif) ...[
                    // jarak
                    const SizedBox(height: 16),
                    // OutlinedButton: pindah ke beranda
                    OutlinedButton(
                      onPressed: widget.onCariPaket,
                      // tulisan tombol
                      child: const Text('Cari paket'),
                    ),
                  ],
                ],
              ),
            ),

          for (final pesanan in daftar) ...[
            // Container: kartu satu pesanan
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
              // Column: isi kartu pesanan
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row: foto + info mitra
                  Row(
                    children: [
                      // ClipRRect: sudut foto dibikin bulet
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        // Image.asset: foto paket
                        child: Image.asset(
                          pesanan['foto'],
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                        ),
                      ),
                      // jarak
                      const SizedBox(width: 12),
                      // Expanded: info ngisi sisa lebar
                      Expanded(
                        // Column: nama mitra + isi pesanan
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // nama mitra
                            Text(
                              pesanan['mitra'],
                              style: const TextStyle(
                                fontSize: Teks.keterangan,
                                color: Warna.teksPendukung,
                              ),
                            ),
                            // isi pesanan
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
                  // jarak
                  const SizedBox(height: 16),
                  // langkah status: dipesan -> siap diambil -> selesai
                  Row(
                    children: [
                      // langkah 1: dipesan
                      _LangkahStatus(
                        nama: 'Dipesan',
                        waktu: jam(pesanan['dipesan']),
                        status: 'lewat',
                      ),
                      // langkah 2: siap diambil
                      _LangkahStatus(
                        nama: 'Siap diambil',
                        waktu: jam(pesanan['mulai']),
                        status: 'berikutnya',
                      ),
                      // langkah 3: selesai
                      const _LangkahStatus(
                        nama: 'Selesai',
                        waktu: '—',
                        status: 'belum',
                        terakhir: true,
                      ),
                    ],
                  ),
                  // jarak
                  const SizedBox(height: 14),
                  // Container: kotak kode + total
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Warna.latar,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    // Row: kode kiri, total kanan
                    child: Row(
                      children: [
                        // Expanded: dorong total ke kanan
                        Expanded(
                          // Column: kode + sisa waktu
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // kode ambil
                              Text(
                                pesanan['kode'],
                                style: const TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: Teks.kodeKecil,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              // sisa waktu ambil
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
                        // total bayar
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
                  // jarak
                  const SizedBox(height: 14),
                  // SizedBox: tombol selebar kartu
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
                      // icon qr
                      icon: const Icon(Icons.qr_code_2),
                      // tulisan tombol
                      label: const Text(
                        'Tampilkan kode',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // jarak antar kartu
            const SizedBox(height: 12),
          ],
          if (tabAktif && daftar.isNotEmpty)
            // catatan pesanan selesai
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
    // Expanded: tiap langkah lebarnya sama
    return Expanded(
      // Column: titik + nama + waktu
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: titik + garis ke langkah berikutnya
          Row(
            children: [
              // Container: titik bulet langkah
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
                    // icon centang kalau udah lewat
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              if (!terakhir)
                // Expanded: garis ngisi sisa lebar
                Expanded(
                  // Container: garis penghubung
                  child: Container(
                    height: 2,
                    color: status == 'lewat' ? Warna.hijau : Warna.garis,
                  ),
                ),
            ],
          ),
          // jarak
          const SizedBox(height: 6),
          // nama langkah
          Text(
            nama,
            style: TextStyle(
              fontSize: Teks.kecil,
              fontWeight: FontWeight.w700,
              color: status == 'belum' ? Warna.teksPendukung : Warna.teks,
            ),
          ),
          // waktu langkah
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
