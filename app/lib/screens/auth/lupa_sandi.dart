import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/cubit/akun_cubit.dart';
import 'package:sisa_rasa/data/layanan_akun.dart';
import 'package:sisa_rasa/screens/auth/bagian_auth.dart';
import 'package:sisa_rasa/theme/warna.dart';

/// atur ulang kata sandi lewat kode OTP di email (figma v3: umum/lupa kata sandi, F-61).
/// tiga langkah di satu layar: email -> kode -> kata sandi baru.
/// sengaja ga dipecah jadi tiga alamat, biar email sama tiket reset ga nongol di URL.
/// abis berhasil, layar ditutup dan ngebalikin email-nya ke layar Masuk
class LupaSandi extends StatefulWidget {
  const LupaSandi({this.email, super.key});

  /// email yg udah diketik di layar Masuk, biar ga ngetik ulang
  final String? email;

  @override
  State<LupaSandi> createState() => _LupaSandiState();
}

class _LupaSandiState extends State<LupaSandi> {
  late final email = TextEditingController(text: widget.email);
  final kode = TextEditingController();
  final sandi = TextEditingController();
  final ulangi = TextEditingController();

  int langkah = 0;
  bool memuat = false;
  String? galat;
  String? tiket;
  int sisaDetik = 0;
  Timer? _hitungMundur;

  LayananAkun get _layanan => context.read<AkunCubit>().layanan;

  @override
  void dispose() {
    _hitungMundur?.cancel();
    email.dispose();
    kode.dispose();
    sandi.dispose();
    ulangi.dispose();
    super.dispose();
  }

  void _mulaiHitungMundur() {
    _hitungMundur?.cancel();
    setState(() => sisaDetik = jedaKirimUlang.inSeconds);
    _hitungMundur = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => sisaDetik--);
      if (sisaDetik <= 0) t.cancel();
    });
  }

  /// jalanin [aksi], galatnya ditampilin di layar
  Future<void> _jalankan(Future<void> Function() aksi) async {
    FocusScope.of(context).unfocus();
    setState(() {
      memuat = true;
      galat = null;
    });
    try {
      await aksi();
    } on GagalAkun catch (e) {
      if (mounted) setState(() => galat = e.pesan);
    } finally {
      if (mounted) setState(() => memuat = false);
    }
  }

  Future<void> kirimKode() async {
    if (!emailValid(email.text)) {
      setState(() => galat = 'Format email belum benar.');
      return;
    }
    await _jalankan(() async {
      await _layanan.mintaKodeReset(email.text);
      kode.clear();
      setState(() => langkah = 1);
      _mulaiHitungMundur();
    });
  }

  Future<void> kirimUlang() => _jalankan(() async {
    await _layanan.mintaKodeReset(email.text);
    kode.clear();
    _mulaiHitungMundur();
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Kode baru dikirim')));
    }
  });

  Future<void> verifikasi() => _jalankan(() async {
    tiket = await _layanan.cekKodeReset(email.text, kode.text);
    _hitungMundur?.cancel();
    setState(() => langkah = 2);
  });

  Future<void> simpan() async {
    if (sandi.text.length < panjangSandiMinimal) {
      setState(() => galat = 'Minimal $panjangSandiMinimal karakter.');
      return;
    }
    if (ulangi.text != sandi.text) {
      setState(() => galat = 'Belum sama dengan kata sandi baru.');
      return;
    }
    await _jalankan(() async {
      await _layanan.aturSandiBaru(tiket!, sandi.text);
      if (mounted) context.pop(rapikanEmail(email.text));
    });
  }

  void kembali() {
    if (langkah == 0) {
      context.pop();
      return;
    }
    _hitungMundur?.cancel();
    setState(() {
      // dari langkah kata sandi baru balik ke awal, tiketnya udah sekali pakai
      langkah = 0;
      galat = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // tombol kembali HP mundur satu langkah dulu, bukan langsung nutup layar
      canPop: langkah == 0,
      onPopInvokedWithResult: (sudah, _) {
        if (!sudah) kembali();
      },
      child: Scaffold(
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
        body: switch (langkah) {
          0 => _langkahEmail(),
          1 => _langkahKode(),
          _ => _langkahSandi(),
        },
      ),
    );
  }

  Widget _keterangan(String teks) => Text(
    teks,
    style: const TextStyle(
      fontSize: 15,
      height: 22 / 15,
      color: Warna.teksPendukung,
    ),
  );

  Widget _langkahEmail() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              const JudulAuth('Atur ulang kata sandi'),
              const SizedBox(height: 6),
              _keterangan(
                'Masukkan email akunmu. Kami kirim kode 6 digit untuk memastikan itu kamu.',
              ),
              const SizedBox(height: 20),
              const LabelAuth('Email'),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                onChanged: (_) {
                  if (galat != null) setState(() => galat = null);
                },
                onSubmitted: (_) => kirimKode(),
                decoration: InputDecoration(
                  hintText: 'nama@email.com',
                  errorText: galat,
                  errorMaxLines: 2,
                ),
              ),
              const SizedBox(height: 16),
              TombolAuth(
                label: 'Kirim kode',
                memuat: memuat,
                onPressed: kirimKode,
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: const Icon(Icons.help_outline, color: Warna.teks),
                title: const Text(
                  'Tidak bisa buka email?',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Hubungi admin Sisa Rasa, sertakan nama dan email akunmu.',
                ),
                trailing: const Icon(Icons.mail_outline, color: Warna.teks),
                onTap: () => ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Kontak admin menyusul di menu Bantuan'),
                    ),
                  ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _langkahKode() {
    final layanan = _layanan;
    // mode uji: email belum beneran dikirim, jadi kodenya ditunjukin di sini
    final kodeUji = layanan is AkunTiruan ? layanan.kodeUji(email.text) : null;
    final lengkap = kode.text.length == 6;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        const JudulAuth('Masukkan kode'),
        const SizedBox(height: 6),
        _keterangan(
          'Kode 6 digit dikirim ke ${samarkanEmail(email.text)}. Cek juga folder spam.',
        ),
        if (kodeUji != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Warna.mendesakLembut,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Mode uji: email belum benar-benar dikirim. Kodenya $kodeUji',
              key: const Key('kode-uji'),
              style: const TextStyle(fontSize: 13, color: Warna.mendesak),
            ),
          ),
        ],
        const SizedBox(height: 20),
        _KotakKode(
          kolom: kode,
          galat: galat != null,
          onChanged: () => setState(() => galat = null),
          onLengkap: verifikasi,
        ),
        if (galat != null) ...[
          const SizedBox(height: 8),
          Text(
            galat!,
            style: const TextStyle(fontSize: 13, color: Warna.merah),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Belum dapat kode? ',
              style: TextStyle(color: Warna.teksPendukung),
            ),
            if (sisaDetik > 0)
              Text(
                'Kirim ulang dalam 0:${sisaDetik.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Warna.teks,
                ),
              )
            else
              TextButton(
                onPressed: memuat ? null : kirimUlang,
                style: TextButton.styleFrom(
                  foregroundColor: Warna.hijau,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                ),
                child: const Text(
                  'Kirim ulang',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TombolAuth(
          label: 'Verifikasi',
          memuat: memuat,
          onPressed: lengkap ? verifikasi : null,
        ),
      ],
    );
  }

  Widget _langkahSandi() {
    final belumSama = galat == 'Belum sama dengan kata sandi baru.'
        ? galat
        : null;
    final galatLain = belumSama == null ? galat : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        const JudulAuth('Buat kata sandi baru'),
        const SizedBox(height: 20),
        const LabelAuth('Kata sandi baru'),
        KolomSandi(
          kolom: sandi,
          galat: galatLain,
          bantuan: 'Minimal $panjangSandiMinimal karakter.',
          onChanged: (_) => setState(() => galat = null),
        ),
        const SizedBox(height: 20),
        const LabelAuth('Ulangi kata sandi baru'),
        KolomSandi(
          kolom: ulangi,
          galat: belumSama,
          onChanged: (_) => setState(() => galat = null),
          onSubmitted: (_) => simpan(),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Warna.softGreen,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 20, color: Warna.hijau),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Setelah disimpan, semua perangkat lain yang masuk ke akunmu akan dikeluarkan.',
                  style: TextStyle(fontSize: 13, color: Warna.hijau),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TombolAuth(
          label: 'Simpan kata sandi',
          memuat: memuat,
          onPressed: simpan,
        ),
      ],
    );
  }
}

