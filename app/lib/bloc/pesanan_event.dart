// event
abstract class PesananEvent {}

// dikirim pas tombol Bayar di checkout dipencet
class PesananDibuat extends PesananEvent {
  PesananDibuat({
    required this.keranjang,
    required this.daftarPaket,
    required this.metode,
  });

  final Map<String, int> keranjang;
  final List<Map<String, dynamic>> daftarPaket;
  // salah satu dari MetodeBayar (qris, gopay, va)
  final String metode;
}

// dikirim pas pembeli mencet "Saya sudah bayar · cek status"
class PembayaranDicek extends PesananEvent {
  PembayaranDicek(this.id);

  final String id;
}

// dikirim pas pembeli batalin (F-55) atau batas bayarnya habis (F-40)
class PesananDibatalkan extends PesananEvent {
  PesananDibatalkan(this.id, {required this.alasan});

  final String id;
  final String alasan;
}
