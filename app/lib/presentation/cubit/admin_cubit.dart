import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/domain/repositories/layanan_admin.dart';
import 'package:sisa_rasa/domain/repositories/layanan_pesanan.dart';

/// daftar mitra buat halaman verifikasi admin (F-36 - F-38).
/// state: filter (status yg lagi dipilih, '' = semua), mitra (daftar),
/// memuat (lagi ngambil dari server)
class AdminCubit extends Cubit<Map<String, dynamic>> {
  AdminCubit({required this.layanan})
    : super(const {
        'filter': StatusGerai.menunggu,
        'mitra': <Map<String, dynamic>>[],
        'memuat': true,
      });

  final LayananAdmin layanan;

  final _galat = StreamController<String>.broadcast();

  /// pesan galat dari server, ditampilin jadi snackbar di main.dart
  Stream<String> get galat => _galat.stream;

  String get filter => state['filter'] as String;

  List<Map<String, dynamic>> get mitra =>
      state['mitra'] as List<Map<String, dynamic>>;

  bool get memuat => state['memuat'] as bool;

  Future<void> muat() async {
    emit({...state, 'memuat': true});
    final dimuat = filter;
    try {
      final daftar = await layanan.daftarMitra(status: dimuat);
      // filter keburu diganti pas lagi nunggu server: hasil lama dibuang
      if (!isClosed && dimuat == filter) {
        emit({...state, 'mitra': daftar, 'memuat': false});
      }
    } on GagalLayanan catch (e) {
      if (isClosed) return;
      emit({...state, 'memuat': false});
      _galat.add(e.pesan);
    }
  }

  Future<void> pilihFilter(String filter) {
    emit({...state, 'filter': filter, 'mitra': <Map<String, dynamic>>[]});
    return muat();
  }

  /// true kalau berhasil, daftar langsung dimuat ulang
  Future<bool> periksa(String id, String status, {String alasan = ''}) async {
    try {
      await layanan.periksa(id, status, alasan: alasan);
    } on GagalLayanan catch (e) {
      if (!_galat.isClosed) _galat.add(e.pesan);
      return false;
    }
    await muat();
    return true;
  }

  @override
  Future<void> close() {
    _galat.close();
    return super.close();
  }
}
