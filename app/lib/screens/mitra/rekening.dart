import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/cubit/akun_cubit.dart';
import 'package:sisa_rasa/cubit/saldo_cubit.dart';
import 'package:sisa_rasa/theme/warna.dart';

/// rekening pencairan mitra (figma v3: mitra/rekening pencairan, F-49)
class RekeningPencairan extends StatefulWidget {
  const RekeningPencairan({super.key});

  @override
  State<RekeningPencairan> createState() => _RekeningPencairanState();
}

class _RekeningPencairanState extends State<RekeningPencairan> {
  final nomor = TextEditingController();
  final nama = TextEditingController();
  String bank = bankPencairan.first;
  Map<String, String?> galat = {};

  String get _mitra => context.read<AkunCubit>().state['nama']!;

  @override
  void initState() {
    super.initState();
    final lama = context.read<SaldoCubit>().rekening(_mitra);
    if (lama != null) {
      bank = lama['bank'];
      nomor.text = lama['nomor'];
      nama.text = lama['nama'];
    }
  }

  @override
  void dispose() {
    nomor.dispose();
    nama.dispose();
    super.dispose();
  }

  void simpan() {
    final g = <String, String?>{};
    final n = nomor.text;
    if (n.length < 10 || n.length > 16) {
      g['nomor'] = 'Nomor rekening 10–16 angka.';
    }
    if (nama.text.trim().isEmpty) {
      g['nama'] = 'Nama pemilik wajib diisi.';
    } else if (!namaRekeningCocok(nama.text, _mitra)) {
      g['nama'] = 'Nama tidak cocok dengan nama usaha ($_mitra).';
    }
    setState(() => galat = g);
    if (g.isNotEmpty) return;

    context.read<SaldoCubit>().simpanRekening(
      _mitra,
      bank: bank,
      nomor: n,
      nama: nama.text.trim().toUpperCase(),
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Rekening disimpan')));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cocok = namaRekeningCocok(nama.text, _mitra);

    return Scaffold(
      backgroundColor: Warna.latar,
      appBar: AppBar(
        backgroundColor: Warna.latar,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 4,
        title: const Text(
          'Rekening pencairan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Warna.teks,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Warna.softGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.schedule, size: 20, color: Warna.hijau),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Saldo dicairkan otomatis ke rekening ini setiap hari pukul 09.00.',
                    style: TextStyle(fontSize: 13, color: Warna.hijau),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _Label('Bank'),
          DropdownButtonFormField<String>(
            initialValue: bank,
            items: [
              for (final b in bankPencairan)
                DropdownMenuItem(value: b, child: Text(b)),
            ],
            onChanged: (b) => setState(() => bank = b!),
          ),
          const SizedBox(height: 20),
          const _Label('Nomor rekening'),
          TextField(
            controller: nomor,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(16),
            ],
            onChanged: (_) => setState(() => galat.remove('nomor')),
            decoration: InputDecoration(
              hintText: 'Contoh: 1234567890',
              helperText: 'Hanya angka, tanpa titik atau spasi.',
              errorText: galat['nomor'],
            ),
          ),
          const SizedBox(height: 20),
          const _Label('Nama pemilik rekening'),
          TextField(
            controller: nama,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() => galat.remove('nama')),
            decoration: InputDecoration(
              hintText: _mitra.toUpperCase(),
              errorText: galat['nama'],
            ),
          ),
          if (cocok && galat['nama'] == null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.check, size: 16, color: Warna.hijau),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Nama cocok dengan data bank',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Warna.hijau,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'Nama pemilik harus sama dengan nama usaha di profil. Ganti rekening berlaku untuk pencairan berikutnya.',
            style: TextStyle(fontSize: 12, color: Warna.teksPendukung),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: simpan,
            style: FilledButton.styleFrom(
              backgroundColor: Warna.hijau,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Simpan rekening'),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        teks,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Warna.teks,
        ),
      ),
    );
  }
}
