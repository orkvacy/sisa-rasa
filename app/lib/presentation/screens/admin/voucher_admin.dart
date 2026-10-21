import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/core/theme/warna.dart';
import 'package:sisa_rasa/core/utils/format.dart';
import 'package:sisa_rasa/domain/aturan/voucher.dart';
import 'package:sisa_rasa/domain/repositories/layanan_pesanan.dart';
import 'package:sisa_rasa/presentation/cubit/voucher_cubit.dart';

/// halaman admin: voucher platform. potongannya ditanggung platform,
/// penerimaan mitra ga berkurang
class VoucherAdmin extends StatefulWidget {
  const VoucherAdmin({super.key});

  @override
  State<VoucherAdmin> createState() => _VoucherAdminState();
}

class _VoucherAdminState extends State<VoucherAdmin> {
  late final StreamSubscription<String> _galat;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<VoucherCubit>();
    _galat = cubit.galat.listen((pesan) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(pesan)));
    });
    cubit.muatSemua();
  }

  @override
  void dispose() {
    _galat.cancel();
    super.dispose();
  }

  Future<void> _buat() async {
    final cubit = context.read<VoucherCubit>();
    final dibuat = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Warna.kartu,
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const _FormVoucher()),
    );
    if (dibuat == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Voucher dibuat')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<VoucherCubit>();
    final daftar = cubit.semua;
    return Scaffold(
      backgroundColor: Warna.latar,
      appBar: AppBar(
        backgroundColor: Warna.latar,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Voucher',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Warna.teks,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('buat-voucher'),
        onPressed: _buat,
        backgroundColor: Warna.hijau,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        icon: const Icon(Icons.add),
        label: const Text('Buat voucher'),
      ),
      body: RefreshIndicator(
        onRefresh: cubit.muatSemua,
        child: cubit.memuat && daftar.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : daftar.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(32),
                children: const [
                  Text(
                    'Belum ada voucher. Buat voucher pertama untuk promo akuisisi pengguna.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Warna.teksPendukung),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: daftar.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _KartuVoucherAdmin(daftar[i]),
              ),
      ),
    );
  }
}

class _KartuVoucherAdmin extends StatelessWidget {
  const _KartuVoucherAdmin(this.v);

  final Map<String, dynamic> v;

  @override
  Widget build(BuildContext context) {
    final int? kuota = v['kuota'];
    final int minBelanja = v['minBelanja'];
    final DateTime mulai = v['mulai'];
    final DateTime berakhir = v['berakhir'];
    final aktif = v['aktif'] == true;
    final label = [
      if (v['khususBaru'] == true) 'Pesanan pertama',
      if (v['publik'] != true) 'Kode rahasia',
      kuota == null
          ? '${v['terpakai']} terpakai'
          : '${v['terpakai']}/$kuota terpakai',
    ];
    return Container(
      key: Key('voucher-admin-${v['kode']}'),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: Warna.kartu,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Warna.garis),
      ),
      child: Row(
        children: [
          Expanded(
            child: Opacity(
              opacity: aktif ? 1 : 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v['kode'],
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Warna.hijau,
                    ),
                  ),
                  Text(
                    v['judul'],
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Warna.teks,
                    ),
                  ),
                  Text(
                    [
                      ringkasVoucher(v, rupiah),
                      if (minBelanja > 0) 'min. ${rupiah(minBelanja)}',
                    ].join(' · '),
                    style: const TextStyle(fontSize: 12, color: Warna.teks),
                  ),
                  Text(
                    '${tanggalPendek(mulai)} – ${tanggalPendek(berakhir)} · ${label.join(' · ')}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Warna.teksPendukung,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Switch(
            value: aktif,
            onChanged: (nilai) =>
                context.read<VoucherCubit>().aturAktif(v['id'], aktif: nilai),
          ),
        ],
      ),
    );
  }
}

/// form buat voucher. tanggal mulai = sekarang, berakhir dipilih admin
class _FormVoucher extends StatefulWidget {
  const _FormVoucher();

  @override
  State<_FormVoucher> createState() => _FormVoucherState();
}

