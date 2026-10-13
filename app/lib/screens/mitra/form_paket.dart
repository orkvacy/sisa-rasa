import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/cubit/akun_cubit.dart';
import 'package:sisa_rasa/cubit/paket_cubit.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';

/// kategori paket, sama kayak chip di beranda pembeli (F-03)
const kategoriPaket = ['Nasi & lauk', 'Roti & kue', 'Buffet hotel', 'Minuman'];

/// form paket baru / ubah paket (figma v3: mitra/form paket baru, mitra/ubah paket).
/// F-15 isi formulir, F-16 harga diskon harus lebih murah, F-17 porsi bilangan bulat positif,
/// F-18 ubah + hapus pakai konfirmasi, F-22 tandai buat Meja Berbagi
class FormPaket extends StatefulWidget {
  const FormPaket({this.idPaket, super.key});

  /// null = paket baru
  final String? idPaket;

  @override
  State<FormPaket> createState() => _FormPaketState();
}

class _FormPaketState extends State<FormPaket> {
  final nama = TextEditingController();
  final deskripsi = TextEditingController();
  final hargaAsli = TextEditingController();
  final hargaDiskon = TextEditingController();
  String? kategori;
  int porsi = 1;
  int? mulai;
  int? tutup;
  bool mejaBerbagi = false;
  Map<String, String?> galat = {};

  // dicari pakai where, bukan cari(), soalnya abis dihapus paketnya udah ga ada
  Map<String, dynamic>? get _lama => widget.idPaket == null
      ? null
      : context
            .read<PaketCubit>()
            .state
            .where((p) => p['id'] == widget.idPaket)
            .firstOrNull;

  @override
  void initState() {
    super.initState();
    final lama = _lama;
    if (lama != null) {
      nama.text = lama['nama'];
      deskripsi.text = lama['deskripsi'] ?? '';
      hargaAsli.text = '${lama['hargaAsli']}';
      hargaDiskon.text = '${lama['hargaDiskon']}';
      kategori = lama['kategori'];
      porsi = lama['totalPorsi'];
      mulai = lama['mulai'];
      tutup = lama['tutup'];
      mejaBerbagi = lama['mejaBerbagi'] == true;
    }
  }

  @override
  void dispose() {
    nama.dispose();
    deskripsi.dispose();
    hargaAsli.dispose();
    hargaDiskon.dispose();
    super.dispose();
  }

