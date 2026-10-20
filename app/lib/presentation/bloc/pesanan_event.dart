// event
abstract class PesananEvent {}

// dikirim pas tombol Bayar di checkout dipencet
class PesananDibuat extends PesananEvent {
  PesananDibuat({
    required this.idAkun,
    required this.namaPembeli,
    required this.keranjang,
    required this.daftarPaket,
    required this.metode,
    this.kunci,
  });

  // pemilik pesanan, biar pas ganti akun daftar pesanannya ikut ganti
  final String idAkun;
  // ditampilin ke mitra, disingkat jadi "Rani A."
  final String namaPembeli;
  final Map<String, int> keranjang;
  final List<Map<String, dynamic>> daftarPaket;
  // salah satu dari MetodeBayar (qris, gopay, va)
  final String metode;
  // idempotency key, satu per layar checkout. kalau request ke server diulang
  // (sinyal putus, kepencet dua kali), server ngasih pesanan yg sama, bukan pesanan baru
  final String? kunci;
}

// minta daftar pesanan terbaru dari server. dikirim pas masuk dan berkala,
// biar HP mitra liat pesanan baru dan HP pembeli liat status dari mitra
class PesananDimuat extends PesananEvent {}

// akun keluar / ganti: pesanan akun sebelumnya dibuang dari HP
class PesananDikosongkan extends PesananEvent {}

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

// dikirim mitra pas pesanan yg udah dibayar ga bisa dipenuhi (paket habis, dapur tutup).
// dana pembeli balik penuh (F-42)
class PesananDibatalkanMitra extends PesananEvent {
  PesananDibatalkanMitra(this.id, {required this.alasan});

  final String id;
  final String alasan;
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
