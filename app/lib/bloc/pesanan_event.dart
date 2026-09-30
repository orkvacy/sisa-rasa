// event
abstract class PesananEvent {}

// dikirim pas tombol Pesan di keranjang dipencet
class PesananDibuat extends PesananEvent {
  PesananDibuat({required this.keranjang, required this.daftarPaket});

  final Map<String, int> keranjang;
  final List<Map<String, dynamic>> daftarPaket;
}
