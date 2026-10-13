import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/cubit/keranjang_cubit.dart';
import 'package:sisa_rasa/cubit/paket_cubit.dart';
import 'package:sisa_rasa/theme/teks.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';
import 'package:sisa_rasa/widgets/timeline_ambil.dart';

/// halaman detail paket, kebuka dari beranda / cari
class DetailPaket extends StatefulWidget {
  const DetailPaket({required this.paket, super.key});

  final Map<String, dynamic> paket;

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
    // context.read: ambil cubit buat manggil fungsinya aja, ga perlu digambar ulang
    final keranjangCubit = context.read<KeranjangCubit>();
    final keranjang = keranjangCubit.state;
    final mitraKeranjang = keranjang.isEmpty
        ? null
        : context.read<PaketCubit>().cari(keranjang.keys.first)['mitra'];
    var gantiMitra = false;

    // kalau keranjangnya udah isi paket dari mitra lain, tanya dulu
    if (mitraKeranjang != null && mitraKeranjang != widget.paket['mitra']) {
      final ganti = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.white,
        // Padding: jarak isi bottom sheet
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          // Column: isi konfirmasi disusun ke bawah
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // judul konfirmasi
              const Text(
                'Ganti isi keranjang?',
                style: TextStyle(
                  fontSize: Teks.subjudul,
                  fontWeight: FontWeight.w800,
                ),
              ),
              // jarak
              const SizedBox(height: 8),
              // penjelasan kenapa keranjang harus dikosongin
              Text(
                'Keranjangmu berisi paket dari $mitraKeranjang. Satu pesanan hanya bisa dari satu mitra karena diambil langsung di tempat.',
                style: const TextStyle(
                  fontSize: Teks.isi,
                  height: 1.45,
                  color: Warna.teksPendukung,
                ),
              ),
              // jarak
              const SizedBox(height: 20),
              // SizedBox: biar tombolnya selebar layar
              SizedBox(
                width: double.infinity,
                height: 52,
                // FilledButton: tombol utama yg warnanya penuh, Navigator.pop sambil ngirim jawaban true
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(backgroundColor: Warna.merah),
                  // tulisan tombol kosongkan
                  child: const Text('Kosongkan & tambah'),
                ),
              ),
              // jarak
              const SizedBox(height: 8),
              // tombol batal selebar layar
              SizedBox(
                width: double.infinity,
                height: 52,
                // OutlinedButton: tombol batal
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  // tulisan batal
                  child: const Text('Batal'),
                ),
              ),
            ],
          ),
        ),
      );
      if (ganti != true) return;
      gantiMitra = true;
    }

    keranjangCubit.tambah(widget.paket, jumlah, gantiMitra: gantiMitra);
    if (!mounted) return;
    // snackbar dinaikin 88 biar munculnya di atas bar keranjang, ga nutupin
    ScaffoldMessenger.of(context).showSnackBar(
      // SnackBar: notif paket udah masuk keranjang
      SnackBar(
        // isi notif
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

    // Scaffold: kerangka halaman detail
    return Scaffold(
      backgroundColor: Colors.white,
      // Column: isi di atas, bar tombol di bawah
      body: Column(
        children: [
          // Expanded: isi detail ngisi sisa layar
          Expanded(
            // SingleChildScrollView: isi detail bisa di scroll
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
                    // Column: info paket disusun ke bawah
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row: icon toko + nama mitra
                        Row(
                          children: [
                            // icon toko
                            const Icon(
                              Icons.storefront_outlined,
                              size: 18,
                              color: Warna.teksPendukung,
                            ),
                            // jarak
                            const SizedBox(width: 6),
                            // Expanded biar nama mitra ga overflow
                            Expanded(
                              // mitra, jenis, jarak
                              child: Text(
                                '${paket['mitra']} · ${paket['jenisMitra']} · ${paket['jarak']}',
                                style: const TextStyle(
                                  color: Warna.teksPendukung,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // jarak
                        const SizedBox(height: 6),
                        // nama paket
                        Text(
                          paket['nama'],
                          style: const TextStyle(
                            fontSize: Teks.subjudul,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        // jarak
                        const SizedBox(height: 8),
                        // Row: harga diskon sama harga asli sebaris
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // harga diskon
                            Text(
                              rupiah(paket['hargaDiskon']),
                              style: const TextStyle(
                                fontSize: Teks.judul,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            // jarak
                            const SizedBox(width: 8),
                            // Padding: harga asli diturunin dikit biar sejajar
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              // harga asli dicoret
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
                        // jarak
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
                          // tulisan hemat berapa
                          child: Text(
                            'Hemat ${rupiah(paket['hargaAsli'] - paket['hargaDiskon'])}',
                            style: const TextStyle(
                              fontSize: Teks.keterangan,
                              fontWeight: FontWeight.w700,
                              color: Warna.hijau,
                            ),
                          ),
                        ),
                        // jarak
                        const SizedBox(height: 16),
                        // deskripsi paket
                        Text(
                          paket['deskripsi'],
                          style: const TextStyle(
                            fontSize: Teks.isi,
                            height: 1.5,
                            color: Warna.teksPendukung,
                          ),
                        ),
                        // jarak
                        const SizedBox(height: 20),

                        // meter 10 kotak, yg ijo = porsi yg udah keselamatin
                        Row(
                          children: [
                            for (var i = 0; i < 10; i++) ...[
                              // Expanded: tiap kotak meter lebarnya sama
                              Expanded(
                                // Container: satu kotak meter
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
                              // jarak antar kotak
                              if (i < 9) const SizedBox(width: 4),
                            ],
                          ],
                        ),
                        // jarak
                        const SizedBox(height: 6),
                        // keterangan porsi yg udah diselamatin
                        Text(
                          habis
                              ? 'Semua $total porsi sudah diselamatkan'
                              : '${total - sisa} dari $total porsi sudah diselamatkan · sisa $sisa',
                          style: const TextStyle(
                            fontSize: Teks.keterangan,
                            color: Warna.teksPendukung,
                          ),
                        ),
                        // jarak
                        const SizedBox(height: 20),

                        // kotak jam ambil
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Warna.latar,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          // Column: isi kotak jam ambil
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Row: tulisan ambil hari ini + pil hitung mundur
                              Row(
                                children: [
                                  // Expanded: dorong pil ke kanan
                                  const Expanded(
                                    // tulisan ambil hari ini
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
                                    // Row: icon jam + sisa waktu
                                    child: Row(
                                      children: [
                                        // icon jam
                                        const Icon(
                                          Icons.schedule,
                                          size: 14,
                                          color: Warna.mendesak,
                                        ),
                                        // jarak
                                        const SizedBox(width: 4),
                                        // sisa waktu buka / tutup
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
                              // jarak
                              const SizedBox(height: 8),
                              // jam ambil
                              Text(
                                '${jam(paket['mulai'])} – ${jam(paket['tutup'])}',
                                style: const TextStyle(
                                  fontSize: Teks.judul,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              // jarak
                              const SizedBox(height: 14),
                              // timeline jam ambil
                              TimelineAmbil(paket: paket),
                            ],
                          ),
                        ),
                        // jarak
                        const SizedBox(height: 16),
                        // Row: icon lokasi + alamat
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // icon lokasi
                            const Icon(
                              Icons.place_outlined,
                              size: 20,
                              color: Warna.hijau,
                            ),
                            // jarak
                            const SizedBox(width: 8),
                            // alamat mitra
                            Expanded(child: Text(paket['alamat'])),
                          ],
                        ),
                        // jarak
                        const SizedBox(height: 10),
                        // Row: icon bayar + info bayar
                        const Row(
                          children: [
                            // icon bayar
                            Icon(
                              Icons.payments_outlined,
                              size: 20,
                              color: Warna.hijau,
                            ),
                            // jarak
                            SizedBox(width: 8),
                            // Expanded biar tulisannya turun baris
                            Expanded(
                              // info bayar di tempat
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
                    // CircleAvatar: latar bulet putih buat tombol back
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white,
                      // IconButton: tombol back
                      child: IconButton(
                        tooltip: 'Kembali',
                        onPressed: () => Navigator.pop(context),
                        // icon panah kiri
                        icon: const Icon(Icons.arrow_back, color: Warna.teks),
                      ),
                    ),
                  ),
                  // Positioned: tombol favorit di pojok kanan atas
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    right: 16,
                    // latar bulet buat tombol favorit
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white,
                      // IconButton: tombol simpan mitra
                      child: IconButton(
                        tooltip: 'Simpan mitra',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            // notif favorit belum ada
                            const SnackBar(
                              // isi notif
                              content: Text(
                                'Mitra favorit belum tersedia di versi ini',
                              ),
                            ),
                          );
                        },
                        // icon hati
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
            // Row: pengatur porsi + tombol tambah
            child: Row(
              children: [
                if (!habis) ...[
                  // Container: kotak pengatur porsi
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      border: Border.all(color: Warna.garisKontrol),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    // Row: tombol kurang, angka, tombol tambah
                    child: Row(
                      children: [
                        // IconButton: kurangi porsi
                        IconButton(
                          tooltip: 'Kurangi porsi',
                          visualDensity: VisualDensity.compact,
                          onPressed: jumlah > 1
                              ? () => aturJumlah(jumlah - 1)
                              : null,
                          // icon minus
                          icon: const Icon(Icons.remove),
                        ),
                        // SizedBox: lebar kolom angka porsi
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
                        // IconButton: tambah porsi
                        IconButton(
                          tooltip: 'Tambah porsi',
                          visualDensity: VisualDensity.compact,
                          onPressed: jumlah < sisa
                              ? () => aturJumlah(jumlah + 1)
                              : null,
                          // icon plus
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ),
                  // jarak
                  const SizedBox(width: 12),
                ],
                // Expanded: tombol tambah ngisi sisa lebar
                Expanded(
                  // tinggi tombol
                  child: SizedBox(
                    height: 52,
                    // FilledButton: tombol masuk keranjang, mati kalau habis
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
                        // tulisan tombol
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
