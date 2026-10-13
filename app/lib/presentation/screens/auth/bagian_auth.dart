import 'package:flutter/material.dart';
import 'package:sisa_rasa/core/theme/warna.dart';

/// potongan yg dipake bareng layar Masuk dan Daftar (figma v3: umum/masuk, umum/daftar)

class JudulAuth extends StatelessWidget {
  const JudulAuth(this.teks, {super.key});

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Text(
      teks,
      style: const TextStyle(
        fontSize: 32,
        height: 40 / 32,
        letterSpacing: -0.6,
        fontWeight: FontWeight.w800,
        color: Warna.teks,
      ),
    );
  }
}

class LabelAuth extends StatelessWidget {
  const LabelAuth(this.teks, {super.key});

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

/// kolom kata sandi dengan tombol mata buat nampilin / nyembunyiin isinya
class KolomSandi extends StatefulWidget {
  const KolomSandi({
    required this.kolom,
    this.galat,
    this.bantuan,
    this.adaGalat = false,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController kolom;
  final String? galat;
  final String? bantuan;

  /// garis merah tanpa teks galat (teksnya udah ditampilin di kotak atas)
  final bool adaGalat;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<KolomSandi> createState() => _KolomSandiState();
}

class _KolomSandiState extends State<KolomSandi> {
  bool tampil = false;

  @override
  Widget build(BuildContext context) {
    // garis merah diambil dari tema, biar sama kayak kolom galat lain
    final tema = Theme.of(context).inputDecorationTheme;
    return TextField(
      controller: widget.kolom,
      obscureText: !tampil,
      autocorrect: false,
      enableSuggestions: false,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      autofillHints: const [AutofillHints.password],
      decoration: InputDecoration(
        errorText: widget.galat,
        helperText: widget.bantuan,
        helperMaxLines: 2,
        enabledBorder: widget.adaGalat ? tema.errorBorder : null,
        focusedBorder: widget.adaGalat ? tema.focusedErrorBorder : null,
        suffixIcon: IconButton(
          tooltip: tampil ? 'Sembunyikan kata sandi' : 'Tampilkan kata sandi',
          onPressed: () => setState(() => tampil = !tampil),
          icon: Icon(
            tampil ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
        ),
      ),
    );
  }
}

/// tombol hijau besar selebar layar, nampilin muter-muter selama [memuat]
class TombolAuth extends StatelessWidget {
  const TombolAuth({
    required this.label,
    required this.onPressed,
    this.memuat = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool memuat;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: memuat ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Warna.hijau,
        disabledBackgroundColor: Warna.hijau.withValues(alpha: 0.6),
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: memuat
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Text(label),
    );
  }
}

/// "Belum punya akun? Daftar" di bawah layar
class TautanBawah extends StatelessWidget {
  const TautanBawah({
    required this.teks,
    required this.aksi,
    required this.onTap,
    super.key,
  });

  final String teks;
  final String aksi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(teks, style: const TextStyle(color: Warna.teksPendukung)),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: Warna.hijau,
            textStyle: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(aksi),
        ),
      ],
    );
  }
}

/// kotak galat merah muda di atas form (figma: umum/masuk - galat)
class KotakGalat extends StatelessWidget {
  const KotakGalat(this.pesan, {super.key});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Warna.merahLembut,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 20, color: Warna.merah),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pesan,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Warna.merah,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
