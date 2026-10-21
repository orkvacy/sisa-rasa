import 'dart:math';

/// aturan voucher platform, sama kayak backend/internal/toko/voucher.go.
/// potongan ditanggung platform: subtotal (bagian mitra) ga berubah,
/// yang berkurang cuma total yang dibayar pembeli

/// persen dari subtotal, dibulatkan, paling banyak maksPotongan
int potonganVoucher(Map<String, dynamic> voucher, int subtotal) => min(
  voucher['maksPotongan'] as int,
  (subtotal * (voucher['persen'] as int) / 100).round(),
);

/// "Diskon 20% s.d. Rp10.000"
String ringkasVoucher(
  Map<String, dynamic> voucher,
  String Function(int) rupiah,
) => 'Diskon ${voucher['persen']}% s.d. ${rupiah(voucher['maksPotongan'])}';

/// pesan kenapa voucher belum bisa dipakai buat [subtotal] ini, null kalau bisa
String? alasanVoucherTakBisa(
  Map<String, dynamic> voucher,
  int subtotal,
  String Function(int) rupiah,
) {
  final int minimal = voucher['minBelanja'];
  if (subtotal < minimal) {
    return 'Belanja ${rupiah(minimal - subtotal)} lagi untuk memakai voucher ini.';
  }
  return null;
}
