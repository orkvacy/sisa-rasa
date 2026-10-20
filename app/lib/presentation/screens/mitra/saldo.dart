import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/presentation/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/presentation/cubit/akun_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/saldo_cubit.dart';
import 'package:sisa_rasa/presentation/router.dart';
import 'package:sisa_rasa/presentation/screens/mitra/dasbor.dart';
import 'package:sisa_rasa/core/theme/warna.dart';
import 'package:sisa_rasa/core/utils/format.dart';
import 'package:sisa_rasa/domain/aturan/saldo.dart';

/// saldo mitra (figma v3: mitra/saldo, F-48, F-50)
class Saldo extends StatefulWidget {
  const Saldo({super.key});

  @override
  State<Saldo> createState() => _SaldoState();
}

class _SaldoState extends State<Saldo> {
  // riwayat diringkas dulu, "Semua" buat buka sisanya
  static const _ringkas = 5;
  bool semua = false;

  @override
  Widget build(BuildContext context) {
    // sesaat abis keluar, layar ini masih sempet digambar sekali sebelum router pindah
    final mitra = context.watch<AkunCubit>().state['nama'];
    if (mitra == null) return const SizedBox.shrink();
    final saldoCubit = context.watch<SaldoCubit>();
    final rekening = saldoCubit.rekening(mitra);
    final riwayat = saldoCubit.riwayat(
      mitra,
      context.watch<PesananBloc>().state,
    );
    final tersedia = saldoTersedia(riwayat);
    final tampil = semua ? riwayat : riwayat.take(_ringkas).toList();

    // dikelompokin per hari: Hari ini, Kemarin, ...
    final kelompok = <String, List<Map<String, dynamic>>>{};
    for (final e in tampil) {
      kelompok.putIfAbsent(kelompokTanggal(e['waktu']), () => []).add(e);
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, ruangBawahMitra),
        children: [
          const Text(
            'Saldo',
            style: TextStyle(
              fontSize: 28,
              height: 34 / 28,
              letterSpacing: -0.4,
              fontWeight: FontWeight.w800,
              color: Warna.teks,
            ),
          ),
          const SizedBox(height: 16),
          _KartuSaldo(
            tersedia: tersedia,
            rekening: rekening,
            onUbahRekening: () => context.push(Rute.mitraRekening),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _KotakAngka(
                  nilai: rupiah(totalMingguIni(riwayat, 'masuk')),
                  label: 'masuk minggu ini',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KotakAngka(
                  nilai: rupiah(totalMingguIni(riwayat, 'cair')),
                  label: 'dicairkan minggu ini',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Warna.teksPendukung,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Saldo dari pesanan yang sudah diambil, setelah dipotong komisi. Dicairkan tiap hari pukul 09.00.',
                  style: TextStyle(fontSize: 12, color: Warna.teksPendukung),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Riwayat',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Warna.teks,
                  ),
                ),
              ),
              if (riwayat.length > _ringkas)
                TextButton(
                  onPressed: () => setState(() => semua = !semua),
                  style: TextButton.styleFrom(foregroundColor: Warna.hijau),
                  child: Text(semua ? 'Ringkas' : 'Semua'),
                ),
            ],
          ),
          if (riwayat.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Belum ada dana masuk. Saldo bertambah setelah pesanan diambil pembeli.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Warna.teksPendukung),
              ),
            ),
          for (final MapEntry(key: judul, value: isi) in kelompok.entries) ...[
            const SizedBox(height: 8),
            Text(
              judul,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Warna.teksPendukung,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Warna.garis),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  for (final e in isi) ...[
                    _BarisRiwayat(entri: e),
                    if (e != isi.last)
                      const Divider(height: 1, color: Warna.garis),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _KartuSaldo extends StatelessWidget {
  const _KartuSaldo({
    required this.tersedia,
    required this.rekening,
    required this.onUbahRekening,
  });

  final int tersedia;
  final Map<String, dynamic>? rekening;
  final VoidCallback onUbahRekening;

  @override
  Widget build(BuildContext context) {
    final rek = rekening;
    // server nyairin saldo tiap hari mulai 09.00 (jendela sampai 11.59, NF-11)
    final kapan = jamSekarang < 9 * 60
        ? 'hari ini, 09.00'
        : jamSekarang < 12 * 60
        ? 'sebentar lagi'
        : 'besok, 09.00';
    final jadwal = rek == null
        ? 'Tambahkan rekening supaya saldo bisa dicairkan'
        : tersedia > 0
        ? 'Dicairkan otomatis $kapan'
        : 'Belum ada saldo untuk dicairkan';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Warna.momen,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saldo tersedia',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              rupiah(tersedia),
              key: const Key('saldo-tersedia'),
              style: const TextStyle(
                fontSize: 32,
                height: 40 / 32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  jadwal,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
            ],
          ),
          const Divider(height: 28, color: Colors.white24),
          Row(
            children: [
              const Icon(
                Icons.account_balance_outlined,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: rek == null
                    ? const Text(
                        'Belum ada rekening pencairan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rekeningSingkat(rek['bank'], rek['nomor']),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'a.n. ${rek['nama']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
              ),
              TextButton(
                onPressed: onUbahRekening,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(rek == null ? 'Tambah' : 'Ubah'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KotakAngka extends StatelessWidget {
  const _KotakAngka({required this.nilai, required this.label});

  final String nilai;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Warna.garis),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              nilai,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Warna.teks,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Warna.teksPendukung),
          ),
        ],
      ),
    );
  }
}

/// satu baris riwayat: dana masuk dari pesanan, atau pencairan ke rekening (F-50)
class _BarisRiwayat extends StatelessWidget {
  const _BarisRiwayat({required this.entri});

  final Map<String, dynamic> entri;

  @override
  Widget build(BuildContext context) {
    final masuk = entri['jenis'] == 'masuk';
    final DateTime waktu = entri['waktu'];
    final jamMenit = jam(waktu.hour * 60 + waktu.minute);

    final judul = masuk
        ? '${entri['kode']} · ${entri['pembeli']}'
        : 'Pencairan ke ${rekeningSingkat(entri['bank'], entri['nomor'])}';
    final keterangan = masuk
        ? '${rupiah(entri['jual'])} · komisi ${rupiah(entri['komisi'])}'
        : '${entri['status']} · $jamMenit';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: masuk ? Warna.softGreen : Warna.kraft,
            child: Icon(
              masuk ? Icons.add : Icons.chevron_right,
              size: 20,
              color: masuk ? Warna.hijau : Warna.teks,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  judul,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Warna.teks,
                  ),
                ),
                Text(
                  keterangan,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Warna.teksPendukung,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${masuk ? '+' : '−'}${rupiah(entri['jumlah'])}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: masuk ? Warna.hijau : Warna.teks,
            ),
          ),
        ],
      ),
    );
  }
}
