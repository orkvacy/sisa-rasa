import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sisa_rasa/core/theme/teks.dart';
import 'package:sisa_rasa/core/theme/warna.dart';
import 'package:sisa_rasa/core/utils/format.dart';
import 'package:sisa_rasa/presentation/widgets/gambar_paket.dart';
import 'package:sisa_rasa/presentation/widgets/kabar_jumlah.dart';

/// gaya kolom angka di tombol - +. semua garis sama padding dari tema dimatiin,
/// soalnya padding 16 dari inputDecorationTheme bikin angkanya kedorong keluar kolom
const isianJumlah = InputDecoration(
  filled: false,
  isDense: true,
  contentPadding: EdgeInsets.zero,
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
);

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

class _KartuKeranjangState extends State<KartuKeranjang>
    with SingleTickerProviderStateMixin {
  late final TextEditingController jumlahController;
  final _fokusJumlah = FocusNode();
  late final _gerakJumlah = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 180),
  );
  late final _geserJumlah = Tween(
    begin: const Offset(0, 0.15),
    end: Offset.zero,
  ).chain(CurveTween(curve: Curves.easeOut)).animate(_gerakJumlah);
  bool _kurangiGerak = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _kurangiGerak = MediaQuery.disableAnimationsOf(context);
    if (_kurangiGerak) _gerakJumlah.value = 1;
  }

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
    if (oldWidget.jumlah != widget.jumlah &&
        !_fokusJumlah.hasFocus &&
        !_kurangiGerak) {
      _gerakJumlah.forward(from: 0);
    }
  }

  @override
  void dispose() {
    jumlahController.dispose();
    _fokusJumlah.dispose();
    _gerakJumlah.dispose();
    super.dispose();
  }

  void updateJumlah(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 1) return;
    // ga boleh lebih dari sisa porsi
    final int sisa = widget.paket['sisaPorsi'];
    widget.onJumlahBerubah(parsed.clamp(1, sisa));
  }

  void _ubahDariTombol(int baru) {
    widget.onJumlahBerubah(baru);
    kabarJumlah(
      context,
      nama: widget.paket['nama'],
      jumlah: baru,
      jarakBawah: 144,
    );
  }

  @override
  Widget build(BuildContext context) {
    final int sisa = widget.paket['sisaPorsi'];

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          // GambarPaket: foto kecil paketnya
          child: GambarPaket(
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                '${rupiah(widget.paket['hargaDiskon'])} / porsi',
                style: TextStyle(
                  fontSize: Teks.keterangan,
                  color: Warna.teksPendukung,
                ),
              ),
              // sisa dipisah barisnya biar ga kepotong di tengah kayak "· sisa 3"
              Text(
                'Sisa $sisa porsi',
                style: TextStyle(
                  fontSize: Teks.kecil,
                  fontWeight: sisa <= 2 ? FontWeight.w700 : FontWeight.w400,
                  color: sisa <= 2 ? Warna.mendesak : Warna.teksPendukung,
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
                    ? () => _ubahDariTombol(widget.jumlah - 1)
                    : null,
                icon: const Icon(Icons.remove, size: 18),
              ),
              SizedBox(
                width: 32,
                // TextField: jumlah porsi, keyboardnya angka
                child: SlideTransition(
                  position: _geserJumlah,
                  child: TextField(
                    focusNode: _fokusJumlah,
                    controller: jumlahController,
                    keyboardType: TextInputType.number,
                    // digitsOnly: huruf sama simbol ga bisa masuk
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    onChanged: updateJumlah,
                    style: const TextStyle(
                      fontSize: Teks.nama,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: isianJumlah,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Tambah porsi',
                visualDensity: VisualDensity.compact,
                onPressed: widget.jumlah < sisa
                    ? () => _ubahDariTombol(widget.jumlah + 1)
                    : null,
                icon: const Icon(Icons.add, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
