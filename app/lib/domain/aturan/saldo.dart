/// bank yg bisa dipilih buat rekening pencairan (F-49)
const bankPencairan = ['BCA', 'Mandiri', 'BRI', 'BNI', 'BSI', 'CIMB Niaga'];

/// saldo yg belum dicairkan: semua dana masuk dikurangi pencairan yg ga gagal.
/// yg masih Diproses ikut ngurangin, biar ga keliatan bisa dicairin dua kali
int saldoTersedia(List<Map<String, dynamic>> riwayat) {
  var saldo = 0;
  for (final e in riwayat) {
    if (e['jenis'] == 'masuk') saldo += e['jumlah'] as int;
    if (e['jenis'] == 'cair' && e['status'] != 'Gagal') {
      saldo -= e['jumlah'] as int;
    }
  }
  return saldo;
}

/// total satu jenis ('masuk' / 'cair') sejak senin minggu ini
int totalMingguIni(
  List<Map<String, dynamic>> riwayat,
  String jenis, {
  DateTime? sekarang,
}) {
  final kini = sekarang ?? DateTime.now();
  final senin = DateTime(
    kini.year,
    kini.month,
    kini.day,
  ).subtract(Duration(days: kini.weekday - 1));
  return riwayat
      .where(
        (e) => e['jenis'] == jenis && !(e['waktu'] as DateTime).isBefore(senin),
      )
      .fold(0, (n, e) => n + (e['jumlah'] as int));
}

/// "BCA · 1234", nomor rekening cuma 4 angka terakhir yg ditampilin
String rekeningSingkat(String bank, String nomor) {
  final akhir = nomor.length > 4 ? nomor.substring(nomor.length - 4) : nomor;
  return '$bank · $akhir';
}

/// F-49: nama pemilik rekening harus sama dengan nama usaha.
/// sementara dibandingin sama nama akun, nanti server nanya ke bank (cek rekening)
bool namaRekeningCocok(String namaRekening, String namaUsaha) {
  String rapi(String s) =>
      s.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
  return rapi(namaRekening).isNotEmpty && rapi(namaRekening) == rapi(namaUsaha);
}
