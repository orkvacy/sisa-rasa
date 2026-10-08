import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/data/dummy_deals.dart';

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
}
