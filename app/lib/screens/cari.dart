import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/cubit/paket_cubit.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';
import 'package:sisa_rasa/widgets/kartu_paket.dart';

/// halaman cari, dibuka dari icon cari di beranda
class Cari extends StatefulWidget {
  const Cari({required this.onBukaPaket, super.key});

  final ValueChanged<Map<String, dynamic>> onBukaPaket;

  @override
  State<Cari> createState() => _CariState();
}

class _CariState extends State<Cari> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    // nyari di nama paket sama nama mitra
    final daftarPaket = context.watch<PaketCubit>().state;
    final hasil = daftarPaket.where((paket) {
      final teks = '${paket['nama']} ${paket['mitra']}'.toLowerCase();
      return paket['tutup'] > jamSekarang && teks.contains(searchQuery);
    }).toList();

    return Scaffold(
      // AppBar: bar atas, tombol back nya udah otomatis Navigator.pop
      appBar: AppBar(
        backgroundColor: Warna.latar,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: TextField(
          autofocus: true,
          onChanged: (value) =>
              setState(() => searchQuery = value.toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Cari paket atau mitra',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Warna.garisKontrol),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Warna.garisKontrol),
            ),
          ),
        ),
        actions: const [SizedBox(width: 16)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (hasil.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Text(
                'Tidak ada paket yang cocok. Coba nama paket atau nama mitra lain.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Warna.teksPendukung),
              ),
            ),
          for (final paket in hasil) ...[
            KartuPaket(paket: paket, onTap: () => widget.onBukaPaket(paket)),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
