import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/presentation/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/domain/repositories/layanan_akun.dart';
import 'package:sisa_rasa/presentation/cubit/akun_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/keranjang_cubit.dart';
import 'package:sisa_rasa/presentation/router.dart';
import 'package:sisa_rasa/core/theme/teks.dart';
import 'package:sisa_rasa/core/theme/warna.dart';
import 'package:sisa_rasa/core/utils/format.dart';
import 'package:sisa_rasa/presentation/widgets/navigasi_bawah.dart';

/// tab akun: profil, kartu dampak, sama menu setelan
class Akun extends StatelessWidget {
  const Akun({super.key});

  @override
  Widget build(BuildContext context) {
    // sesaat abis keluar, layar ini masih sempet digambar sekali sebelum router pindah
    final akun = context.watch<AkunCubit>().state;
    if (akun['id'] == null) return const SizedBox.shrink();
    final daftarPesanan = PesananBloc.milik(
      context.watch<PesananBloc>().state,
      akun['id']!,
    );
    var porsi = 0;
    var hemat = 0;
    for (final pesanan in daftarPesanan) {
      // cuma yg udah dibayar (udah punya kode ambil), yg batal / belum bayar ga dihitung
      if (pesanan['kode'] == null) continue;
      porsi += pesanan['porsi'] as int;
      hemat += pesanan['hemat'] as int;
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          NavigasiBawah.ruangBawah,
        ),
        children: [
          Row(
            children: [
              // dibuka dari dasbor mitra (bukan tab), jadi perlu tombol kembali
              if (GoRouter.of(context).canPop())
                IconButton(
                  tooltip: 'Kembali',
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                ),
              const Expanded(
                child: Text(
                  'Akun',
                  style: TextStyle(
                    fontSize: Teks.judul,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              // kDebugMode: tombol ini cuma ada pas flutter run / test,
              // di build rilis (flutter build apk) otomatis ilang
              if (kDebugMode) const _TombolGantiAkun(),
            ],
          ),
          const SizedBox(height: 16),
          // Material dipake buat latar kartu, soalnya kalau Container berwarna efek pencet ListTile nya ketutup
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            // ListTile: baris siap pakai, ada leading (kiri), title, subtitle, trailing (kanan)
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              onTap: () => _ubahProfil(context),
              // CircleAvatar: lingkaran isi inisial nama, gantiin foto profil
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: Warna.softGreen,
                child: Text(
                  inisial(akun['nama']!),
                  style: const TextStyle(
                    fontSize: Teks.nama,
                    fontWeight: FontWeight.w800,
                    color: Warna.hijau,
                  ),
                ),
              ),
              title: Text(
                akun['nama']!,
                style: const TextStyle(
                  fontSize: Teks.nama,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(akun['email']!),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Warna.softGreen,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      namaPeran(akun['peran']!),
                      style: const TextStyle(
                        fontSize: Teks.kecil,
                        fontWeight: FontWeight.w700,
                        color: Warna.hijau,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 12),

          // kartu dampak, dihitung dari pesanan yg udah dibuat.
          // khusus pembeli, dampak mitra udah ada di dasbornya
          if (akun['peran'] == 'pembeli') ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Warna.kartu,
                border: Border.all(color: Warna.garis),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.eco_outlined, size: 18, color: Warna.hijau),
                      SizedBox(width: 8),
                      Text(
                        'Dampakmu hari ini',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Warna.teks,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$porsi',
                              style: const TextStyle(
                                fontSize: Teks.subjudul,
                                fontWeight: FontWeight.w800,
                                color: Warna.hijau,
                              ),
                            ),
                            const Text(
                              'porsi terselamatkan',
                              style: TextStyle(
                                fontSize: Teks.kecil,
                                color: Warna.teksPendukung,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rupiah(hemat),
                              style: const TextStyle(
                                fontSize: Teks.subjudul,
                                fontWeight: FontWeight.w800,
                                color: Warna.hijau,
                              ),
                            ),
                            const Text(
                              'kamu hemat',
                              style: TextStyle(
                                fontSize: Teks.kecil,
                                color: Warna.teksPendukung,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ] else
            const SizedBox(height: 8),

          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              'Akun',
              style: TextStyle(
                fontSize: Teks.keterangan,
                fontWeight: FontWeight.w700,
                color: Warna.teksPendukung,
              ),
            ),
          ),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _BarisMenu(
                  ikon: Icons.person_outline,
                  judul: 'Profil',
                  onTap: () => _ubahProfil(context),
                ),
                const _BarisMenu(
                  ikon: Icons.mail_outline,
                  judul: 'Email',
                  nilai: 'Terverifikasi',
                ),
                const _BarisMenu(ikon: Icons.lock_outline, judul: 'Kata sandi'),
                // F-62: akun mitra ditutup lewat tim (masih ada saldo + rekening)
                if (akun['peran'] == 'pembeli')
                  _BarisMenu(
                    ikon: Icons.delete_outline,
                    judul: 'Hapus akun',
                    warna: Warna.merah,
                    onTap: () => _hapusAkun(context),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              'Preferensi',
              style: TextStyle(
                fontSize: Teks.keterangan,
                fontWeight: FontWeight.w700,
                color: Warna.teksPendukung,
              ),
            ),
          ),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: const Column(
              children: [
                _BarisMenu(
                  ikon: Icons.dark_mode_outlined,
                  judul: 'Tampilan',
                  nilai: 'Ikuti sistem',
                ),
                _BarisMenu(
                  ikon: Icons.favorite_border,
                  judul: 'Mitra favorit',
                  nilai: '3',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              'Lainnya',
              style: TextStyle(
                fontSize: Teks.keterangan,
                fontWeight: FontWeight.w700,
                color: Warna.teksPendukung,
              ),
            ),
          ),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const _BarisMenu(ikon: Icons.help_outline, judul: 'Bantuan'),
                _BarisMenu(
                  ikon: Icons.description_outlined,
                  judul: 'Ketentuan & privasi',
                  onTap: () => context.push(Rute.ketentuan),
                ),
                _BarisMenu(
                  ikon: Icons.logout,
                  judul: 'Keluar',
                  onTap: () => _keluar(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// F-63: pembeli ganti nama. nama mitra = nama gerai yang nempel di paket,
/// pesanan, dan rekening, jadi gantinya lewat tim Sisa Rasa
void _ubahProfil(BuildContext context) {
  final akun = context.read<AkunCubit>().state;
  if (akun['peran'] != 'pembeli') {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Nama usaha diubah lewat tim Sisa Rasa, karena terhubung ke paket dan rekening.',
          ),
        ),
      );
    return;
  }
  showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<AkunCubit>(),
      child: _DialogUbahNama(namaSekarang: akun['nama']!),
    ),
  );
}

/// F-62: minta sandi lagi, lalu data akun dihapus dan semua sesi dicabut
void _hapusAkun(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: context.read<AkunCubit>()),
        BlocProvider.value(value: context.read<KeranjangCubit>()),
      ],
      child: const _DialogHapusAkun(),
    ),
  );
}

