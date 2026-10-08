/// biaya layanan dalam persen dari harga pesanan, dibayar pembeli.
/// sementara masih ditulis di aplikasi, nanti diambil dari server.
/// kalau diisi 0, barisnya otomatis ga muncul di checkout
const int persenBiayaLayanan = 10;

/// biaya layanan buat [subtotal] tertentu, dibulatkan ke rupiah terdekat
int biayaLayanan(int subtotal) =>
    (subtotal * persenBiayaLayanan / 100).round();

/// batas bayar F-40, porsi ditahan selama ini sebelum pesanan batal sendiri
const int menitBatasBayar = 15;

/// metode bayar yg didukung (F-10)
abstract final class MetodeBayar {
  static const qris = 'qris';
  static const gopay = 'gopay';
  static const va = 'va';

  static const semua = [qris, gopay, va];

  static String nama(String metode) => switch (metode) {
    qris => 'QRIS',
    gopay => 'GoPay',
    _ => 'Virtual Account BCA',
  };

  static String keterangan(String metode) => switch (metode) {
    qris => 'Semua e-wallet & m-banking',
    gopay => 'Dibuka di aplikasi Gojek',
    _ => 'Transfer dari m-BCA, KlikBCA, atau ATM',
  };
}

/// semua urusan bayar lewat kelas ini.
/// layar sama bloc ga tau pembayarannya asli atau tiruan,
/// jadi pas backend udah ada cukup tuker implementasinya (NF-04).
///
/// status lunas yg asli harus dari server, bukan dari aplikasi (NF-10),
/// makanya aplikasi cuma bisa "nanya" udah lunas apa belum
abstract class LayananPembayaran {
  /// true kalau ga ada uang beneran yg pindah, layar pembayaran nampilin keterangan
  bool get modeUji;

  /// bikin tagihan buat satu pesanan, balikin isi QR / nomor VA / tautan GoPay
  Future<Map<String, String>> buatTagihan({
    required String idPesanan,
    required String metode,
    required int total,
  });

  /// nanya ke penyedia pembayaran, pesanan ini udah lunas belum
  Future<bool> sudahLunas(String idPesanan);
}

/// pembayaran tiruan buat selama backend belum ada.
/// ga ada uang yg beneran pindah, dan "Saya sudah bayar" selalu dianggap lunas
class PembayaranTiruan implements LayananPembayaran {
  const PembayaranTiruan({this.jeda = const Duration(milliseconds: 600)});

  /// pura-pura nunggu jawaban server
  final Duration jeda;

  @override
  bool get modeUji => true;

  @override
  Future<Map<String, String>> buatTagihan({
    required String idPesanan,
    required String metode,
    required int total,
  }) async {
    await Future<void>.delayed(jeda);
    // angka dari id pesanan, biar tiap pesanan nomornya beda tapi tetep sama tiap dibuka
    final angka = idPesanan.codeUnits.fold<int>(
      0,
      (a, b) => (a * 31 + b) % 100000000,
    );
    final nomor = '80770812${angka.toString().padLeft(8, '0')}';
    return {
      'isiQr': 'SISARASA-TIRUAN|$idPesanan|$total',
      'nomorVa':
          '${nomor.substring(0, 4)} ${nomor.substring(4, 8)} '
          '${nomor.substring(8, 12)} ${nomor.substring(12, 16)}',
    };
  }

  @override
  Future<bool> sudahLunas(String idPesanan) async {
    await Future<void>.delayed(jeda);
    return true;
  }
}
