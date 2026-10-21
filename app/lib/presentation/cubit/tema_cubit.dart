import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Kelola tema aplikasi (SRS F-27, NF-02):
/// - ThemeMode.system ('sistem')
/// - ThemeMode.light ('terang')
/// - ThemeMode.dark ('gelap')
class TemaCubit extends Cubit<ThemeMode> {
  TemaCubit({
    FlutterSecureStorage? penyimpanan,
    ThemeMode awal = ThemeMode.system,
  }) : _penyimpanan = penyimpanan ?? const FlutterSecureStorage(),
       super(awal);

  final FlutterSecureStorage _penyimpanan;
  static const _kunci = 'mode_tema';

  /// Pulihkan preferensi tema yang tersimpan di perangkat saat aplikasi dibuka
  Future<void> pulihkan() async {
    try {
      final tersimpan = await _penyimpanan.read(key: _kunci);
      if (tersimpan != null && !isClosed) {
        emit(dariString(tersimpan));
      }
    } catch (_) {
      // jika ada kendala pembacaan secure storage, tetap pada default
    }
  }

  /// Ganti tema dan simpan preferensi ke secure storage
  Future<void> ganti(ThemeMode mode) async {
    emit(mode);
    try {
      await _penyimpanan.write(key: _kunci, value: keString(mode));
    } catch (_) {}
  }

  static String label(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'Terang',
    ThemeMode.dark => 'Gelap',
    ThemeMode.system => 'Ikuti sistem',
  };

  static ThemeMode dariString(String teks) => switch (teks) {
    'terang' => ThemeMode.light,
    'gelap' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static String keString(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'terang',
    ThemeMode.dark => 'gelap',
    ThemeMode.system => 'sistem',
  };
}
