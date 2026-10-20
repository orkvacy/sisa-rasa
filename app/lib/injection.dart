import 'package:get_it/get_it.dart';
import 'package:sisa_rasa/core/alamat.dart';
import 'package:sisa_rasa/core/sesi_aktif.dart';
import 'package:sisa_rasa/data/repositories/akun_api.dart';
import 'package:sisa_rasa/data/repositories/akun_tiruan.dart';
import 'package:sisa_rasa/data/repositories/paket_api.dart';
import 'package:sisa_rasa/data/repositories/paket_lokal.dart';
import 'package:sisa_rasa/data/repositories/pembayaran_tiruan.dart';
import 'package:sisa_rasa/data/repositories/percakapan_api.dart';
import 'package:sisa_rasa/data/repositories/percakapan_tiruan.dart';
import 'package:sisa_rasa/data/repositories/pesanan_api.dart';
import 'package:sisa_rasa/data/repositories/saldo_api.dart';
import 'package:sisa_rasa/data/repositories/saldo_lokal.dart';
import 'package:sisa_rasa/data/sumber/klien_api.dart';
import 'package:sisa_rasa/domain/repositories/layanan_akun.dart';
import 'package:sisa_rasa/domain/repositories/layanan_paket.dart';
import 'package:sisa_rasa/domain/repositories/layanan_pembayaran.dart';
import 'package:sisa_rasa/domain/repositories/layanan_percakapan.dart';
import 'package:sisa_rasa/domain/repositories/layanan_pesanan.dart';
import 'package:sisa_rasa/domain/repositories/layanan_saldo.dart';

/// service locator (GetIt). layar sama cubit cuma kenal kontrak di domain/,
/// implementasinya ditentuin di sini doang (NF-04)
final sl = GetIt.instance;

/// true kalau aplikasi tersambung server: akun, paket, dan pesanan dari API
bool get pakaiServer => sl.isRegistered<LayananPesanan>();

void daftarkanDependensi({String alamat = alamatApi}) {
  final sesi = SesiAktif();
  sl
    ..registerSingleton<SesiAktif>(sesi)
    // pembayaran masih tiruan di dua mode: server juga belum pakai Midtrans,
    // jadi layar pembayaran tetap nampilin keterangan mode uji
    ..registerLazySingleton<LayananPembayaran>(PembayaranTiruan.new);

  if (alamat.isEmpty) {
    sl
      ..registerLazySingleton<LayananAkun>(AkunTiruan.new)
      ..registerLazySingleton<LayananPaket>(PaketLokal.new)
      ..registerLazySingleton<LayananPercakapan>(PercakapanTiruan.new)
      ..registerLazySingleton<LayananSaldo>(SaldoLokal.new);
    return;
  }
  final klien = KlienApi(alamat: alamat, sesi: sesi);
  sl
    ..registerLazySingleton<LayananAkun>(() => AkunApi(alamat: alamat))
    ..registerLazySingleton<LayananPaket>(() => PaketApi(klien))
    ..registerLazySingleton<LayananPesanan>(() => PesananApi(klien))
    ..registerLazySingleton<LayananPercakapan>(() => PercakapanApi(klien))
    ..registerLazySingleton<LayananSaldo>(() => SaldoApi(klien));
}
