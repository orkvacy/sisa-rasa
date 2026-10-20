import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/core/theme/warna.dart';
import 'package:sisa_rasa/core/utils/format.dart';
import 'package:sisa_rasa/domain/repositories/layanan_admin.dart';
import 'package:sisa_rasa/presentation/cubit/admin_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/akun_cubit.dart';

/// halaman admin (F-36 - F-38): mitra yang baru daftar diperiksa dulu
/// sebelum paketnya keliatan pembeli. admin juga bisa nonaktifin mitra
class VerifikasiMitra extends StatefulWidget {
  const VerifikasiMitra({super.key});

  @override
  State<VerifikasiMitra> createState() => _VerifikasiMitraState();
}

class _VerifikasiMitraState extends State<VerifikasiMitra> {
  late final StreamSubscription<String> _galat;

  static const _filter = [
    (StatusGerai.menunggu, 'Menunggu'),
    (StatusGerai.terverifikasi, 'Terverifikasi'),
    (StatusGerai.ditolak, 'Ditolak'),
    (StatusGerai.nonaktif, 'Nonaktif'),
    ('', 'Semua'),
  ];

  @override
  void initState() {
    super.initState();
    final admin = context.read<AdminCubit>();
    _galat = admin.galat.listen((pesan) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(pesan)));
    });
    admin.muat();
  }

  @override
  void dispose() {
    _galat.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminCubit>();
    final mitra = admin.mitra;

    final Widget isi;
    if (admin.memuat && mitra.isEmpty) {
      isi = const Center(child: CircularProgressIndicator());
    } else if (mitra.isEmpty) {
      // tetap bisa ditarik buat muat ulang
      isi = ListView(
        padding: const EdgeInsets.all(32),
        children: const [
          Text(
            'Belum ada mitra di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Warna.teksPendukung),
          ),
        ],
      );
    } else {
      isi = ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: mitra.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _KartuMitra(mitra[i]),
      );
    }

    return Scaffold(
      backgroundColor: Warna.latar,
      appBar: AppBar(
        backgroundColor: Warna.latar,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Verifikasi mitra',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Warna.teks,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout, color: Warna.teksPendukung),
            onPressed: () => _keluar(context),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final (status, label) in _filter)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: admin.filter == status,
                      onSelected: (_) => admin.pilihFilter(status),
                      selectedColor: Warna.softGreen,
                      backgroundColor: Warna.kartu,
                      side: const BorderSide(color: Warna.garis),
                      showCheckmark: false,
                      // tema bawaan chip terpilih teksnya putih, ga kebaca di hijau muda
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: admin.filter == status
                            ? Warna.hijau
                            : Warna.teksPendukung,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(onRefresh: admin.muat, child: isi),
          ),
        ],
      ),
    );
  }
}

class _KartuMitra extends StatelessWidget {
  const _KartuMitra(this.mitra);

  final Map<String, dynamic> mitra;