class _DialogUbahNama extends StatefulWidget {
  const _DialogUbahNama({required this.namaSekarang});

  final String namaSekarang;

  @override
  State<_DialogUbahNama> createState() => _DialogUbahNamaState();
}

class _DialogUbahNamaState extends State<_DialogUbahNama> {
  late final nama = TextEditingController(text: widget.namaSekarang);
  String? galat;
  bool menyimpan = false;

  @override
  void dispose() {
    nama.dispose();
    super.dispose();
  }

  Future<void> simpan() async {
    setState(() {
      menyimpan = true;
      galat = null;
    });
    try {
      await context.read<AkunCubit>().ubahNama(nama.text);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('Nama disimpan')));
    } on GagalAkun catch (e) {
      if (mounted) setState(() => galat = e.pesan);
    } finally {
      if (mounted) setState(() => menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ubah nama'),
      content: TextField(
        controller: nama,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        maxLength: 60,
        decoration: InputDecoration(
          labelText: 'Nama lengkap',
          errorText: galat,
        ),
        onSubmitted: (_) => simpan(),
      ),
      actions: [
        TextButton(
          onPressed: menyimpan ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: menyimpan ? null : simpan,
          child: Text(menyimpan ? 'Menyimpan…' : 'Simpan'),
        ),
      ],
    );
  }
}

class _DialogHapusAkun extends StatefulWidget {
  const _DialogHapusAkun();

  @override
  State<_DialogHapusAkun> createState() => _DialogHapusAkunState();
}

class _DialogHapusAkunState extends State<_DialogHapusAkun> {
  final sandi = TextEditingController();
  String? galat;
  bool menghapus = false;

  @override
  void dispose() {
    sandi.dispose();
    super.dispose();
  }

