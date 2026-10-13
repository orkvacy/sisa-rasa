/// biaya layanan dalam persen dari harga pesanan, dibayar pembeli.
/// sementara masih ditulis di aplikasi, nanti diambil dari server.
/// kalau diisi 0, barisnya otomatis ga muncul di checkout
const int persenBiayaLayanan = 10;

/// biaya layanan buat [subtotal] tertentu, dibulatkan ke rupiah terdekat
int biayaLayanan(int subtotal) => (subtotal * persenBiayaLayanan / 100).round();

/// komisi platform dalam persen dari harga jual, dipotong dari bagian mitra (F-48).
/// sementara ditulis di aplikasi, nanti diatur di server
const int persenKomisi = 10;

int komisi(int hargaJual) => (hargaJual * persenKomisi / 100).round();

/// yg diterima mitra dari satu pesanan: harga jual dikurangi komisi
int penerimaanBersih(Map<String, dynamic> pesanan) {
  final int jual = pesanan['subtotal'];
  return jual - komisi(jual);
}

/// batas bayar F-40, porsi ditahan selama ini sebelum pesanan batal sendiri
const int menitBatasBayar = 15;

/// metode bayar yg didukung (F-10).
/// virtual account ditulis per bank: va_bca, va_mandiri, va_bri, va_bni
abstract final class MetodeBayar {
  static const qris = 'qris';
  static const gopay = 'gopay';
  static const va = 'va_bca';
  static const vaMandiri = 'va_mandiri';
  static const vaBri = 'va_bri';
  static const vaBni = 'va_bni';

  /// pilihan di checkout, VA cuma satu baris (banknya dipilih belakangan)
  static const semua = [qris, gopay, va];

  /// bank yg bisa dipilih buat virtual account
  static const bank = [va, vaMandiri, vaBri, vaBni];

  static bool isVa(String metode) => metode.startsWith('va_');

  static String namaBank(String metode) => switch (metode) {
    vaMandiri => 'Mandiri',
    vaBri => 'BRI',
    vaBni => 'BNI',
    _ => 'BCA',
  };

  static String nama(String metode) => switch (metode) {
    qris => 'QRIS',
    gopay => 'GoPay',
    _ => 'Virtual Account ${namaBank(metode)}',
  };

  static String keterangan(String metode) => switch (metode) {
    qris => 'Semua e-wallet & m-banking',
    gopay => 'Dibuka di aplikasi Gojek',
    vaMandiri => "Transfer dari Livin' by Mandiri atau ATM",
    vaBri => 'Transfer dari BRImo atau ATM BRI',
    vaBni => 'Transfer dari BNI Mobile atau ATM BNI',
    _ => 'Transfer dari m-BCA, KlikBCA, atau ATM BCA',
  };

  /// aplikasi bank buat langkah cara bayar VA
  static String aplikasiBank(String metode) => switch (metode) {
    vaMandiri => "Livin' by Mandiri atau ATM Mandiri",
    vaBri => 'BRImo atau ATM BRI',
    vaBni => 'BNI Mobile atau ATM BNI',
    _ => 'm-BCA, KlikBCA, atau ATM BCA',
  };
}
