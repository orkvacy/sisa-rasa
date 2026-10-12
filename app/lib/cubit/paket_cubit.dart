import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/data/dummy_deals.dart';
import 'package:sisa_rasa/utils/format.dart';

// nyimpen daftar paket + sisa porsinya
// state nya List paket, tiap ada yg berubah emit list baru
class PaketCubit extends Cubit<List<Map<String, dynamic>>> {
  // isi awalnya salinan dummyDeals, biar data aslinya ga ikut keubah
  PaketCubit()
    : super([
        for (final paket in dummyDeals) {...paket},
      ]);

  Map<String, dynamic> cari(String id) {
    return state.firstWhere((paket) => paket['id'] == id);
  }

  // dipanggil pas pesanan dibuat, sisa porsi dikurangin sesuai isi keranjang
  // porsinya ditahan buat pembeli selama nunggu dibayar (F-23, F-40)
  void kurangiStok(Map<String, int> keranjang) {
    emit([
      for (final paket in state)
        {
          ...paket,
          'sisaPorsi': paket['sisaPorsi'] - (keranjang[paket['id']] ?? 0),
        },
    ]);
  }

  // kebalikannya, dipanggil pas pesanan batal sebelum dibayar (F-40)
  void kembalikanStok(Map<String, int> porsiPaket) {
    emit([
      for (final paket in state)
        {
          ...paket,
          'sisaPorsi': paket['sisaPorsi'] + (porsiPaket[paket['id']] ?? 0),
        },
    ]);
  }

  // mitra ubah sisa porsi langsung dari daftar (F-44)
  void ubahSisa(String id, int sisa) {
    emit([
      for (final paket in state)
        if (paket['id'] == id) {...paket, 'sisaPorsi': sisa} else paket,
    ]);
  }

  // mitra tutup / buka gerai sementara, paketnya ga tampil buat pembeli (F-51)
  void aturGerai(String mitra, {required bool buka}) {
    emit([
      for (final paket in state)
        if (paket['mitra'] == mitra) {...paket, 'geraiTutup': !buka} else paket,
    ]);
  }

  bool geraiBuka(String mitra) =>
      !state.any((p) => p['mitra'] == mitra && p['geraiTutup'] == true);

  /// paket yg boleh keliatan di sisi pembeli: belum lewat jam tutup (F-25),
  /// gerainya buka (F-51), dan ga dinonaktifkan mitra (F-45)
  static bool tampilUntukPembeli(Map<String, dynamic> paket) =>
      paket['tutup'] > jamSekarang &&
      paket['geraiTutup'] != true &&
      paket['nonaktif'] != true;

  var _nomorBaru = 0;

  /// mitra nambah paket (F-15), langsung tersedia sampai jam tutup ambil.
  /// data gerai (alamat, jarak, jenis) disalin dari paket mitra yg udah ada
  String tambahPaket(Map<String, dynamic> isian) {
    final gerai = state.where((p) => p['mitra'] == isian['mitra']).firstOrNull;
    _nomorBaru++;
    final id = 'pm-${DateTime.now().millisecondsSinceEpoch}-$_nomorBaru';
    emit([
      ...state,
      {
        'jenisMitra': gerai?['jenisMitra'] ?? 'Mitra',
        'alamat': gerai?['alamat'] ?? '',
        'jarak': gerai?['jarak'] ?? '',
        'foto': gerai?['foto'] ?? 'assets/images/shinchann.jpg',
        'geraiTutup': gerai?['geraiTutup'] ?? false,
        ...isian,
        'id': id,
        'sisaPorsi': isian['totalPorsi'],
      },
    ]);
    return id;
  }

  /// mitra ubah paket (F-18). kalau jumlah porsinya diganti,
  /// sisa porsi ikut geser sebanyak selisihnya
  void ubahPaket(String id, Map<String, dynamic> isian) {
    emit([
      for (final paket in state)
        if (paket['id'] == id)
          {
            ...paket,
            ...isian,
            'sisaPorsi':
                ((paket['sisaPorsi'] as int) +
                        (isian['totalPorsi'] as int) -
                        (paket['totalPorsi'] as int))
                    .clamp(0, isian['totalPorsi'] as int),
          }
        else
          paket,
    ]);
  }

  void hapusPaket(String id) {
    emit([
      for (final paket in state)
        if (paket['id'] != id) paket,
    ]);
  }

  /// aktif / nonaktifin paket, yg nonaktif ga tampil buat pembeli (F-45)
  void aturAktif(String id, {required bool aktif}) {
    emit([
      for (final paket in state)
        if (paket['id'] == id) {...paket, 'nonaktif': !aktif} else paket,
    ]);
  }
}