  Future<void> hapus() async {
    setState(() {
      menghapus = true;
      galat = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final keranjang = context.read<KeranjangCubit>();
    final akun = context.read<AkunCubit>();
    try {
      if (akun.tanpaSandi) {
        // akun Google: konfirmasinya pilih akun Google yang sama lagi
        if (!await akun.hapusAkunGoogle()) {
          if (mounted) setState(() => menghapus = false);
          return;
        }
      } else {
        await akun.hapusAkun(sandi.text);
      }
      keranjang.kosongkan();
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Akunmu sudah dihapus')),
      );
    } on GagalAkun catch (e) {
      if (mounted) {
        setState(() {
          galat = e.pesan;
          menghapus = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tanpaSandi = context.read<AkunCubit>().tanpaSandi;
    return AlertDialog(
      title: const Text('Hapus akun?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nama, email, dan kata sandimu dihapus, dan akun ini tidak bisa dipakai lagi. '
            'Riwayat transaksi tetap disimpan tanpa namamu karena wajib dicatat. '
            'Tindakan ini tidak bisa dibatalkan.',
          ),
          const SizedBox(height: 16),
          if (tanpaSandi) ...[
            const Text(
              'Kamu masuk dengan Google. Pilih akun Google yang sama untuk konfirmasi.',
              style: TextStyle(color: Warna.teksPendukung),
            ),
            if (galat != null) ...[
              const SizedBox(height: 8),
              Text(galat!, style: const TextStyle(color: Warna.merah)),
            ],
          ] else
            TextField(
              controller: sandi,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Kata sandi',
                helperText: 'Masukkan kata sandi untuk konfirmasi',
                errorText: galat,
                errorMaxLines: 3,
              ),
              onSubmitted: (_) => hapus(),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: menghapus ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: menghapus ? null : hapus,
          style: TextButton.styleFrom(foregroundColor: Warna.merah),
          child: Text(
            menghapus
                ? 'Menghapus…'
                : tanpaSandi
                ? 'Konfirmasi dengan Google'
                : 'Hapus akun',
          ),
        ),
      ],
    );
  }
}

/// F-33: konfirmasi dulu, terus token sesinya dicabut
Future<void> _keluar(BuildContext context) async {
  final yakin = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Keluar dari akun?'),
      content: const Text(
        'Pesanan aktifmu tetap tersimpan. Masuk lagi untuk melihat kodenya.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(foregroundColor: Warna.merah),
          child: const Text('Keluar'),
        ),
      ],
    ),
  );
  if (yakin != true || !context.mounted) return;
  // keranjang ga ikut ke akun berikutnya yg masuk di HP ini
  context.read<KeranjangCubit>().kosongkan();
  // router langsung pindah ke Sambutan begitu akunnya kosong
  await context.read<AkunCubit>().keluar();
}

/// tombol pindah akun cepet selama testing, gantiin logout - login
class _TombolGantiAkun extends StatelessWidget {
  const _TombolGantiAkun();

  void _pilih(BuildContext context) {
    final aktif = context.read<AkunCubit>().state['id'];
    // diambil sekarang, jangan di dalam builder: pas ganti akun halaman ini udah ketutup
    final daftarAkun = context.read<AkunCubit>().layanan.akunUji;
    // showModalBottomSheet: lembar dari bawah, isinya daftar akun uji
    showModalBottomSheet<void>(
      context: context,
      // useRootNavigator: dibuka di atas navigasi bawah, kalau ga bawahnya ketutup
      useRootNavigator: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        // bisa digulir, layar pendek / landscape ga muat semua akun
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 4),
                child: Text(
                  'Ganti akun',
                  style: TextStyle(
                    fontSize: Teks.subjudul,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  'Khusus mode uji. Keranjang dikosongkan saat pindah akun.',
                  style: TextStyle(
                    fontSize: Teks.keterangan,
                    color: Warna.teksPendukung,
                  ),
                ),
              ),
              for (final akun in daftarAkun)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: CircleAvatar(
                    backgroundColor: Warna.softGreen,
                    child: Text(
                      inisial(akun['nama']!),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Warna.hijau,
                      ),
                    ),
                  ),
                  title: Text(
                    akun['nama']!,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${namaPeran(akun['peran']!)} · ${akun['email']}',
                  ),
                  trailing: akun['id'] == aktif
                      ? const Icon(Icons.check_circle, color: Warna.hijau)
                      : null,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    if (akun['id'] == aktif) return;
                    // diambil dulu sebelum ganti akun: kalau perannya beda,
                    // router langsung pindah ke halaman peran baru dan layar ini ketutup
                    final messenger = ScaffoldMessenger.of(context);
                    final keranjang = context.read<KeranjangCubit>();
                    final akunCubit = context.read<AkunCubit>();
                    // halaman akun yg dibuka dari dasbor mitra ditutup dulu,
                    // biar ga sempet digambar ulang pake akun peran lain
                    if (GoRouter.of(context).canPop()) context.pop();
                    keranjang.kosongkan();
                    akunCubit.ganti(akun['id']!);
                    messenger
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text('Masuk sebagai ${akun['nama']}'),
                        ),
                      );
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _pilih(context),
      icon: const Icon(Icons.swap_horiz, size: 18),
      label: const Text('Ganti akun'),
      style: TextButton.styleFrom(
        foregroundColor: Warna.hijau,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        textStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// satu baris menu di tab akun
class _BarisMenu extends StatelessWidget {
  const _BarisMenu({
    required this.ikon,
    required this.judul,
    this.nilai,
    this.onTap,
    this.warna = Warna.teks,
  });

  final IconData ikon;
  final String judul;
  final String? nilai;

  /// warna ikon + judul, merah buat aksi berbahaya (Hapus akun)
  final Color warna;

  /// kosong = halamannya belum ada, cuma munculin snackbar
  final VoidCallback? onTap;

  static void segeraHadir(BuildContext context, String menu) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$menu belum tersedia di versi ini')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(ikon, color: warna),
      title: Text(judul, style: TextStyle(color: warna)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (nilai != null)
            Text(nilai!, style: const TextStyle(color: Warna.teksPendukung)),
          const Icon(Icons.chevron_right, color: Warna.teksPendukung),
        ],
      ),
      onTap: onTap ?? () => segeraHadir(context, judul),
    );
  }
}
