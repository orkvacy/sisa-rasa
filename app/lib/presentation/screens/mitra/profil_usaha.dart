import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/core/theme/teks.dart';
import 'package:sisa_rasa/core/theme/warna.dart';
import 'package:sisa_rasa/presentation/cubit/akun_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/paket_cubit.dart';

/// Layar 9a: Profil Usaha Mitra (SRS F-64).
/// Mengelola identitas usaha, jenis, alamat, telepon/WA, dan jam operasional.
class ProfilUsaha extends StatefulWidget {
  const ProfilUsaha({super.key});

  @override
  State<ProfilUsaha> createState() => _ProfilUsahaState();
}

class _ProfilUsahaState extends State<ProfilUsaha> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _namaController;
  late final TextEditingController _alamatController;
  late final TextEditingController _teleponController;
  late final TextEditingController _jamController;
  String _jenisDipilih = 'Hotel';

  final _daftarJenis = ['Hotel', 'Restoran', 'Bakery', 'Kafe'];

  @override
  void initState() {
    super.initState();
    final akun = context.read<AkunCubit>().state;
    final nama = akun['nama'] ?? 'Mitra Usaha';
    final paket = context.read<PaketCubit>().state;
    final dataMitra = paket.where((p) => p['mitra'] == nama).firstOrNull;

    _namaController = TextEditingController(text: nama);
    _alamatController = TextEditingController(
      text: dataMitra?['alamat'] ?? 'Jl. Mulawarman No. 41, Samarinda',
    );
    _teleponController = TextEditingController(text: '081254321098');
    _jamController = TextEditingController(text: '08:00 - 22:00');
    if (dataMitra?['jenisMitra'] != null &&
        _daftarJenis.contains(dataMitra!['jenisMitra'])) {
      _jenisDipilih = dataMitra['jenisMitra'];
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _alamatController.dispose();
    _teleponController.dispose();
    _jamController.dispose();
    super.dispose();
  }

  void _simpan() {
    if (_formKey.currentState?.validate() != true) return;
    context.read<AkunCubit>().ubahNama(_namaController.text);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Profil usaha berhasil diperbarui'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Warna.latar,
      appBar: AppBar(
        backgroundColor: Warna.latar,
        title: const Text(
          'Profil Usaha',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Kartu Ringkasan Gerai
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Warna.garis),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Warna.softGreen,
                      child: const Icon(
                        Icons.storefront,
                        color: Warna.hijau,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _namaController.text,
                            style: const TextStyle(
                              fontSize: Teks.nama,
                              fontWeight: FontWeight.w800,
                              color: Warna.teks,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kategori: $_jenisDipilih',
                            style: const TextStyle(
                              fontSize: Teks.keterangan,
                              color: Warna.teksPendukung,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Informasi Usaha',
                style: TextStyle(
                  fontSize: Teks.keterangan,
                  fontWeight: FontWeight.w700,
                  color: Warna.teksPendukung,
                ),
              ),
              const SizedBox(height: 8),

              // Formulir Isian
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Warna.garis),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _namaController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Usaha / Gerai',
                        hintText: 'Contoh: Ibis Kitchen & Bakery',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Nama usaha wajib diisi'
                          : null,
                      onChanged: (val) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Jenis Usaha',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Warna.teksPendukung,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final jenis in _daftarJenis)
                          ChoiceChip(
                            label: Text(jenis),
                            selected: _jenisDipilih == jenis,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _jenisDipilih = jenis);
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _alamatController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Alamat Lengkap Gerai',
                        hintText: 'Jl. Nama Jalan No. XX, Kota',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Alamat gerai wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _teleponController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Nomor WhatsApp / Telepon',
                        hintText: '08xxxxxxxxxx',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Nomor telepon wajib diisi untuk F-52'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _jamController,
                      decoration: const InputDecoration(
                        labelText: 'Jam Operasional Pengambilan',
                        hintText: '08:00 - 22:00',
                        prefixIcon: Icon(Icons.access_time_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Jam operasional wajib diisi'
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _simpan,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Simpan Perubahan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
