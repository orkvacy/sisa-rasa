import 'package:flutter/material.dart';
import 'package:sisa_rasa/data/pembayaran.dart';
import 'package:sisa_rasa/theme/warna.dart';

/// satu baris metode bayar (figma v3): radio, kotak logo, nama + keterangan.
/// yg kepilih latarnya hijau muda dengan garis hijau tua
class BarisMetode extends StatelessWidget {
  const BarisMetode({
    required this.metode,
    required this.dipilih,
    required this.onTap,
    this.judul,
    this.keterangan,
    this.panah = false,
    super.key,
  });

  final String metode;
  final bool dipilih;
  final VoidCallback onTap;
  // dipake baris VA di checkout: "Virtual Account" + daftar bank
  final String? judul;
  final String? keterangan;
  // panah kanan kalau barisnya buka pilihan lagi (bank VA)
  final bool panah;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: dipilih,
      button: true,
      child: Material(
        color: dipilih ? Warna.softGreen : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: dipilih ? Warna.hijau : Warna.garis,
            width: dipilih ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // radio digambar sendiri, biar ga pake Radio yg udah deprecated
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: dipilih ? Warna.hijau : Warna.garisKontrol,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: dipilih
                      ? Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Warna.hijau,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                LogoMetode(metode: metode),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        judul ?? MetodeBayar.nama(metode),
                        style: const TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          fontWeight: FontWeight.w600,
                          color: Warna.teks,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        keterangan ?? MetodeBayar.keterangan(metode),
                        style: const TextStyle(
                          fontSize: 12,
                          height: 16 / 12,
                          letterSpacing: 0.1,
                          fontWeight: FontWeight.w500,
                          color: Warna.teksPendukung,
                        ),
                      ),
                    ],
                  ),
                ),
                if (panah)
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Warna.teksPendukung,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// kotak putih 44x32 isi ikon metode
class LogoMetode extends StatelessWidget {
  const LogoMetode({required this.metode, super.key});

  final String metode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Warna.garis),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: MetodeBayar.isVa(metode)
          ? Text(
              MetodeBayar.namaBank(metode),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Warna.teks,
              ),
            )
          : Icon(
              metode == MetodeBayar.gopay
                  ? Icons.account_balance_wallet_outlined
                  : Icons.qr_code_2,
              size: 20,
              color: Warna.teks,
            ),
    );
  }
}

/// lembar bawah pilih metode. [hanyaBank] true = cuma daftar bank VA.
/// balikin metode yg dipilih, atau null kalau ditutup
Future<String?> pilihMetode(
  BuildContext context, {
  required String aktif,
  bool hanyaBank = false,
}) {
  final pilihan = hanyaBank
      ? MetodeBayar.bank
      : [MetodeBayar.qris, MetodeBayar.gopay, ...MetodeBayar.bank];

  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hanyaBank ? 'Pilih bank' : 'Ganti metode pembayaran',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Warna.teks,
              ),
            ),
            const SizedBox(height: 12),
            for (final metode in pilihan) ...[
              BarisMetode(
                metode: metode,
                dipilih: metode == aktif,
                onTap: () => Navigator.pop(sheetContext, metode),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    ),
  );
}
