import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/domain/repositories/layanan_pesanan.dart';
import 'package:sisa_rasa/domain/repositories/layanan_voucher.dart';

/// voucher platform. state: tersedia (buat pembeli di checkout),
/// semua (buat admin), memuat
class VoucherCubit extends Cubit<Map<String, dynamic>> {
  VoucherCubit({required this.layanan})
    : super(const {
        'tersedia': <Map<String, dynamic>>[],
        'semua': <Map<String, dynamic>>[],
        'memuat': false,
      });

  final LayananVoucher layanan;

  final _galat = StreamController<String>.broadcast();

  /// pesan galat dari server, ditampilin jadi snackbar
  Stream<String> get galat => _galat.stream;

  List<Map<String, dynamic>> get tersedia =>
      state['tersedia'] as List<Map<String, dynamic>>;
  List<Map<String, dynamic>> get semua =>
      state['semua'] as List<Map<String, dynamic>>;
  bool get memuat => state['memuat'] as bool;

  Future<void> _muat(
    String kunci,
    Future<List<Map<String, dynamic>>> Function() ambil,
  ) async {
    emit({...state, 'memuat': true});
    try {
      final daftar = await ambil();
      if (!isClosed) emit({...state, kunci: daftar, 'memuat': false});
    } on GagalLayanan catch (e) {
      if (isClosed) return;
      emit({...state, 'memuat': false});
      _galat.add(e.pesan);
    }
  }

  Future<void> muatTersedia() => _muat('tersedia', layanan.tersedia);

  Future<void> muatSemua() => _muat('semua', layanan.semua);

  /// cek kode di checkout. hasilnya {voucher, potongan}, atau lempar
  /// GagalLayanan berisi alasannya (ditampilin di bawah kolom kode)
  Future<Map<String, dynamic>> cek(String kode, int subtotal) =>
      layanan.cek(kode, subtotal);

  /// admin bikin voucher. lempar GagalLayanan kalau isiannya ditolak
  Future<void> buat(Map<String, dynamic> isian) async {
    final v = await layanan.buat(isian);
    if (isClosed) return;
    emit({
      ...state,
      'semua': [v, ...semua],
    });
  }

  Future<void> aturAktif(String id, {required bool aktif}) async {
    try {
      final v = await layanan.aturAktif(id, aktif: aktif);
      if (isClosed) return;
      emit({
        ...state,
        'semua': [
          for (final lama in semua)
            if (lama['id'] == id) v else lama,
        ],
      });
    } on GagalLayanan catch (e) {
      if (!_galat.isClosed) _galat.add(e.pesan);
    }
  }

  @override
  Future<void> close() {
    _galat.close();
    return super.close();
  }
}
