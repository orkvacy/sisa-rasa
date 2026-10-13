import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/presentation/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/presentation/cubit/akun_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/percakapan_cubit.dart';
import 'package:sisa_rasa/domain/aturan/status_pesanan.dart';
import 'package:sisa_rasa/core/theme/warna.dart';
import 'package:sisa_rasa/presentation/utils/aksi_mitra.dart';
import 'package:sisa_rasa/core/utils/format.dart';
import 'package:sisa_rasa/domain/aturan/percakapan.dart';

/// percakapan pembeli - mitra untuk satu pesanan (SRS layar 6a, F-67 s.d. F-70).
/// dipake dua peran, peran yg lagi masuk nentuin bubble mana yg "punya saya"
class Percakapan extends StatefulWidget {
  const Percakapan({required this.idPesanan, super.key});

  final String idPesanan;

  @override
  State<Percakapan> createState() => _PercakapanState();
}

class _PercakapanState extends State<Percakapan> {
  final kolom = TextEditingController();
  late final String peran = context.read<AkunCubit>().state['peran'] == 'mitra'
      ? 'mitra'
      : 'pembeli';

  @override
  void initState() {
    super.initState();
    final cubit = context.read<PercakapanCubit>();
    cubit.muat(widget.idPesanan).then((_) {
      if (mounted) cubit.tandaiDibaca(widget.idPesanan, peran);
    });
  }

  @override
  void dispose() {
    kolom.dispose();
    super.dispose();
  }

  void kirim(String teks) {
    context.read<PercakapanCubit>().kirim(
      idPesanan: widget.idPesanan,
      peran: peran,
      teks: teks,
    );
    kolom.clear();
  }

  @override
  Widget build(BuildContext context) {
    final pesanan = context.select<PesananBloc, Map<String, dynamic>?>(
      (bloc) => bloc.cari(widget.idPesanan),
    );
    if (pesanan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Pesanan tidak ditemukan')),
      );
    }
    final daftar = context.watch<PercakapanCubit>().pesan(widget.idPesanan);
    final keadaan = keadaanPercakapan(pesanan);
    final lawan = peran == 'mitra'
        ? pesanan['namaPembeli']
        : pesanan['mitra'] as String;

    // pesan baru dari lawan bicara langsung dianggap dibaca selama layar ini kebuka
    return BlocListener<
      PercakapanCubit,
      Map<String, List<Map<String, dynamic>>>
    >(
      listenWhen: (lama, baru) =>
          lama[widget.idPesanan] != baru[widget.idPesanan],
      listener: (context, _) =>
          context.read<PercakapanCubit>().tandaiDibaca(widget.idPesanan, peran),
      child: Scaffold(
        backgroundColor: Warna.latar,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 0,
          leading: IconButton(
            tooltip: 'Kembali',
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
          ),
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Warna.softGreen,
                child: Text(
                  inisial(lawan.replaceAll('.', '')),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Warna.hijau,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lawan,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Warna.teks,
                      ),
                    ),
                    Text(
                      '${pesanan['kode'] ?? ''} · ${StatusPesanan.label(pesanan['status'])}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Warna.teksPendukung,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (peran == 'pembeli')
              IconButton(
                tooltip: 'Telepon mitra',
                onPressed: () => hubungiMitra(context, pesanan['mitra']),
                icon: const Icon(Icons.call_outlined),
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: daftar.isEmpty
                  ? _Kosong(peran: peran)
                  // reverse: pesan terbaru nempel di bawah, deket kolom ketik
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      itemCount: daftar.length,
                      itemBuilder: (context, i) {
                        final p = daftar[daftar.length - 1 - i];
                        final sebelumnya = i + 1 < daftar.length
                            ? daftar[daftar.length - 2 - i]
                            : null;
                        final judulHari = kelompokTanggal(p['waktu']);
                        final hariBaru =
                            sebelumnya == null ||
                            kelompokTanggal(sebelumnya['waktu']) != judulHari;
                        return Column(
                          children: [
                            if (hariBaru) _JudulHari(judulHari),
                            _Gelembung(
                              pesan: p,
                              punyaSaya: p['peran'] == peran,
                              onKirimUlang: () => context
                                  .read<PercakapanCubit>()
                                  .kirimUlang(widget.idPesanan, p['id']),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            if (keadaan == 'terbuka')
              _KolomKirim(
                kolom: kolom,
                templat: pesanCepat[peran]!,
                onKirim: kirim,
              )
            else
              _Tertutup(
                teks: keadaan == 'tidakAda'
                    ? 'Percakapan terbuka setelah pesanan dibayar.'
                    : 'Percakapan ditutup $jamPercakapanSetelahSelesai jam setelah pesanan berakhir. Riwayatnya tetap bisa dibaca.',
              ),
          ],
        ),
      ),
    );
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong({required this.peran});

  final String peran;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.chat_bubble_outline,
              size: 40,
              color: Warna.teksPendukung,
            ),
            const SizedBox(height: 12),
            Text(
              peran == 'mitra'
                  ? 'Belum ada pesan. Kabari pembeli kalau pesanannya sudah siap.'
                  : 'Belum ada pesan. Kabari mitra kalau kamu terlambat atau sudah sampai.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Warna.teksPendukung),
            ),
          ],
        ),
      ),
    );
  }
}