  @override
  Widget build(BuildContext context) {
    final status = mitra['status'] as String;
    final alasan = mitra['alasan'] as String?;
    final alamat = mitra['alamat'] as String? ?? '';
    final daftar = DateTime.tryParse(mitra['daftar'] as String? ?? '');
    final keterangan = [
      mitra['jenis'],
      if ((mitra['email'] as String? ?? '').isNotEmpty) mitra['email'],
    ].join(' · ');

    return Container(
      key: Key('mitra-${mitra['id']}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Warna.kartu,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Warna.garis),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  mitra['nama'] as String,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Warna.teks,
                  ),
                ),
              ),
              _PilGerai(status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            keterangan,
            style: const TextStyle(fontSize: 13, color: Warna.teksPendukung),
          ),
          if (alamat.isNotEmpty)
            Text(
              alamat,
              style: const TextStyle(fontSize: 13, color: Warna.teksPendukung),
            ),
          const SizedBox(height: 4),
          Text(
            [
              '${mitra['jumlahPaket']} paket',
              if (daftar != null) 'daftar ${tanggalLengkap(daftar.toLocal())}',
            ].join(' · '),
            style: const TextStyle(fontSize: 12, color: Warna.teksPendukung),
          ),
          if (alasan != null) ...[
            const SizedBox(height: 8),
            Text(
              'Alasan: $alasan',
              style: const TextStyle(fontSize: 13, color: Warna.merah),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (status == StatusGerai.menunggu)
                TextButton(
                  onPressed: () => _periksa(context, StatusGerai.ditolak),
                  style: TextButton.styleFrom(foregroundColor: Warna.merah),
                  child: const Text('Tolak'),
                ),
              if (status == StatusGerai.terverifikasi)
                TextButton(
                  onPressed: () => _periksa(context, StatusGerai.nonaktif),
                  style: TextButton.styleFrom(foregroundColor: Warna.merah),
                  child: const Text('Nonaktifkan'),
                )
              else ...[
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _periksa(context, StatusGerai.terverifikasi),
                  style: FilledButton.styleFrom(
                    backgroundColor: Warna.hijau,
                    // tema bawaan tombolnya selebar layar, di sini cukup seukuran teks
                    minimumSize: const Size(0, 44),
                  ),
                  child: Text(
                    status == StatusGerai.menunggu
                        ? 'Setujui'
                        : 'Aktifkan lagi',
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _periksa(BuildContext context, String status) async {
    final admin = context.read<AdminCubit>();
    final nama = mitra['nama'] as String;
    var alasan = '';
    if (status == StatusGerai.terverifikasi) {
      final yakin = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Setujui $nama?'),
          content: const Text(
            'Paket mitra ini langsung tampil ke pembeli dan bisa dipesan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Setujui'),
            ),
          ],
        ),
      );
      if (yakin != true) return;
    } else {
      final isian = await showDialog<String>(
        context: context,
        builder: (c) => _DialogAlasan(
          judul: status == StatusGerai.ditolak
              ? 'Tolak $nama?'
              : 'Nonaktifkan $nama?',
        ),
      );
      if (isian == null) return;
      alasan = isian;
    }
    final berhasil = await admin.periksa(
      mitra['id'] as String,
      status,
      alasan: alasan,
    );
    if (!berhasil || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(switch (status) {
            StatusGerai.terverifikasi => '$nama sudah terverifikasi.',
            StatusGerai.ditolak => '$nama ditolak.',
            _ => '$nama dinonaktifkan.',
          }),
        ),
      );
  }
}

/// alasan wajib diisi, nanti keliatan di dasbor mitranya
class _DialogAlasan extends StatefulWidget {
  const _DialogAlasan({required this.judul});

  final String judul;

  @override
  State<_DialogAlasan> createState() => _DialogAlasanState();
}

class _DialogAlasanState extends State<_DialogAlasan> {
  final _alasan = TextEditingController();

  @override
  void dispose() {
    _alasan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isi = _alasan.text.trim();
    return AlertDialog(
      title: Text(widget.judul),
      content: TextField(
        key: const Key('alasan'),
        controller: _alasan,
        autofocus: true,
        maxLength: 300,
        maxLines: 3,
        minLines: 1,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: 'Alasan',
          helperText: 'Ditampilkan ke mitra di dasbornya.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: isi.isEmpty ? null : () => Navigator.pop(context, isi),
          style: TextButton.styleFrom(foregroundColor: Warna.merah),
          child: const Text('Kirim'),
        ),
      ],
    );
  }
}

class _PilGerai extends StatelessWidget {
  const _PilGerai(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final (latar, warna, label) = switch (status) {
      StatusGerai.menunggu => (
        Warna.mendesakLembut,
        Warna.mendesak,
        'Menunggu',
      ),
      StatusGerai.terverifikasi => (
        Warna.softGreen,
        Warna.hijau,
        'Terverifikasi',
      ),
      StatusGerai.ditolak => (Warna.merahLembut, Warna.merah, 'Ditolak'),
      _ => (Warna.garis, Warna.teksPendukung, 'Nonaktif'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: warna,
        ),
      ),
    );
  }
}

Future<void> _keluar(BuildContext context) async {
  final yakin = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Keluar dari akun admin?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          style: TextButton.styleFrom(foregroundColor: Warna.merah),
          child: const Text('Keluar'),
        ),
      ],
    ),
  );
  if (yakin != true || !context.mounted) return;
  await context.read<AkunCubit>().keluar();
}
