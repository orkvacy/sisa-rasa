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
