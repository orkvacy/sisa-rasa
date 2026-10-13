import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/presentation/cubit/akun_cubit.dart';
import 'package:sisa_rasa/domain/repositories/layanan_akun.dart';
import 'package:sisa_rasa/presentation/router.dart';
import 'package:sisa_rasa/presentation/screens/auth/bagian_auth.dart';
import 'package:sisa_rasa/core/theme/warna.dart';
import 'package:sisa_rasa/domain/aturan/akun.dart';

/// daftar akun baru (figma v3: umum/daftar, F-29, F-65)
class Daftar extends StatefulWidget {
  const Daftar({this.dari, super.key});

  final String? dari;

  @override
  State<Daftar> createState() => _DaftarState();
}

class _DaftarState extends State<Daftar> {
  final nama = TextEditingController();
  final email = TextEditingController();
  final sandi = TextEditingController();
  String peran = 'pembeli';
  bool setuju = false;
  late final _bukaKetentuan = TapGestureRecognizer()
    ..onTap = () => context.push(Rute.ketentuan);
  bool memuat = false;
  Map<String, String?> galat = {};

  // tamu yg mau checkout pasti mau beli, mitra ga perlu ditawarin
  bool get _dariCheckout => widget.dari != null;

  @override
  void dispose() {
    nama.dispose();
    email.dispose();
    sandi.dispose();
    _bukaKetentuan.dispose();
    super.dispose();
  }

  Future<void> kirim() async {
    FocusScope.of(context).unfocus();
    final g = <String, String?>{};
    if (nama.text.trim().length < 2) g['nama'] = 'Isi nama kamu.';
    if (!emailValid(email.text)) g['email'] = 'Format email belum benar.';
    if (sandi.text.length < panjangSandiMinimal) {
      g['sandi'] = 'Minimal $panjangSandiMinimal karakter.';
    }
    // F-65: wajib setuju ketentuan sebelum bisa daftar
    if (!setuju) g['setuju'] = 'Setujui Ketentuan & Kebijakan privasi dulu.';
    setState(() => galat = g);
    if (g.isNotEmpty) return;

    setState(() => memuat = true);
    try {
      await context.read<AkunCubit>().daftar(
        nama: nama.text,
        email: email.text,
        sandi: sandi.text,
        peran: peran,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Akun dibuat. Selamat datang, ${nama.text}!')),
        );
    } on GagalAkun catch (e) {
      if (mounted) setState(() => galat = {'email': e.pesan});
    } finally {
      if (mounted) setState(() => memuat = false);
    }
  }

  void kembali() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(context.read<AkunCubit>().tamu ? Rute.beranda : Rute.sambutan);
    }
  }

  String _bantuanSandi() {
    final sisa = panjangSandiMinimal - sandi.text.length;
    if (sandi.text.isEmpty) return 'Minimal $panjangSandiMinimal karakter.';
    if (sisa > 0) {
      return 'Minimal $panjangSandiMinimal karakter. Sisa $sisa lagi.';
    }
    return 'Panjang kata sandi sudah cukup.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Warna.latar,
      appBar: AppBar(
        backgroundColor: Warna.latar,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Kembali',
          onPressed: kembali,
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
      ),
      body: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            const JudulAuth('Buat akun'),
            if (!_dariCheckout) ...[
              const SizedBox(height: 16),
              const LabelAuth('Kamu mendaftar sebagai'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _KartuPeran(
                      ikon: Icons.person_outline,
                      judul: 'Pembeli',
                      keterangan: 'Cari paket murah di sekitar',
                      dipilih: peran == 'pembeli',
                      onTap: () => setState(() => peran = 'pembeli'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _KartuPeran(
                      ikon: Icons.storefront_outlined,
                      judul: 'Mitra usaha',
                      keterangan: 'Jual sisa dapur usahamu',
                      dipilih: peran == 'mitra',
                      onTap: () => setState(() => peran = 'mitra'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Peran tidak bisa diubah setelah akun dibuat.',
                style: TextStyle(fontSize: 12, color: Warna.teksPendukung),
              ),
            ],
            const SizedBox(height: 20),
            LabelAuth(peran == 'mitra' ? 'Nama usaha' : 'Nama'),
            TextField(
              controller: nama,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              onChanged: (_) => setState(() => galat.remove('nama')),
              decoration: InputDecoration(
                hintText: peran == 'mitra' ? 'Contoh: Ibis Hotel' : 'Nama kamu',
                errorText: galat['nama'],
              ),
            ),
            const SizedBox(height: 20),
            const LabelAuth('Email'),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              onChanged: (_) => setState(() => galat.remove('email')),
              decoration: InputDecoration(
                hintText: 'nama@email.com',
                errorText: galat['email'],
              ),
            ),
            const SizedBox(height: 20),
            const LabelAuth('Kata sandi'),
            KolomSandi(
              kolom: sandi,
              galat: galat['sandi'],
              bantuan: _bantuanSandi(),
              onChanged: (_) => setState(() => galat.remove('sandi')),
            ),
            const SizedBox(height: 12),
            // F-65: setuju ketentuan, tautannya buka halaman Ketentuan
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: setuju,
                  activeColor: Warna.hijau,
                  side: BorderSide(
                    color: galat['setuju'] != null
                        ? Warna.merah
                        : Warna.garisKontrol,
                    width: 1.5,
                  ),
                  onChanged: (nilai) => setState(() {
                    setuju = nilai!;
                    galat.remove('setuju');
                  }),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          color: Warna.teks,
                        ),
                        children: [
                          const TextSpan(text: 'Saya setuju dengan '),
                          TextSpan(
                            text: 'Ketentuan & Kebijakan privasi',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Warna.hijau,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: _bukaKetentuan,
                          ),
                          const TextSpan(text: ' Sisa Rasa.'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (galat['setuju'] != null)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 4),
                child: Text(
                  galat['setuju']!,
                  style: const TextStyle(fontSize: 12, color: Warna.merah),
                ),
              ),
            const SizedBox(height: 16),
            TombolAuth(label: 'Buat akun', memuat: memuat, onPressed: kirim),
            const SizedBox(height: 24),
            TautanBawah(
              teks: 'Sudah punya akun?',
              aksi: 'Masuk',
              onTap: () => context.pushReplacement(
                widget.dari == null ? Rute.masuk : Rute.masukLalu(widget.dari!),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KartuPeran extends StatelessWidget {
  const _KartuPeran({
    required this.ikon,
    required this.judul,
    required this.keterangan,
    required this.dipilih,
    required this.onTap,
  });

  final IconData ikon;
  final String judul;
  final String keterangan;
  final bool dipilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: dipilih,
      button: true,
      child: Material(
        color: dipilih ? Warna.softGreen : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: dipilih ? Warna.hijau : Warna.garis,
            width: dipilih ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(ikon, color: Warna.hijau),
                const SizedBox(height: 10),
                Text(
                  judul,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Warna.teks,
                  ),
                ),
                const SizedBox(height: 4),
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
        ),
      ),
    );
  }
}
