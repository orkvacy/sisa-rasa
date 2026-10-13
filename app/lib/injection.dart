import 'package:get_it/get_it.dart';
import 'package:sisa_rasa/data/repositories/akun_tiruan.dart';
import 'package:sisa_rasa/data/repositories/paket_lokal.dart';
import 'package:sisa_rasa/data/repositories/pembayaran_tiruan.dart';
import 'package:sisa_rasa/data/repositories/percakapan_tiruan.dart';
import 'package:sisa_rasa/data/repositories/saldo_lokal.dart';
import 'package:sisa_rasa/domain/repositories/layanan_akun.dart';
import 'package:sisa_rasa/domain/repositories/layanan_paket.dart';
import 'package:sisa_rasa/domain/repositories/layanan_pembayaran.dart';
import 'package:sisa_rasa/domain/repositories/layanan_percakapan.dart';
import 'package:sisa_rasa/domain/repositories/layanan_saldo.dart';

/// service locator (GetIt). layar sama cubit cuma kenal kontrak di domain/,
/// implementasinya ditentuin di sini doang (NF-04).
///
/// pas backend Go jadi, cukup ganti barisnya, misal `PaketLokal.new` jadi `PaketApi.new`,
/// ga ada satu pun berkas di presentation/ yg perlu diubah
final sl = GetIt.instance;

void daftarkanDependensi() {
  sl
    ..registerLazySingleton<LayananAkun>(AkunTiruan.new)
    ..registerLazySingleton<LayananPaket>(PaketLokal.new)
    ..registerLazySingleton<LayananPembayaran>(PembayaranTiruan.new)
    ..registerLazySingleton<LayananPercakapan>(PercakapanTiruan.new)
    ..registerLazySingleton<LayananSaldo>(SaldoLokal.new);
}
