import 'package:flutter_bloc/flutter_bloc.dart';

class KeranjangCubit extends Cubit<Map<String, int>> {
  KeranjangCubit() : super({});

  // gantiMitra true = keranjang lama dikosongin dulu (1 pesanan cuma boleh 1 mitra)
  void tambah(
    Map<String, dynamic> paket,
    int jumlah, {
    bool gantiMitra = false,
  }) {
    final baru = gantiMitra ? <String, int>{} : {...state};
    final int sisa = paket['sisaPorsi'];
    baru[paket['id']] = ((baru[paket['id']] ?? 0) + jumlah).clamp(1, sisa);
    emit(baru);
  }

  void ubahJumlah(String id, int jumlah) {
    emit({...state, id: jumlah});
  }

  void kosongkan() {
    emit({});
  }
}