class _FormVoucherState extends State<_FormVoucher> {
  final kode = TextEditingController();
  final judul = TextEditingController();
  final persen = TextEditingController(text: '20');
  final maks = TextEditingController(text: '10000');
  final minBelanja = TextEditingController(text: '0');
  final kuota = TextEditingController();
  DateTime berakhir = DateTime.now().add(const Duration(days: 30));
  bool khususBaru = false;
  bool publik = true;
  bool menyimpan = false;
  String? galat;

  @override
  void dispose() {
    for (final c in [kode, judul, persen, maks, minBelanja, kuota]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pilihTanggal() async {
    final kini = DateTime.now();
    final dipilih = await showDatePicker(
      context: context,
      initialDate: berakhir,
      firstDate: kini,
      lastDate: kini.add(const Duration(days: 365)),
    );
    if (dipilih != null && mounted) {
      // berlaku sampai akhir hari yang dipilih
      setState(
        () => berakhir = DateTime(
          dipilih.year,
          dipilih.month,
          dipilih.day,
          23,
          59,
        ),
      );
    }
  }

  Future<void> _simpan() async {
    final nPersen = int.tryParse(persen.text);
    final nMaks = int.tryParse(maks.text);
    final nMin = int.tryParse(minBelanja.text.isEmpty ? '0' : minBelanja.text);
    final nKuota = kuota.text.trim().isEmpty ? null : int.tryParse(kuota.text);
    if (nPersen == null ||
        nMaks == null ||
        nMin == null ||
        (kuota.text.trim().isNotEmpty && nKuota == null)) {
      setState(() => galat = 'Isi angka dengan benar.');
      return;
    }
    setState(() {
      menyimpan = true;
      galat = null;
    });
    try {
      await context.read<VoucherCubit>().buat({
        'kode': kode.text,
        'judul': judul.text,
        'persen': nPersen,
        'maksPotongan': nMaks,
        'minBelanja': nMin,
        'mulai': DateTime.now(),
        'berakhir': berakhir,
        'kuota': nKuota,
        'khususBaru': khususBaru,
        'publik': publik,
      });
      if (mounted) Navigator.pop(context, true);
    } on GagalLayanan catch (e) {
      if (mounted) {
        setState(() {
          galat = e.pesan;
          menyimpan = false;
        });
      }
    }
  }

  Widget _angka(TextEditingController c, String label, {String? bantuan}) =>
      TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label, helperText: bantuan),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Buat voucher',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Potongan ditanggung platform. Penerimaan mitra tidak berkurang.',
              style: TextStyle(fontSize: 12, color: Warna.teksPendukung),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('isian-kode'),
              controller: kode,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Kode',
                helperText: '4–20 huruf/angka, misal SISAHEMAT',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('isian-judul'),
              controller: judul,
              decoration: const InputDecoration(labelText: 'Judul'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _angka(persen, 'Diskon (%)')),
                const SizedBox(width: 10),
                Expanded(child: _angka(maks, 'Maks. potongan (Rp)')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _angka(minBelanja, 'Min. belanja (Rp)')),
                const SizedBox(width: 10),
                Expanded(
                  child: _angka(
                    kuota,
                    'Kuota',
                    bantuan: 'Kosong = tanpa batas',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Berlaku sampai'),
              subtitle: Text(tanggalLengkap(berakhir)),
              trailing: const Icon(Icons.calendar_today_outlined, size: 20),
              onTap: _pilihTanggal,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Khusus pesanan pertama'),
              subtitle: const Text('Hanya pembeli yang belum pernah pesan'),
              value: khususBaru,
              onChanged: (v) => setState(() => khususBaru = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tampilkan di daftar voucher'),
              subtitle: const Text(
                'Matikan untuk kode rahasia (promo Instagram, brosur)',
              ),
              value: publik,
              onChanged: (v) => setState(() => publik = v),
            ),
            if (galat != null) ...[
              const SizedBox(height: 6),
              Text(galat!, style: const TextStyle(color: Warna.merah)),
            ],
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('simpan-voucher'),
              onPressed: menyimpan ? null : _simpan,
              style: FilledButton.styleFrom(backgroundColor: Warna.hijau),
              child: Text(menyimpan ? 'Menyimpan…' : 'Simpan voucher'),
            ),
          ],
        ),
      ),
    );
  }
}
