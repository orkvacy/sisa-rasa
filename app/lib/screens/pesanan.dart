import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/bloc/pesanan_event.dart';
import 'package:sisa_rasa/cubit/akun_cubit.dart';
import 'package:sisa_rasa/data/pembayaran.dart';
import 'package:sisa_rasa/data/status_pesanan.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/aksi_mitra.dart';
import 'package:sisa_rasa/utils/format.dart';
import 'package:sisa_rasa/widgets/hitung_mundur.dart';
import 'package:sisa_rasa/widgets/navigasi_melayang.dart';
import 'package:sisa_rasa/widgets/pil_status.dart';

/// tab pesanan (figma v3), disaring jadi berlangsung / selesai / dibatalkan (F-12)
class Pesanan extends StatefulWidget {
  const Pesanan({
    required this.onBukaDetail,
    required this.onBukaKode,
    required this.onBayar,
    required this.onCariPaket,
    super.key,
  });

  final ValueChanged<Map<String, dynamic>> onBukaDetail;
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
    // cuma pesanan punya akun yg lagi dipake, tiap ada perubahan status tab ini ikut update
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

    // selesai sama dibatalkan dikelompokin per tanggal (Hari ini, Kemarin, ...)
    final isi = <Widget>[];
    String? kelompokTerakhir;
    for (final pesanan in daftar) {
      if (segmen != 'berlangsung') {
        final kelompok = kelompokTanggal(_waktuAkhir(pesanan));
        if (kelompok != kelompokTerakhir) {
          isi.add(_JudulKelompok(kelompok));
          kelompokTerakhir = kelompok;
        }
      }
      isi
        ..add(_kartu(pesanan))
        ..add(const SizedBox(height: 12));
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          NavigasiMelayang.ruangBawah,
        ),
        children: [
          const Text(
            'Pesanan',
            style: TextStyle(
              fontSize: 28,
              height: 34 / 28,
              letterSpacing: -0.4,
              fontWeight: FontWeight.w800,
              color: Warna.teks,
            ),
          ),
          const SizedBox(height: 24),
          _SaringStatus(
            pilihan: _segmen,
            aktif: segmen,
            jumlahBerlangsung: berlangsung.length,
            onPilih: (nama) => setState(() => segmen = nama),
          ),
          const SizedBox(height: 12),
          if (daftar.isEmpty) _kosong() else ...isi,
        ],
      ),
    );
  }

  /// kapan pesanan ini terakhir berubah, dipake buat ngelompokin
  DateTime _waktuAkhir(Map<String, dynamic> pesanan) =>
      pesanan['diambilPada'] ??
      pesanan['dibatalkanPada'] ??
      pesanan['dibayarPada'] ??
      pesanan['dibuat'];

  Widget _kosong() {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 56,
            color: Warna.teksPendukung,
          ),
          const SizedBox(height: 12),
          Text(switch (segmen) {
            'berlangsung' => 'Belum ada pesanan berlangsung',
            'selesai' => 'Belum ada pesanan selesai',
            _ => 'Tidak ada pesanan yang dibatalkan',
          }, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
    );
  }

  Widget _kartu(Map<String, dynamic> pesanan) {
    final String status = pesanan['status'];
    final List isi = pesanan['isi'];

    final keterangan = switch (status) {
      StatusPesanan.selesai =>
        'Diambil ${tanggalSingkat(_waktuAkhir(pesanan))}',
      StatusPesanan.tidakDiambil =>
        'Tidak diambil sampai ${jam(pesanan['tutup'])}',
      StatusPesanan.dibatalkan =>
        '${pesanan['otomatis'] == true ? 'Batal otomatis' : 'Dibatalkan'} ${tanggalSingkat(_waktuAkhir(pesanan))}',
      _ => 'Hari ini, ${jam(pesanan['mulai'])} – ${jam(pesanan['tutup'])}',
    };

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Warna.garis),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => widget.onBukaDetail(pesanan),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // atas: nama mitra + pil status
              Row(
                children: [
                  const Icon(
                    Icons.storefront_outlined,
                    size: 18,
                    color: Warna.teks,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pesanan['mitra'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 20 / 13,
                        fontWeight: FontWeight.w700,
                        color: Warna.teks,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PilStatus(status: status),
                ],
              ),
              const SizedBox(height: 12),
              // isi: foto, paket, keterangan waktu, total
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      pesanan['foto'],
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${isi[0]['jumlah']}× ${isi[0]['nama']}'
                          '${isi.length > 1 ? ' +${isi.length - 1} lainnya' : ''}',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 20 / 13,
                            fontWeight: FontWeight.w600,
                            color: Warna.teks,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          keterangan,
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
                  const SizedBox(width: 12),
                  Text(
                    rupiah(pesanan['total']),
                    style: const TextStyle(
                      fontSize: 13,
                      height: 20 / 13,
                      fontWeight: FontWeight.w700,
                      color: Warna.teks,
                    ),
                  ),
                ],
              ),
              ...switch (status) {
                StatusPesanan.menungguBayar => _bawahMenungguBayar(pesanan),
                StatusPesanan.disiapkan ||
                StatusPesanan.siapDiambil => _bawahAktif(pesanan),
                StatusPesanan.dibatalkan => _bawahDibatalkan(pesanan),
                _ => _bawahSelesai(pesanan),
              },
            ],
          ),
        ),
      ),
    );
  }

  /// belum dibayar: hitung mundur batas bayar (F-40) sama tombol bayar
  List<Widget> _bawahMenungguBayar(Map<String, dynamic> pesanan) {
    const gaya = TextStyle(
      fontSize: 12,
      height: 16 / 12,
      letterSpacing: 0.1,
      fontWeight: FontWeight.w600,
      color: Warna.mendesak,
    );
    return [
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.schedule, size: 16, color: Warna.mendesak),
          const SizedBox(width: 6),
          // Expanded + Wrap: turun baris kalau layarnya sempit (NF-01)
          Expanded(
            child: Wrap(
              children: [
                const Text('Bayar dalam ', style: gaya),
                // kalau waktunya abis pas tab ini lagi kebuka, pesanannya batal sendiri
                HitungMundur(
                  batas: pesanan['batasBayar'],
                  onHabis: () => context.read<PesananBloc>().add(
                    PesananDibatalkan(
                      pesanan['id'],
                      alasan: 'Tidak dibayar dalam $menitBatasBayar menit.',
                      otomatis: true,
                    ),
                  ),
                  style: gaya,
                ),
                const Text(', lewat itu batal otomatis', style: gaya),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _TombolUtama(
        teks: 'Bayar sekarang',
        onPressed: () => widget.onBayar(pesanan),
      ),
    ];
  }

  /// sudah dibayar: kode QR, petunjuk arah, hubungi mitra (F-52)
  List<Widget> _bawahAktif(Map<String, dynamic> pesanan) {
    return [
      const SizedBox(height: 12),
      _TombolUtama(
        ikon: Icons.qr_code_2,
        teks: 'Tampilkan QR',
        kode: pesanan['kode'],
        onPressed: () => widget.onBukaKode(pesanan),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _TombolGaris(
              ikon: Icons.navigation_outlined,
              teks: 'Petunjuk arah',
              onPressed: () => bukaPeta(context, pesanan['alamat']),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TombolGaris(
              ikon: Icons.call_outlined,
              teks: 'Hubungi mitra',
              onPressed: () => hubungiMitra(context, pesanan['mitra']),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _bawahSelesai(Map<String, dynamic> pesanan) {
    final diambil = pesanan['status'] == StatusPesanan.selesai;
    return [
      const SizedBox(height: 12),
      _Catatan(
        ikon: diambil ? Icons.eco_outlined : Icons.info_outline,
        teks: diambil
            ? '${pesanan['porsi']} porsi terselamatkan'
            : 'Tidak diambil sampai jam tutup, dana tidak dikembalikan.',
      ),
    ];
  }

  /// batal: alasan, lalu status dana kalau tadinya udah dibayar (F-12, F-42)
  List<Widget> _bawahDibatalkan(Map<String, dynamic> pesanan) {
    final sudahBayar = pesanan['dibayarPada'] != null;
    return [
      const SizedBox(height: 12),
      _Catatan(
        ikon: pesanan['otomatis'] == true ? Icons.schedule : Icons.info_outline,
        teks: sudahBayar
            ? pesanan['alasan']
            : '${pesanan['alasan']} Tidak ada dana yang terpotong.',
      ),
      if (sudahBayar) ...[
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'Dana ${rupiah(pesanan['total'])} kembali ke ${MetodeBayar.nama(pesanan['metode'])}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Warna.teks,
                ),
              ),
            ),
            // pengembalian dana diurus server, sementara selalu "Diproses"
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Warna.kraft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Diproses',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    ];
  }
}

/// rel krem isi tiga pilihan, yg aktif jadi pil gelap
class _SaringStatus extends StatelessWidget {
  const _SaringStatus({
    required this.pilihan,
    required this.aktif,
    required this.jumlahBerlangsung,
    required this.onPilih,
  });

  final List<String> pilihan;
  final String aktif;
  final int jumlahBerlangsung;
  final ValueChanged<String> onPilih;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Warna.kraft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final nama in pilihan)
            Expanded(
              // Semantics: dibaca pembaca layar sebagai tombol, plus tau mana yg kepilih
              child: Semantics(
                button: true,
                selected: aktif == nama,
                child: Material(
                  color: aktif == nama ? Warna.gelap : Colors.transparent,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onPilih(nama),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 9,
                      ),
                      // FittedBox: kalau hurufnya diperbesar / layarnya sempit,
                      // isinya dikecilin dikit, ga meluber (NF-01)
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              switch (nama) {
                                'berlangsung' => 'Berlangsung',
                                'selesai' => 'Selesai',
                                _ => 'Dibatalkan',
                              },
                              style: TextStyle(
                                fontSize: 12,
                                height: 16 / 12,
                                letterSpacing: 0.1,
                                fontWeight: aktif == nama
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: aktif == nama
                                    ? Colors.white
                                    : Warna.teksPendukung,
                              ),
                            ),
                            if (nama == 'berlangsung') ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: aktif == nama
                                      ? Colors.white
                                      : Warna.latar,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '$jumlahBerlangsung',
                                  key: const Key('jumlah-berlangsung'),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Warna.teks,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _JudulKelompok extends StatelessWidget {
  const _JudulKelompok(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Text(
        teks,
        style: const TextStyle(
          fontSize: 12,
          height: 16 / 12,
          letterSpacing: 0.1,
          fontWeight: FontWeight.w500,
          color: Warna.teksPendukung,
        ),
      ),
    );
  }
}

/// tombol hijau tua 44 tinggi, opsional ikon sama kode di belakang teks
class _TombolUtama extends StatelessWidget {
  const _TombolUtama({
    required this.teks,
    required this.onPressed,
    this.ikon,
    this.kode,
  });

  final String teks;
  final VoidCallback onPressed;
  final IconData? ikon;
  final String? kode;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Warna.hijau,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ikon != null) ...[
              Icon(ikon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              teks,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            if (kode != null) ...[
              const SizedBox(width: 8),
              Opacity(
                opacity: 0.75,
                child: Text(
                  kode!,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// tombol putih bergaris, dipake buat petunjuk arah sama hubungi mitra
class _TombolGaris extends StatelessWidget {
  const _TombolGaris({
    required this.ikon,
    required this.teks,
    required this.onPressed,
  });

  final IconData ikon;
  final String teks;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(ikon, size: 18),
      label: Text(teks, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: Warna.teks,
        backgroundColor: Colors.white,
        side: const BorderSide(color: Warna.garisKontrol),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// kotak krem muda isi ikon + keterangan
class _Catatan extends StatelessWidget {
  const _Catatan({required this.ikon, required this.teks});

  final IconData ikon;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Warna.latar,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: 18, color: Warna.teksPendukung),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              teks,
              style: const TextStyle(
                fontSize: 12,
                height: 16 / 12,
                fontWeight: FontWeight.w500,
                color: Warna.teks,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
