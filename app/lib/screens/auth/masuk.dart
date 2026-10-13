import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/cubit/akun_cubit.dart';
import 'package:sisa_rasa/data/layanan_akun.dart';
import 'package:sisa_rasa/router.dart';
import 'package:sisa_rasa/screens/auth/bagian_auth.dart';
import 'package:sisa_rasa/theme/warna.dart';

/// masuk pakai email + kata sandi (figma v3: umum/masuk, F-30).
/// peran ga dipilih di sini, ikut dari akunnya (F-26)
class Masuk extends StatefulWidget {
  const Masuk({this.dari, super.key});

  /// halaman tujuan abis masuk, diisi router kalau tamu mau buka halaman yg butuh akun
  final String? dari;

  @override
  State<Masuk> createState() => _MasukState();
}

class _MasukState extends State<Masuk> {
  final email = TextEditingController();
  final sandi = TextEditingController();
  String? galatEmail;
  String? galatMasuk;
  bool memuat = false;

  @override
  void dispose() {
    email.dispose();
    sandi.dispose();
    super.dispose();
  }

  Future<void> kirim() async {
    FocusScope.of(context).unfocus();
    setState(() {
      galatEmail = emailValid(email.text) ? null : 'Format email belum benar.';
      galatMasuk = null;
    });
    if (galatEmail != null) return;
    if (sandi.text.isEmpty) {
      setState(() => galatMasuk = 'Isi kata sandi dulu.');
      return;
    }

    setState(() => memuat = true);
    try {
      // abis berhasil, router yg mindahin ke beranda / dasbor / halaman [dari]
      await context.read<AkunCubit>().masuk(email.text, sandi.text);
    } on GagalAkun catch (e) {
      if (mounted) setState(() => galatMasuk = e.pesan);
    } finally {
      if (mounted) setState(() => memuat = false);
    }
  }

  /// F-61: email dioper lewat extra, bukan alamat, biar ga nongol di URL
  Future<void> lupaSandi() async {
    final hasil = await context.push<String>(
      Rute.lupaSandi,
      extra: email.text.trim(),
    );
    if (hasil == null || !mounted) return;
    setState(() {
      email.text = hasil;
      sandi.clear();
      galatMasuk = null;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Kata sandi diganti. Masuk dengan kata sandi baru.'),
        ),
      );
  }

  void kembali() {
    if (context.canPop()) {
      context.pop();
    } else {
      // dibuka lewat redirect (tamu buka Pesanan / checkout), ga ada yg bisa di-pop
      context.go(context.read<AkunCubit>().tamu ? Rute.beranda : Rute.sambutan);
    }
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
            const JudulAuth('Masuk'),
            const SizedBox(height: 6),
            Text(
              widget.dari == null
                  ? 'Pakai email yang kamu daftarkan. Peranmu (pembeli atau mitra) ikut dari akun.'
                  : 'Masuk dulu untuk lanjut. Isi keranjangmu tetap tersimpan.',
              style: const TextStyle(
                fontSize: 15,
                height: 22 / 15,
                color: Warna.teksPendukung,
              ),
            ),
            if (galatMasuk != null) ...[
              const SizedBox(height: 16),
              KotakGalat(galatMasuk!),
            ],
            const SizedBox(height: 20),
            const LabelAuth('Email'),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              onChanged: (_) {
                if (galatEmail != null) setState(() => galatEmail = null);
              },
              decoration: InputDecoration(
                hintText: 'nama@email.com',
                errorText: galatEmail,
              ),
            ),
            const SizedBox(height: 20),
            const LabelAuth('Kata sandi'),
            KolomSandi(
              kolom: sandi,
              adaGalat: galatMasuk != null,
              onSubmitted: (_) => kirim(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: lupaSandi,
                style: TextButton.styleFrom(
                  foregroundColor: Warna.hijau,
                  textStyle: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Lupa kata sandi?'),
              ),
            ),
            const SizedBox(height: 8),
            TombolAuth(label: 'Masuk', memuat: memuat, onPressed: kirim),
            const SizedBox(height: 24),
            TautanBawah(
              teks: 'Belum punya akun?',
              aksi: 'Daftar',
              onTap: () =>
                  context.pushReplacement(Rute.daftarLalu(widget.dari)),
            ),
          ],
        ),
      ),
    );
  }
}
