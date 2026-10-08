import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/bloc/pesanan_event.dart';
import 'package:sisa_rasa/cubit/akun_cubit.dart';
import 'package:sisa_rasa/data/pembayaran.dart';
import 'package:sisa_rasa/data/status_pesanan.dart';
import 'package:sisa_rasa/theme/teks.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';
import 'package:sisa_rasa/widgets/hitung_mundur.dart';
import 'package:sisa_rasa/widgets/navigasi_melayang.dart';

/// tab pesanan, disaring jadi berlangsung / selesai / dibatalkan (F-12)
class Pesanan extends StatefulWidget {
  const Pesanan({
    required this.onBukaKode,
    required this.onBayar,
    required this.onCariPaket,
    super.key,
  });

  final ValueChanged<Map<String, dynamic>> onBukaKode;
  // buka lagi halaman pembayaran buat pesanan yg belum dibayar
  final ValueChanged<Map<String, dynamic>> onBayar;
  final VoidCallback onCariPaket;

  @override
  State<Pesanan> createState() => _PesananState();
}

class _PesananState extends State<Pesanan> {
  static const _segmen = ['berlangsung', 'selesai', 'dibatalkan'];
  String segmen = 'berlangsung';

  @override
  Widget build(BuildContext context) {
    // ambil daftar pesanan dari PesananBloc, tiap ada perubahan status tab ini ikut update
    // cuma pesanan punya akun yg lagi dipake
    final daftarPesanan = PesananBloc.milik(
      context.watch<PesananBloc>().state,
      context.watch<AkunCubit>().state['id']!,
    );
    final berlangsung = [
      for (final p in daftarPesanan)
        if (StatusPesanan.berlangsung(p['status'])) p,
    ];
    final daftar = switch (segmen) {
      'berlangsung' => berlangsung,
      'selesai' => [
        for (final p in daftarPesanan)
          if (p['status'] == StatusPesanan.selesai ||
              p['status'] == StatusPesanan.tidakDiambil)
            p,
      ],
      _ => [
        for (final p in daftarPesanan)
          if (p['status'] == StatusPesanan.dibatalkan) p,
      ],
    };

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
          // segmen berlangsung / selesai / dibatalkan
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Warna.garis,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                for (final nama in _segmen)
                  Expanded(
                    // Semantics: dibaca pembaca layar sebagai tombol, plus tau mana yg kepilih
                    child: Semantics(
                      button: true,
                      selected: segmen == nama,
                      child: GestureDetector(
                        onTap: () => setState(() => segmen = nama),
                        child: Container(
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: segmen == nama
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            switch (nama) {
                              'berlangsung' =>
                                'Berlangsung · ${berlangsung.length}',
                              'selesai' => 'Selesai',
                              _ => 'Dibatalkan',
                            },
                            style: TextStyle(
                              fontSize: Teks.keterangan,
                              fontWeight: FontWeight.w700,
                              color: segmen == nama
                                  ? Warna.teks
                                  : Warna.teksPendukung,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // kalau segmen ini belum ada pesanannya
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
                    switch (segmen) {
                      'berlangsung' => 'Belum ada pesanan berlangsung',
                      'selesai' => 'Belum ada pesanan selesai',
                      _ => 'Tidak ada pesanan yang dibatalkan',
                    },
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
                  if (segmen == 'berlangsung') ...[
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
            switch (pesanan['status']) {
              StatusPesanan.menungguBayar => _kartuMenungguBayar(pesanan),
              StatusPesanan.dibatalkan => _kartuDibatalkan(pesanan),
              _ => _kartuAktif(pesanan),
            },
            const SizedBox(height: 12),
          ],
          if (segmen == 'berlangsung' && daftar.isNotEmpty)
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

  /// bagian atas kartu: foto, nama mitra, sama isi pesanan
  Widget _kepala(Map<String, dynamic> pesanan, {Widget? kanan}) {
    return Row(
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: Teks.tombol,
                  fontWeight: FontWeight.w700,
                ),
              ),
              // isi lebih dari satu paket: sisanya cukup disebut jumlahnya
              if ((pesanan['isi'] as List).length > 1)
                Text(
                  '+${(pesanan['isi'] as List).length - 1} paket lain',
                  style: const TextStyle(
                    fontSize: Teks.kecil,
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

  BoxDecoration get _kotakKartu => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  /// pesanan yg belum dibayar: hitung mundur sama tombol bayar (F-40)
  Widget _kartuMenungguBayar(Map<String, dynamic> pesanan) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _kotakKartu,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kepala(
            pesanan,
            kanan: _Pil(
              teks: StatusPesanan.label(StatusPesanan.menungguBayar),
              latar: Warna.mendesakLembut,
              warna: Warna.mendesak,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Warna.mendesakLembut,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                // Expanded + Wrap: teks hitung mundur turun baris kalau ga muat, ga meluber (NF-01)
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Bayar dalam ',
                        style: TextStyle(color: Warna.mendesak),
                      ),
                      // kalau waktunya abis pas tab ini lagi kebuka, pesanannya batal sendiri
                      HitungMundur(
                        batas: pesanan['batasBayar'],
                        onHabis: () => context.read<PesananBloc>().add(
                          PesananDibatalkan(
                            pesanan['id'],
                            alasan:
                                'Tidak dibayar dalam $menitBatasBayar menit.',
                          ),
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Warna.mendesak,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
            child: FilledButton(
              onPressed: () => widget.onBayar(pesanan),
              style: FilledButton.styleFrom(
                backgroundColor: Warna.hijau,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Bayar sekarang · ${MetodeBayar.nama(pesanan['metode'])}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// pesanan batal: alasan sama keterangan dana (F-12)
  Widget _kartuDibatalkan(Map<String, dynamic> pesanan) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _kotakKartu,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kepala(
            pesanan,
            kanan: _Pil(
              teks: StatusPesanan.label(StatusPesanan.dibatalkan),
              latar: Warna.garis,
              warna: Warna.teksPendukung,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            pesanan['alasan'] ?? '',
            style: const TextStyle(fontSize: Teks.keterangan),
          ),
          const SizedBox(height: 4),
          // yg bisa batal di versi ini cuma yg belum dibayar, jadi belum ada uang yg ditarik
          const Text(
            'Belum ada dana yang ditarik.',
            style: TextStyle(
              fontSize: Teks.keterangan,
              color: Warna.teksPendukung,
            ),
          ),
        ],
      ),
    );
  }

  /// pesanan yg udah dibayar, tinggal diambil
  Widget _kartuAktif(Map<String, dynamic> pesanan) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _kotakKartu,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kepala(pesanan),
          const SizedBox(height: 16),
          // langkah status: disiapkan -> siap diambil -> selesai (F-41)
          Row(
            children: [
              _LangkahStatus(
                nama: StatusPesanan.label(StatusPesanan.disiapkan),
                waktu: jam(pesanan['dibayar'] ?? pesanan['dipesan']),
                status: 'lewat',
              ),
              _LangkahStatus(
                nama: StatusPesanan.label(StatusPesanan.siapDiambil),
                waktu: jam(pesanan['mulai']),
                status: 'berikutnya',
              ),
              _LangkahStatus(
                nama: StatusPesanan.label(StatusPesanan.selesai),
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
    );
  }
}

/// label status kecil di pojok kanan kartu
class _Pil extends StatelessWidget {
  const _Pil({required this.teks, required this.latar, required this.warna});

  final String teks;
  final Color latar;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        teks,
        style: TextStyle(
          fontSize: Teks.kecil,
          fontWeight: FontWeight.w700,
          color: warna,
        ),
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
