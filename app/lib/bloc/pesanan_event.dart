// event
abstract class PesananEvent {}

// dikirim pas tombol Bayar di checkout dipencet
class PesananDibuat extends PesananEvent {
  PesananDibuat({
    required this.idAkun,
    required this.keranjang,
    required this.daftarPaket,
    required this.metode,
  });

  // pemilik pesanan, biar pas ganti akun daftar pesanannya ikut ganti
  final String idAkun;
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
  PesananDibatalkan(this.id, {required this.alasan, this.otomatis = false});

  final String id;
  final String alasan;
  // true kalau batalnya karena batas bayar habis, bukan dipencet pembeli
  final bool otomatis;
}

// dikirim pas pembeli ganti metode bayar sebelum lunas, tagihannya dibikin ulang
class MetodeDiganti extends PesananEvent {
  MetodeDiganti(this.id, this.metode);

  final String id;
  final String metode;
}

// dikirim mitra pas pesanan siap diambil (F-43) atau sudah diambil (F-20).
// sementara dipencet dari tombol mode uji di detail pesanan
class StatusPesananDiubah extends PesananEvent {
  StatusPesananDiubah(this.id, this.status);

  final String id;
  // StatusPesanan.siapDiambil atau StatusPesanan.selesai
  final String status;
}
