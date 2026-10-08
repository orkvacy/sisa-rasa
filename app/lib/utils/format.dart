/// jam sekarang dalam menit (16 * 60 + 20 = 16.20)
/// sengaja dibikin tetap biar pas demo isinya sama terus, nnti diganti jam asli
const int jamSekarang = 16 * 60 + 20;

/// Mengubah angka jadi format rupiah, contoh 18000 jadi Rp18.000
String rupiah(int nilai) {
  final teks = nilai.toString();
  final hasil = StringBuffer();
  for (var i = 0; i < teks.length; i++) {
    if (i > 0 && (teks.length - i) % 3 == 0) {
      hasil.write('.');
    }
    hasil.write(teks[i]);
  }
  return 'Rp${hasil.toString()}';
}

/// persen diskon, dibulatin ke bawah
int persenDiskon(int hargaAsli, int hargaDiskon) {
  return (hargaAsli - hargaDiskon) * 100 ~/ hargaAsli;
}

/// menit jadi jam, contoh 1020 jadi 17.00
String jam(int menit) {
  final j = (menit ~/ 60).toString().padLeft(2, '0');
  final m = (menit % 60).toString().padLeft(2, '0');
  return '$j.$m';
}

/// sisa waktu dari sekarang, contoh "40 mnt" atau "1 j 40 mnt"
String sisaWaktu(int menitTujuan) {
  final selisih = menitTujuan - jamSekarang;
  if (selisih < 60) return '$selisih mnt';
  if (selisih % 60 == 0) return '${selisih ~/ 60} j';
  return '${selisih ~/ 60} j ${selisih % 60} mnt';
}

/// true kalau jam ambil paketnya udah mulai tapi belum tutup
bool sudahBuka(Map<String, dynamic> paket) {
  return paket['mulai'] <= jamSekarang && jamSekarang < paket['tutup'];
}

const _bulan = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String _jamMenit(DateTime waktu) =>
    '${waktu.hour.toString().padLeft(2, '0')}.${waktu.minute.toString().padLeft(2, '0')}';

/// contoh "30 Sep, 17.12", dipake di kartu pesanan
String tanggalSingkat(DateTime waktu) =>
    '${waktu.day} ${_bulan[waktu.month - 1]}, ${_jamMenit(waktu)}';

/// contoh "1 Okt 2026, 16.26", dipake di detail pesanan
String tanggalLengkap(DateTime waktu) =>
    '${waktu.day} ${_bulan[waktu.month - 1]} ${waktu.year}, ${_jamMenit(waktu)}';

/// judul kelompok di tab pesanan: Hari ini / Kemarin / Minggu ini / Lebih lama
String kelompokTanggal(DateTime waktu, {DateTime? sekarang}) {
  final kini = sekarang ?? DateTime.now();
  final hariIni = DateTime(kini.year, kini.month, kini.day);
  final hari = DateTime(waktu.year, waktu.month, waktu.day);
  final selisih = hariIni.difference(hari).inDays;
  if (selisih <= 0) return 'Hari ini';
  if (selisih == 1) return 'Kemarin';
  if (selisih < 7) return 'Minggu ini';
  return 'Lebih lama';
}
