import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/core/theme/warna.dart';
import 'package:sisa_rasa/core/utils/format.dart';
import 'package:sisa_rasa/domain/aturan/voucher.dart';
import 'package:sisa_rasa/domain/repositories/layanan_pesanan.dart';
import 'package:sisa_rasa/presentation/cubit/voucher_cubit.dart';

/// lembar pilih voucher di checkout: ketik kode, atau pilih dari daftar.
/// balikin {voucher, potongan} kalau ada yang dipakai, null kalau ditutup
Future<Map<String, dynamic>?> pilihVoucher(
  BuildContext context, {
  required int subtotal,
}) {
  final cubit = context.read<VoucherCubit>()..muatTersedia();
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Warna.kartu,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _LembarVoucher(subtotal: subtotal),
    ),
  );
}

class _LembarVoucher extends StatefulWidget {
  const _LembarVoucher({required this.subtotal});

  final int subtotal;

  @override
  State<_LembarVoucher> createState() => _LembarVoucherState();
}

class _LembarVoucherState extends State<_LembarVoucher> {
  final _kode = TextEditingController();
  String? galat;
  bool mengecek = false;

  @override
  void dispose() {
    _kode.dispose();
    super.dispose();
  }

  Future<void> pakai(String kode) async {
    if (kode.trim().isEmpty || mengecek) return;
    setState(() {
      mengecek = true;
      galat = null;
    });
    try {
      final hasil = await context.read<VoucherCubit>().cek(
        kode,
        widget.subtotal,
      );
      if (mounted) Navigator.pop(context, hasil);
    } on GagalLayanan catch (e) {
      if (mounted) {
        setState(() {
          galat = e.pesan;
          mengecek = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<VoucherCubit>();
    final tinggi = MediaQuery.of(context).size.height * 0.75;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: tinggi),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Voucher',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Warna.teks,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('kode-voucher'),
                      controller: _kode,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      onSubmitted: pakai,
                      decoration: InputDecoration(
                        hintText: 'Masukkan kode voucher',
                        errorText: galat,
                        errorMaxLines: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: mengecek ? null : () => pakai(_kode.text),
                      style: FilledButton.styleFrom(
                        backgroundColor: Warna.hijau,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      child: Text(mengecek ? '…' : 'Pakai'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Voucher tersedia',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Warna.teks,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: cubit.memuat && cubit.tersedia.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : cubit.tersedia.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Belum ada voucher untukmu saat ini. Punya kode promo? Ketik di atas.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Warna.teksPendukung,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: cubit.tersedia.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final v = cubit.tersedia[i];
                          return _KartuVoucher(
                            voucher: v,
                            alasan: alasanVoucherTakBisa(
                              v,
                              widget.subtotal,
                              rupiah,
                            ),
                            onPakai: () => pakai(v['kode']),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KartuVoucher extends StatelessWidget {
  const _KartuVoucher({
    required this.voucher,
    required this.alasan,
    required this.onPakai,
  });

  final Map<String, dynamic> voucher;
  final String? alasan;
  final VoidCallback onPakai;

  @override
  Widget build(BuildContext context) {
    final bisa = alasan == null;
    final DateTime berakhir = voucher['berakhir'];
    final int minBelanja = voucher['minBelanja'];
    return Opacity(
      opacity: bisa ? 1 : 0.55,
      child: InkWell(
        key: Key('voucher-${voucher['kode']}'),
        onTap: bisa ? onPakai : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: bisa ? Warna.hijau : Warna.garis),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Warna.softGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.local_offer_outlined,
                  color: Warna.hijau,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voucher['judul'],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Warna.teks,
                      ),
                    ),
                    Text(
                      [
                        ringkasVoucher(voucher, rupiah),
                        if (minBelanja > 0) 'min. ${rupiah(minBelanja)}',
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: Warna.teks),
                    ),
                    Text(
                      alasan ??
                          [
                            if (voucher['khususBaru'] == true)
                              'Pesanan pertama',
                            'Berlaku s.d. ${tanggalPendek(berakhir)}',
                          ].join(' · '),
                      style: TextStyle(
                        fontSize: 11,
                        color: bisa ? Warna.teksPendukung : Warna.mendesak,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                voucher['kode'],
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Warna.hijau,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
