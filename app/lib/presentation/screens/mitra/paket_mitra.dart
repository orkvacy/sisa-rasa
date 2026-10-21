import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/presentation/cubit/akun_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/paket_cubit.dart';
import 'package:sisa_rasa/presentation/router.dart';
import 'package:sisa_rasa/presentation/screens/mitra/dasbor.dart';
import 'package:sisa_rasa/core/theme/warna.dart';
import 'package:sisa_rasa/core/utils/format.dart';
import 'package:sisa_rasa/presentation/widgets/animasi.dart';
import 'package:sisa_rasa/presentation/widgets/gambar_paket.dart';

/// status satu paket dari sisi mitra
String statusPaket(Map<String, dynamic> paket) {
  if (paket['nonaktif'] == true) return 'Nonaktif';
  // F-25: lewat jam tutup tetep tampil di daftar mitra, tapi kedaluwarsa
  if (paket['tutup'] <= jamSekarang) return 'Kedaluwarsa';
  if (paket['sisaPorsi'] == 0) return 'Habis';
  return 'Aktif';
}

/// kelola paket mitra (figma v3: mitra/paket, F-14, F-44, F-45)
class PaketMitra extends StatefulWidget {
  const PaketMitra({super.key});

  @override
  State<PaketMitra> createState() => _PaketMitraState();
}

class _PaketMitraState extends State<PaketMitra> {
  static const _saring = ['Semua', 'Aktif', 'Habis', 'Nonaktif'];
  String saring = 'Semua';
  String cari = '';

  @override
  Widget build(BuildContext context) {
    // sesaat abis keluar, layar ini masih sempet digambar sekali sebelum router pindah
    final mitra = context.watch<AkunCubit>().state['nama'];
    if (mitra == null) return const SizedBox.shrink();
    final semua = [
      for (final p in context.watch<PaketCubit>().state)
        if (p['mitra'] == mitra) p,
    ];

    int jumlah(String s) => s == 'Semua'
        ? semua.length
        : semua.where((p) => statusPaket(p) == s).length;

    final tampil = semua.where((p) {
      final cocokSaring = saring == 'Semua' || statusPaket(p) == saring;
      final cocokCari = (p['nama'] as String).toLowerCase().contains(
        cari.toLowerCase(),
      );
      return cocokSaring && cocokCari;
    }).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, ruangBawahMitra),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Paket',
                  style: TextStyle(
                    fontSize: 22,
                    height: 34 / 28,
                    letterSpacing: -0.4,
                    fontWeight: FontWeight.w800,
                    color: Warna.teks,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.push(Rute.mitraPaketBaru),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Paket baru'),
                style: FilledButton.styleFrom(
                  backgroundColor: Warna.hijau,
                  // tema bikin tombol selebar layar, di sini seukuran isinya
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (teks) => setState(() => cari = teks),
            // abu muda tanpa garis, sama kayak kolom cari beranda
            decoration: InputDecoration(
              hintText: 'Cari nama paket',
              prefixIcon: const Icon(Icons.search, size: 20),
              fillColor: Warna.kraft,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in _saring) ...[
                  ChoiceChip(
                    label: Text('$s ${jumlah(s)}'),
                    selected: saring == s,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => saring = s),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (tampil.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                semua.isEmpty
                    ? 'Belum ada paket. Tekan Paket baru untuk mulai menjual sisa makanan hari ini.'
                    : 'Tidak ada paket yang cocok.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Warna.teksPendukung),
              ),
            ),
          for (final (i, p) in tampil.indexed) ...[
            MunculBertahap(
              key: ValueKey('$saring-${p['id']}'),
              urutan: i,
              child: _KartuPaket(
                paket: p,
                onTap: () => context.push(Rute.mitraUbahPaket(p['id'])),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _KartuPaket extends StatelessWidget {
  const _KartuPaket({required this.paket, required this.onTap});

  final Map<String, dynamic> paket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PaketCubit>();
    final status = statusPaket(paket);
    final nonaktif = status == 'Nonaktif';
    final int sisa = paket['sisaPorsi'];
    final int total = paket['totalPorsi'];

    final (Color latarPil, Color warnaPil) = switch (status) {
      'Aktif' => (Warna.softGreen, Warna.hijau),
      'Habis' => (Warna.gelap, Colors.white),
      'Kedaluwarsa' => (Warna.garis, Warna.teksPendukung),
      _ => (Warna.kraft, Warna.teksPendukung),
    };

    return Opacity(
      // paket nonaktif dipudarin
      opacity: nonaktif ? 0.55 : 1,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Warna.garis),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GambarPaket(
                        paket['foto'],
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            paket['nama'],
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Warna.teks,
                            ),
                          ),
                          Text(
                            '${jam(paket['mulai'])} – ${jam(paket['tutup'])} · ${rupiah(paket['hargaDiskon'])}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Warna.teksPendukung,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: latarPil,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: warnaPil,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // aktif / nonaktif (F-45)
                    Switch(
                      value: !nonaktif,
                      activeTrackColor: Warna.hijau,
                      onChanged: (aktif) =>
                          cubit.aturAktif(paket['id'], aktif: aktif),
                    ),
                  ],
                ),
                const Divider(height: 24, color: Warna.garis),
                // sisa porsi langsung dari daftar (F-44)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sisa porsi',
                            style: TextStyle(
                              fontSize: 12,
                              color: Warna.teksPendukung,
                            ),
                          ),
                          Text(
                            '$sisa dari $total',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Warna.teks,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // tombol kecil, ditanya dulu: sekali kepencet paketnya
                    // langsung ilang dari beranda pembeli
                    OutlinedButton(
                      key: Key('set-habis-${paket['id']}'),
                      onPressed: sisa > 0
                          ? () => _konfirmasiHabis(context, cubit, paket)
                          : onTap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Warna.hijau,
                        side: const BorderSide(color: Warna.garisKontrol),
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(sisa > 0 ? 'Set habis' : 'Ubah'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// F-44: tanya dulu sebelum sisa porsi dijadiin 0
Future<void> _konfirmasiHabis(
  BuildContext context,
  PaketCubit cubit,
  Map<String, dynamic> paket,
) async {
  final yakin = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Tandai paket habis?'),
      content: Text(
        '${paket['nama']} tidak akan tampil lagi untuk pembeli hari ini. '
        'Sisa porsi bisa diisi lagi lewat Ubah.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Tidak'),
        ),
        FilledButton(
          key: const Key('yakin-habis'),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Ya, habis'),
        ),
      ],
    ),
  );
  if (yakin == true) cubit.ubahSisa(paket['id'], 0);
}