class _JudulHari extends StatelessWidget {
  const _JudulHari(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Warna.kraft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          teks,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Warna.teksPendukung,
          ),
        ),
      ),
    );
  }
}

/// satu pesan. punya sendiri di kanan (hijau), lawan bicara di kiri (putih)
class _Gelembung extends StatelessWidget {
  const _Gelembung({
    required this.pesan,
    required this.punyaSaya,
    required this.onKirimUlang,
  });

  final Map<String, dynamic> pesan;
  final bool punyaSaya;
  final VoidCallback onKirimUlang;

  @override
  Widget build(BuildContext context) {
    final DateTime waktu = pesan['waktu'];
    final String status = pesan['status'];
    final gagal = status == 'gagal';
    final warnaTeks = punyaSaya ? Colors.white : Warna.teks;
    final warnaKecil = punyaSaya ? Colors.white70 : Warna.teksPendukung;

    final (IconData ikon, String label) = switch (status) {
      'mengirim' => (Icons.schedule, 'Mengirim'),
      'terkirim' => (Icons.done, 'Terkirim'),
      'dibaca' => (Icons.done_all, 'Dibaca'),
      _ => (Icons.error_outline, 'Gagal terkirim'),
    };

    final gelembung = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
      ),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      decoration: BoxDecoration(
        color: punyaSaya ? Warna.hijau : Colors.white,
        border: punyaSaya ? null : Border.all(color: Warna.garis),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(punyaSaya ? 18 : 4),
          bottomRight: Radius.circular(punyaSaya ? 4 : 18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: Text(
              pesan['teks'],
              style: TextStyle(fontSize: 15, height: 20 / 15, color: warnaTeks),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                jam(waktu.hour * 60 + waktu.minute),
                style: TextStyle(fontSize: 11, color: warnaKecil),
              ),
              // status cuma ditampilin di pesan sendiri (F-70)
              if (punyaSaya) ...[
                const SizedBox(width: 4),
                Semantics(
                  label: label,
                  child: Icon(
                    ikon,
                    size: 14,
                    color: gagal ? Warna.merahLembut : warnaKecil,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    return Align(
      alignment: punyaSaya ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: punyaSaya
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          gelembung,
          if (gagal)
            TextButton.icon(
              onPressed: onKirimUlang,
              style: TextButton.styleFrom(
                foregroundColor: Warna.merah,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Gagal terkirim. Coba lagi'),
            ),
        ],
      ),
    );
  }
}

class _KolomKirim extends StatefulWidget {
  const _KolomKirim({
    required this.kolom,
    required this.templat,
    required this.onKirim,
  });

  final TextEditingController kolom;
  final List<String> templat;
  final ValueChanged<String> onKirim;

  @override
  State<_KolomKirim> createState() => _KolomKirimState();
}

class _KolomKirimState extends State<_KolomKirim> {
  bool adaIsi = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(height: 1, color: Warna.garis),
            // pesan cepat (F-69)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  for (final t in widget.templat) ...[
                    ActionChip(
                      label: Text(t),
                      onPressed: () => widget.onKirim(t),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.kolom,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (teks) =>
                          setState(() => adaIsi = teks.trim().isNotEmpty),
                      decoration: const InputDecoration(
                        hintText: 'Tulis pesan',
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    tooltip: 'Kirim',
                    onPressed: adaIsi
                        ? () {
                            widget.onKirim(widget.kolom.text);
                            setState(() => adaIsi = false);
                          }
                        : null,
                    style: IconButton.styleFrom(
                      backgroundColor: Warna.hijau,
                      fixedSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tertutup extends StatelessWidget {
  const _Tertutup({required this.teks});

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Warna.kraft,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, size: 18, color: Warna.teks),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  teks,
                  style: const TextStyle(fontSize: 13, color: Warna.teks),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
