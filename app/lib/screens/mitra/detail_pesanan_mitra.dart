import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/bloc/pesanan_event.dart';
import 'package:sisa_rasa/data/dummy_akun.dart';
import 'package:sisa_rasa/data/pembayaran.dart';
import 'package:sisa_rasa/data/status_pesanan.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';
import 'package:sisa_rasa/widgets/bagian_pesanan.dart';

/// detail satu pesanan dari sisi mitra (figma v3: mitra/detail pesanan, F-19, F-20, F-43).
/// bentuknya sama kayak punya pembeli, bedanya rinciannya dari kacamata mitra
/// (harga jual, komisi, yg diterima) dan ada tombol buat maju ke tahap berikutnya
class DetailPesananMitra extends StatelessWidget {
  const DetailPesananMitra({required this.idPesanan, super.key});

  final String idPesanan;

  @override
  Widget build(BuildContext context) {
    final pesanan = context.select<PesananBloc, Map<String, dynamic>?>(
      (bloc) => bloc.cari(idPesanan),
    );
    if (pesanan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Pesanan tidak ditemukan')),
      );
    }
    final String status = pesanan['status'];
    final bisaBatal =
        status == StatusPesanan.disiapkan ||
        status == StatusPesanan.siapDiambil;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Warna.latar,
        body: Column(
          children: [
            KepalaHijau(
              judul: 'Pesanan ${pesanan['kode'] ?? ''}',
              onKembali: () => context.pop(),
            ),
            Expanded(
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
                        BlokPutih(
                          children: [
                            if (status != StatusPesanan.dibatalkan) ...[
                              TahapanPesanan(status: status),
                              const SizedBox(height: 16),
                            ],
                            _KotakStatus(pesanan: pesanan),
                          ],
                        ),
                        const SizedBox(height: 8),
                        BlokPutih(
                          judul: 'Pembeli',
                          children: [
                            BarisIkon(
                              ikon: Icons.person_outline,
                              judul: namaPembeli(pesanan['idAkun']),
                              teks: pesanan['dibayarPada'] == null
                                  ? 'Belum dibayar'
                                  : 'Dibayar ${tanggalSingkat(pesanan['dibayarPada'])}',
                            ),
                            const SizedBox(height: 12),
                            BarisIkon(
                              ikon: Icons.schedule,
                              judul: 'Ambil sendiri',
                              teks:
                                  'Hari ini, ${jam(pesanan['mulai'])} – ${jam(pesanan['tutup'])}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        BagianIsiPesanan(pesanan: pesanan),
                        const SizedBox(height: 8),
                        _RincianMitra(pesanan: pesanan),
                        const SizedBox(height: 8),
                        BagianInfoPesanan(pesanan: pesanan),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            8,
                            16,
                            24 + MediaQuery.of(context).padding.bottom,
                          ),
                          child: bisaBatal
                              ? TextButton(
                                  onPressed: () =>
                                      _tanyaBatal(context, pesanan),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Warna.merah,
                                  ),
                                  child: const Text(
                                    'Batalkan pesanan',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
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

  /// pilih alasan dulu, dana pembeli balik penuh (F-42)
  Future<void> _tanyaBatal(
    BuildContext context,
    Map<String, dynamic> pesanan,
  ) async {
    final bloc = context.read<PesananBloc>();
    final alasan = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => _LembarBatal(pesanan: pesanan),
    );
    if (alasan != null) {
      bloc.add(PesananDibatalkanMitra(pesanan['id'], alasan: alasan));
    }
  }
}

/// kotak status + tombol maju ke tahap berikutnya
class _KotakStatus extends StatelessWidget {
  const _KotakStatus({required this.pesanan});

  final Map<String, dynamic> pesanan;

  @override
  Widget build(BuildContext context) {
    final String status = pesanan['status'];
    final pembeli = namaPembeli(pesanan['idAkun']);
    final ambil = '${jam(pesanan['mulai'])}–${jam(pesanan['tutup'])}';

    final (
      String judul,
      String teks,
      String? tombol,
      String? berikutnya,
    ) = switch (status) {
      StatusPesanan.menungguBayar => (
        'Menunggu pembayaran',
        '$pembeli belum membayar. Siapkan setelah statusnya Lunas.',
        null,
        null,
      ),
      StatusPesanan.disiapkan => (
        'Siapkan pesanan ini',
        '$pembeli datang $ambil. Tandai siap kalau sudah dikemas, status di aplikasi pembeli ikut berubah.',
        'Tandai siap diambil',
        StatusPesanan.siapDiambil,
      ),
      StatusPesanan.siapDiambil => (
        'Menunggu diambil',
        'Cocokkan kode ${pesanan['kode']} yang ditunjukkan $pembeli, lalu tandai sudah diambil.',
        'Tandai sudah diambil',
        StatusPesanan.selesai,
      ),
      StatusPesanan.selesai => (
        'Pesanan sudah diambil',
        '${pesanan['porsi']} porsi terselamatkan. ${rupiah(penerimaanBersih(pesanan))} masuk ke saldo.',
        null,
        null,
      ),
      StatusPesanan.dibatalkan => (
        'Pesanan dibatalkan',
        pesanan['olehMitra'] == true
            ? '${pesanan['alasan']} Dana ${rupiah(pesanan['total'])} dikembalikan penuh ke $pembeli.'
            : '${pesanan['alasan']}',
        null,
        null,
      ),
      _ => (StatusPesanan.label(status), '', null, null),
    };
    final batal = status == StatusPesanan.dibatalkan;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: batal ? Warna.merahLembut : Warna.softGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            judul,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 22 / 16,
              fontWeight: FontWeight.w700,
              color: batal ? Warna.merah : Warna.hijau,
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
          if (tombol != null) ...[
            const SizedBox(height: 12),
            TombolBesar(
              teks: tombol,
              onPressed: () => context.read<PesananBloc>().add(
                StatusPesananDiubah(pesanan['id'], berikutnya!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// rincian dari sisi mitra: harga jual, komisi platform, yg diterima (F-48)
class _RincianMitra extends StatelessWidget {
  const _RincianMitra({required this.pesanan});

  final Map<String, dynamic> pesanan;

  @override
  Widget build(BuildContext context) {
    final int jual = pesanan['subtotal'];
    final lunas = pesanan['dibayarPada'] != null;

    return BlokPutih(
      judul: 'Rincian pembayaran',
      children: [
        BarisNilai(
          label: 'Harga jual (${pesanan['porsi']} porsi)',
          nilai: rupiah(jual),
        ),
        const SizedBox(height: 10),
        BarisNilai(
          label: 'Komisi Sisa Rasa ($persenKomisi%)',
          nilai: '−${rupiah(komisi(jual))}',
        ),
        const Divider(height: 21, color: Warna.garis),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Diterima mitra',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Warna.teks,
                ),
              ),
            ),
            Text(
              rupiah(penerimaanBersih(pesanan)),
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
                color: lunas ? Warna.softGreen : Warna.mendesakLembut,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                lunas ? 'Lunas' : 'Belum dibayar',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: lunas ? Warna.hijau : Warna.mendesak,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// lembar batal: pilih alasan, dana dikembalikan penuh ke pembeli (figma: sheet batalkan)
class _LembarBatal extends StatefulWidget {
  const _LembarBatal({required this.pesanan});

  final Map<String, dynamic> pesanan;

  @override
  State<_LembarBatal> createState() => _LembarBatalState();
}

class _LembarBatalState extends State<_LembarBatal> {
  static const _alasan = [
    'Paket sudah habis.',
    'Dapur tutup lebih awal.',
    'Alasan lain dari mitra.',
  ];
  String dipilih = _alasan.first;

  @override
  Widget build(BuildContext context) {
    final p = widget.pesanan;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Batalkan pesanan ${p['kode']}?',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Warna.teks,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dana ${rupiah(p['total'])} dikembalikan penuh ke ${namaPembeli(p['idAkun'])}. Pembeli akan melihat alasan yang kamu pilih.',
              style: const TextStyle(fontSize: 14, color: Warna.teksPendukung),
            ),
            const SizedBox(height: 12),
            for (final alasan in _alasan)
              Material(
                color: alasan == dipilih ? Warna.softGreen : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => dipilih = alasan),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          alasan == dipilih
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: alasan == dipilih
                              ? Warna.hijau
                              : Warna.garisKontrol,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          alasan
                              .replaceAll('.', '')
                              .replaceAll(' dari mitra', ''),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Warna.teks,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, dipilih),
                style: FilledButton.styleFrom(
                  backgroundColor: Warna.merah,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Batalkan pesanan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kembali'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
