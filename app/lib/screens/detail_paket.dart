import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sisa_rasa/theme/teks.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';
import 'package:sisa_rasa/widgets/timeline_ambil.dart';

/// halaman detail paket, kebuka dari beranda / cari
class DetailPaket extends StatefulWidget {
  const DetailPaket({
    required this.paket,
    required this.mitraKeranjang,
    required this.onTambah,
    super.key,
  });

  final Map<String, dynamic> paket;
  final String? mitraKeranjang;
  final void Function(Map<String, dynamic> paket, int jumlah) onTambah;

  @override
  State<DetailPaket> createState() => _DetailPaketState();
}

class _DetailPaketState extends State<DetailPaket> {
  int jumlah = 1;
  final jumlahController = TextEditingController(text: '1');

  @override
  void dispose() {
    jumlahController.dispose();
    super.dispose();
  }

  void aturJumlah(int nilai) {
    final int sisa = widget.paket['sisaPorsi'];
    setState(() => jumlah = nilai.clamp(1, sisa));
    jumlahController.text = '$jumlah';
  }

  Future<void> tambahKeKeranjang() async {
    // kalau keranjangnya udah isi paket dari mitra lain, tanya dulu
    if (widget.mitraKeranjang != null &&
        widget.mitraKeranjang != widget.paket['mitra']) {
      final ganti = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.white,
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ganti isi keranjang?',
                style: TextStyle(
                  fontSize: Teks.subjudul,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Keranjangmu berisi paket dari ${widget.mitraKeranjang}. Satu pesanan hanya bisa dari satu mitra karena diambil langsung di tempat.',
                style: const TextStyle(
                  fontSize: Teks.isi,
                  height: 1.45,
                  color: Warna.teksPendukung,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                // Navigator.pop sambil ngirim jawaban true
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(backgroundColor: Warna.merah),
                  child: const Text('Kosongkan & tambah'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Batal'),
                ),
              ),
            ],
          ),
        ),
      );
      if (ganti != true) return;
    }

    widget.onTambah(widget.paket, jumlah);
    if (!mounted) return;
    // snackbar dinaikin 88 biar munculnya di atas bar keranjang, ga nutupin
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.paket['nama']} masuk keranjang'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 88),
        duration: const Duration(seconds: 2),
      ),
    );
    // Navigator.pop: balik ke beranda
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final paket = widget.paket;
    final int sisa = paket['sisaPorsi'];
    final int total = paket['totalPorsi'];
    final habis = sisa == 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              // Stack: foto paling belakang, lembar putih nutupin bawah foto,
              // tombol back sama favorit numpuk paling depan
              child: Stack(
                children: [
                  // Image.asset: foto paket full selebar layar
                  Image.asset(
                    paket['foto'],
                    width: double.infinity,
                    height: 320,
                    fit: BoxFit.cover,
                  ),
                  // lembar putih, margin atas 292 biar naik nutupin foto dikit
                  Container(
                    margin: const EdgeInsets.only(top: 292),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.storefront_outlined,
                              size: 18,
                              color: Warna.teksPendukung,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${paket['mitra']} · ${paket['jenisMitra']} · ${paket['jarak']}',
                                style: const TextStyle(
                                  color: Warna.teksPendukung,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          paket['nama'],
                          style: const TextStyle(
                            fontSize: Teks.subjudul,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              rupiah(paket['hargaDiskon']),
                              style: const TextStyle(
                                fontSize: Teks.judul,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                rupiah(paket['hargaAsli']),
                                style: const TextStyle(
                                  fontSize: Teks.isi,
                                  color: Warna.teksPendukung,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // pil hemat
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Warna.softGreen,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'Hemat ${rupiah(paket['hargaAsli'] - paket['hargaDiskon'])}',
                            style: const TextStyle(
                              fontSize: Teks.keterangan,
                              fontWeight: FontWeight.w700,
                              color: Warna.hijau,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          paket['deskripsi'],
                          style: const TextStyle(
                            fontSize: Teks.isi,
                            height: 1.5,
                            color: Warna.teksPendukung,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // meter 10 kotak, yg ijo = porsi yg udah keselamatin
                        Row(
                          children: [
                            for (var i = 0; i < 10; i++) ...[
                              Expanded(
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color:
                                        i <
                                            ((total - sisa) * 10 / total)
                                                .round()
                                        ? Warna.hijau
                                        : Warna.garis,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              if (i < 9) const SizedBox(width: 4),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          habis
                              ? 'Semua $total porsi sudah diselamatkan'
                              : '${total - sisa} dari $total porsi sudah diselamatkan · sisa $sisa',
                          style: const TextStyle(
                            fontSize: Teks.keterangan,
                            color: Warna.teksPendukung,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // kotak jam ambil
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Warna.latar,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Ambil hari ini',
                                      style: TextStyle(
                                        color: Warna.teksPendukung,
                                      ),
                                    ),
                                  ),
                                  // pil hitung mundur
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Warna.mendesakLembut,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.schedule,
                                          size: 14,
                                          color: Warna.mendesak,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          sudahBuka(paket)
                                              ? 'Tutup ${sisaWaktu(paket['tutup'])} lagi'
                                              : 'Buka ${sisaWaktu(paket['mulai'])} lagi',
                                          style: const TextStyle(
                                            fontSize: Teks.keterangan,
                                            fontWeight: FontWeight.w700,
                                            color: Warna.mendesak,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${jam(paket['mulai'])} – ${jam(paket['tutup'])}',
                                style: const TextStyle(
                                  fontSize: Teks.judul,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 14),
                              TimelineAmbil(paket: paket),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              size: 20,
                              color: Warna.hijau,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(paket['alamat'])),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Row(
                          children: [
                            Icon(
                              Icons.payments_outlined,
                              size: 20,
                              color: Warna.hijau,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tunjukkan kode ambil di kasir, bayar di tempat.',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Positioned: tombol back di pojok kiri atas
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 16,
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white,
                      child: IconButton(
                        tooltip: 'Kembali',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Warna.teks),
                      ),
                    ),
                  ),
                  // Positioned: tombol favorit di pojok kanan atas
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    right: 16,
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white,
                      child: IconButton(
                        tooltip: 'Simpan mitra',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Mitra favorit belum tersedia di versi ini',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.favorite_border,
                          color: Warna.teks,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // bar bawah: atur porsi + tombol tambah
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              // BoxShadow: offset y minus biar bayangannya jatuh ke atas
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                if (!habis) ...[
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      border: Border.all(color: Warna.garisKontrol),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Kurangi porsi',
                          visualDensity: VisualDensity.compact,
                          onPressed: jumlah > 1
                              ? () => aturJumlah(jumlah - 1)
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        SizedBox(
                          width: 32,
                          // TextField: jumlah porsi, keyboard angka
                          child: TextField(
                            controller: jumlahController,
                            keyboardType: TextInputType.number,
                            // cuma boleh angka, huruf ditolak
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: Teks.nama,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onChanged: (value) {
                              final parsed = int.tryParse(value);
                              if (parsed != null && parsed > 0) {
                                aturJumlah(parsed);
                              }
                            },
                          ),
                        ),
                        IconButton(
                          tooltip: 'Tambah porsi',
                          visualDensity: VisualDensity.compact,
                          onPressed: jumlah < sisa
                              ? () => aturJumlah(jumlah + 1)
                              : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: habis ? null : tambahKeKeranjang,
                      style: FilledButton.styleFrom(
                        backgroundColor: Warna.hijau,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      // FittedBox: tulisannya ngecil dikit kalau ga muat, biar ga turun baris
                      child: FittedBox(
                        child: Text(
                          habis
                              ? 'Porsi habis'
                              : 'Tambah · ${rupiah(paket['hargaDiskon'] * jumlah)}',
                          style: const TextStyle(
                            fontSize: Teks.tombol,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