/// enam kotak angka OTP. aslinya satu TextField tak terlihat,
/// kotak-kotaknya cuma nampilin isinya (biar tempel kode 6 digit tetep jalan)
class _KotakKode extends StatefulWidget {
  const _KotakKode({
    required this.kolom,
    required this.galat,
    required this.onChanged,
    required this.onLengkap,
  });

  final TextEditingController kolom;
  final bool galat;
  final VoidCallback onChanged;
  final VoidCallback onLengkap;

  @override
  State<_KotakKode> createState() => _KotakKodeState();
}

class _KotakKodeState extends State<_KotakKode> {
  final fokus = FocusNode();

  @override
  void initState() {
    super.initState();
    fokus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    fokus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isi = widget.kolom.text;
    return Stack(
      children: [
        // TextField asli, transparan, nutupin kotak-kotaknya biar bisa dipencet
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              key: const Key('kolom-kode'),
              controller: widget.kolom,
              focusNode: fokus,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              showCursor: false,
              onChanged: (teks) {
                widget.onChanged();
                if (teks.length == 6) widget.onLengkap();
              },
            ),
          ),
        ),
        IgnorePointer(
          child: Row(
            children: [
              for (var i = 0; i < 6; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 0.85,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: widget.galat
                              ? Warna.merah
                              : fokus.hasFocus && i == isi.length
                              ? Warna.hijau
                              : Warna.garisKontrol,
                          width:
                              widget.galat ||
                                  (fokus.hasFocus && i == isi.length)
                              ? 2
                              : 1,
                        ),
                      ),
                      child: Text(
                        i < isi.length ? isi[i] : '',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Warna.teks,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
