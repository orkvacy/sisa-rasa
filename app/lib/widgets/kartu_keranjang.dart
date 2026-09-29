import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sisa_rasa/theme/teks.dart';
import 'package:sisa_rasa/theme/warna.dart';
import 'package:sisa_rasa/utils/format.dart';

/// satu baris paket di keranjang, jumlahnya bisa diketik atau pake tombol - +
class KartuKeranjang extends StatefulWidget {
  const KartuKeranjang({
    required this.paket,
    required this.jumlah,
    required this.onJumlahBerubah,
    super.key,
  });

  final Map<String, dynamic> paket;
  final int jumlah;
  final ValueChanged<int> onJumlahBerubah;

  @override
  State<KartuKeranjang> createState() => _KartuKeranjangState();
}

class _KartuKeranjangState extends State<KartuKeranjang> {
  late final TextEditingController jumlahController;

  @override
  void initState() {
    super.initState();
    jumlahController = TextEditingController(text: '${widget.jumlah}');
  }

  @override
  void didUpdateWidget(covariant KartuKeranjang oldWidget) {
    super.didUpdateWidget(oldWidget);
    // kalau jumlahnya diubah dari tombol - +, angka di kolom ikut ganti
    if (jumlahController.text != '${widget.jumlah}') {
      jumlahController.text = '${widget.jumlah}';
    }
  }

  @override
  void dispose() {
    jumlahController.dispose();
    super.dispose();
  }

  void updateJumlah(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 1) return;
    // ga boleh lebih dari sisa porsi
    final int sisa = widget.paket['sisaPorsi'];
    widget.onJumlahBerubah(parsed.clamp(1, sisa));
  }

  @override
  Widget build(BuildContext context) {
    final int sisa = widget.paket['sisaPorsi'];

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          // Image.asset: foto kecil paketnya
          child: Image.asset(
            widget.paket['foto'],
            width: 60,
            height: 60,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.paket['nama'],
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${rupiah(widget.paket['hargaDiskon'])} / porsi · sisa $sisa',
                style: const TextStyle(
                  fontSize: Teks.kecil,
                  color: Warna.teksPendukung,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Container: kotak buat tombol - , angka, tombol +
        Container(
          height: 40,
          decoration: BoxDecoration(
            border: Border.all(color: Warna.garisKontrol),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Kurangi porsi',
                visualDensity: VisualDensity.compact,
                onPressed: widget.jumlah > 1
                    ? () => widget.onJumlahBerubah(widget.jumlah - 1)
                    : null,
                icon: const Icon(Icons.remove, size: 20),
              ),
              SizedBox(
                width: 28,
                // TextField: jumlah porsi, keyboardnya angka
                child: TextField(
                  controller: jumlahController,
                  keyboardType: TextInputType.number,
                  // digitsOnly: huruf sama simbol ga bisa masuk
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  onChanged: updateJumlah,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Tambah porsi',
                visualDensity: VisualDensity.compact,
                onPressed: widget.jumlah < sisa
                    ? () => widget.onJumlahBerubah(widget.jumlah + 1)
                    : null,
                icon: const Icon(Icons.add, size: 20),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