  Future<void> pilihJam({required bool buka}) async {
    final awal =
        (buka ? mulai : tutup) ?? (buka ? jamSekarang : jamSekarang + 120);
    final hasil = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: awal ~/ 60 % 24, minute: awal % 60),
      helpText: buka ? 'Jam buka ambil' : 'Jam tutup ambil',
    );
    if (hasil == null) return;
    setState(() {
      final menit = hasil.hour * 60 + hasil.minute;
      if (buka) {
        mulai = menit;
      } else {
        tutup = menit;
      }
      galat.remove('jam');
    });
  }

  /// cek isian, balikin true kalau semuanya bener
  bool periksa() {
    final g = <String, String?>{};
    final asli = int.tryParse(hargaAsli.text) ?? 0;
    final diskon = int.tryParse(hargaDiskon.text) ?? 0;
    if (nama.text.trim().isEmpty) g['nama'] = 'Nama paket wajib diisi.';
    if (kategori == null) g['kategori'] = 'Pilih satu kategori.';
    if (asli <= 0) g['hargaAsli'] = 'Isi harga asli.';
    if (diskon <= 0) {
      g['hargaDiskon'] = 'Isi harga diskon.';
    } else if (asli > 0 && diskon >= asli) {
      // F-16
      g['hargaDiskon'] = 'Harus lebih murah dari harga asli.';
    }
    if (mulai == null || tutup == null) {
      g['jam'] = 'Pilih jam buka dan tutup ambil.';
    } else if (tutup! <= mulai!) {
      g['jam'] = 'Jam tutup harus setelah jam buka.';
    } else if (tutup! <= jamSekarang) {
      g['jam'] = 'Jam tutup sudah lewat, paket tidak akan tampil.';
    }
    setState(() => galat = g);
    return g.isEmpty;
  }

  void simpan() {
    if (!periksa()) return;
    final isian = {
      'nama': nama.text.trim(),
      'deskripsi': deskripsi.text.trim(),
      'kategori': kategori,
      'hargaAsli': int.parse(hargaAsli.text),
      'hargaDiskon': int.parse(hargaDiskon.text),
      'totalPorsi': porsi,
      'mulai': mulai,
      'tutup': tutup,
      'mejaBerbagi': mejaBerbagi,
    };
    final cubit = context.read<PaketCubit>();
    final messenger = ScaffoldMessenger.of(context);
    if (widget.idPaket == null) {
      cubit.tambahPaket({
        ...isian,
        'mitra': context.read<AkunCubit>().state['nama'],
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text('${isian['nama']} terbit, langsung tampil ke pembeli'),
        ),
      );
    } else {
      cubit.ubahPaket(widget.idPaket!, isian);
      messenger.showSnackBar(
        const SnackBar(content: Text('Perubahan disimpan')),
      );
    }
    context.pop();
  }

  Future<void> hapus() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus paket?'),
        content: Text(
          '${nama.text} dihapus dari daftar dan tidak tampil lagi ke pembeli. Pesanan yang sudah dibayar tetap berjalan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Warna.merah),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted) return;
    context.read<PaketCubit>().hapusPaket(widget.idPaket!);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${nama.text} dihapus')));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final baru = widget.idPaket == null;
    final lama = _lama;

    return Scaffold(
      backgroundColor: Warna.latar,
      appBar: AppBar(
        backgroundColor: Warna.latar,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 4,
        leading: IconButton(
          tooltip: 'Tutup',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close),
        ),
        title: Text(
          baru ? 'Paket baru' : 'Ubah paket',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Warna.teks,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const _Label('Foto'),
          _KotakFoto(foto: lama?['foto']),
          const SizedBox(height: 20),

          const _Label('Nama paket'),
          TextField(
            controller: nama,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() => galat.remove('nama')),
            decoration: InputDecoration(
              hintText: 'Contoh: Paket Nasi Sore',
              errorText: galat['nama'],
            ),
          ),
          const SizedBox(height: 20),

          const _Label('Kategori'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in kategoriPaket)
                ChoiceChip(
                  label: Text(k),
                  selected: kategori == k,
                  showCheckmark: false,
                  onSelected: (_) => setState(() {
                    kategori = k;
                    galat.remove('kategori');
                  }),
                ),
            ],
          ),
          if (galat['kategori'] != null) _Galat(galat['kategori']!),
          const SizedBox(height: 20),

          const _Label('Deskripsi'),
          TextField(
            controller: deskripsi,
            maxLines: 3,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText:
                  'Contoh: nasi, dua lauk, sayur. Isinya berganti tiap hari.',
              helperText: 'Sebutkan isi & alergen bila ada.',
            ),
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('Harga asli'),
                    _KolomHarga(
                      kolom: hargaAsli,
                      galat: galat['hargaAsli'],
                      onChanged: () =>
                          setState(() => galat.remove('hargaAsli')),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('Harga diskon'),
                    _KolomHarga(
                      kolom: hargaDiskon,
                      galat: galat['hargaDiskon'],
                      bantuan: 'Harus lebih murah dari harga asli.',
                      onChanged: () =>
                          setState(() => galat.remove('hargaDiskon')),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          const _Label('Jumlah porsi'),
          // F-17: lewat tombol - + aja, jadi selalu bilangan bulat positif
          Container(
            width: 132,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Warna.garisKontrol),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Kurangi porsi',
                  onPressed: porsi > 1 ? () => setState(() => porsi--) : null,
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Text(
                    '$porsi',
                    key: const Key('jumlah-porsi'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Tambah porsi',
                  onPressed: porsi < 99 ? () => setState(() => porsi++) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const _Label('Jam ambil hari ini'),
          Row(
            children: [
              Expanded(
                child: _KolomJam(
                  label: 'Buka',
                  menit: mulai,
                  onTap: () => pilihJam(buka: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KolomJam(
                  label: 'Tutup',
                  menit: tutup,
                  onTap: () => pilihJam(buka: false),
                ),
              ),
            ],
          ),
          if (galat['jam'] != null) _Galat(galat['jam']!),
          const SizedBox(height: 20),

          // F-22: tandai buat donasi kalau ga terjual
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Donasikan bila tidak terjual',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Warna.teks,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Sisa porsi setelah jam tutup diserahkan ke Meja Berbagi. Kartu paket diberi badge.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Warna.teksPendukung,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: mejaBerbagi,
                  activeTrackColor: Warna.hijau,
                  onChanged: (nilai) => setState(() => mejaBerbagi = nilai),
                ),
              ],
            ),
          ),
          if (!baru) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: hapus,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Hapus paket'),
                style: TextButton.styleFrom(
                  foregroundColor: Warna.merah,
                  textStyle: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: simpan,
              style: FilledButton.styleFrom(
                backgroundColor: Warna.hijau,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                baru ? 'Terbitkan paket' : 'Simpan perubahan',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
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
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Warna.teks,
        ),
      ),
    );
  }
}

class _Galat extends StatelessWidget {
  const _Galat(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Text(
        teks,
        style: const TextStyle(fontSize: 12, color: Warna.merah),
      ),
    );
  }
}

/// kotak foto. unggah foto butuh tempat nyimpen (server), jadi sementara pakai foto contoh
class _KotakFoto extends StatelessWidget {
  const _KotakFoto({required this.foto});

  final String? foto;

  void _belum(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Unggah foto menyusul setelah server jadi, sementara pakai foto contoh',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (foto != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 170,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(foto!, fit: BoxFit.cover),
              Positioned(
                right: 10,
                bottom: 10,
                child: FilledButton.icon(
                  onPressed: () => _belum(context),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Ganti'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Warna.teks,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Warna.garisKontrol),
      ),
      child: InkWell(
        onTap: () => _belum(context),
        borderRadius: BorderRadius.circular(18),
        child: const SizedBox(
          height: 150,
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_camera_outlined, color: Warna.teks),
              SizedBox(height: 8),
              Text(
                'Ambil atau pilih foto',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Warna.teks,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Foto asli makanan hari ini, bukan foto menu.',
                style: TextStyle(fontSize: 12, color: Warna.teksPendukung),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KolomHarga extends StatelessWidget {
  const _KolomHarga({
    required this.kolom,
    required this.onChanged,
    this.galat,
    this.bantuan,
  });

  final TextEditingController kolom;
  final VoidCallback onChanged;
  final String? galat;
  final String? bantuan;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: kolom,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(7),
      ],
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        prefixText: 'Rp',
        hintText: '0',
        errorText: galat,
        errorMaxLines: 2,
        helperText: galat == null ? bantuan : null,
        helperMaxLines: 2,
      ),
    );
  }
}

class _KolomJam extends StatelessWidget {
  const _KolomJam({
    required this.label,
    required this.menit,
    required this.onTap,
  });

  final String label;
  final int? menit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Warna.garisKontrol),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Warna.teksPendukung,
                      ),
                    ),
                    Text(
                      menit == null ? 'Pilih jam' : jam(menit!),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: menit == null ? Warna.teksPendukung : Warna.teks,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.schedule, color: Warna.teks),
            ],
          ),
        ),
      ),
    );
  }
}
