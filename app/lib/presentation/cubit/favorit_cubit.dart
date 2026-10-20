import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/domain/repositories/layanan_favorit.dart';
import 'package:sisa_rasa/domain/repositories/layanan_pesanan.dart';

/// id mitra dari satu paket. data contoh di HP ga punya idMitra,
/// jadi nama mitranya yang dipake (sama kayak FavoritLokal)
String kunciMitra(Map<String, dynamic> paket) =>
    (paket['idMitra'] as String?) ?? paket['mitra'] as String;

/// mitra favorit pembeli yang lagi masuk. state: daftar {id, nama, jenis},
/// yang terbaru di depan
class FavoritCubit extends Cubit<List<Map<String, dynamic>>> {
  FavoritCubit({required this.layanan}) : super(const []);

  final LayananFavorit layanan;

  final _galat = StreamController<String>.broadcast();

  /// pesan galat dari server, ditampilin jadi snackbar di main.dart
  Stream<String> get galat => _galat.stream;

  bool suka(String idMitra) => state.any((m) => m['id'] == idMitra);

  Future<void> muat() async {
    try {
      final daftar = await layanan.semua();
      if (!isClosed) emit(daftar);
    } on GagalLayanan catch (e) {
      if (!_galat.isClosed) _galat.add(e.pesan);
    }
  }

  /// ganti akun / keluar: favorit akun lama dibuang dari HP
  void kosongkan() => emit(const []);

  /// hati diketuk: layar langsung berubah, baru dikirim ke server.
  /// kalau server nolak, dibalikin lagi
  Future<void> ganti(Map<String, dynamic> paket) async {
    final id = kunciMitra(paket);
    final lama = state;
    final jadiSuka = !suka(id);
    emit(
      jadiSuka
          ? [
              {
                'id': id,
                'nama': paket['mitra'],
                'jenis': paket['jenisMitra'] ?? 'Mitra',
              },
              ...state,
            ]
          : [
              for (final m in state)
                if (m['id'] != id) m,
            ],
    );
    try {
      await layanan.atur(id, suka: jadiSuka);
    } on GagalLayanan catch (e) {
      if (isClosed) return;
      emit(lama);
      if (!_galat.isClosed) _galat.add(e.pesan);
    }
  }

  @override
  Future<void> close() {
    _galat.close();
    return super.close();
  }
}
