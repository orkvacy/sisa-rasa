import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/cubit/paket_cubit.dart';
import 'package:sisa_rasa/screens/cari.dart';
import 'package:sisa_rasa/screens/detail_paket.dart';
import 'package:sisa_rasa/screens/halaman_utama.dart';
import 'package:sisa_rasa/screens/keranjang.dart';
import 'package:sisa_rasa/screens/kode_ambil.dart';

/// semua alamat halaman dikumpulin di sini (NF-05),
/// jadi ga ada lagi MaterialPageRoute yg kesebar di tiap layar.
/// pindah halaman cukup context.push(Rute.xxx), balik pake context.pop()
abstract final class Rute {
  static const utama = '/';
  static const cari = '/cari';
  static const keranjang = '/keranjang';

  static String paket(String id) => '/paket/$id';

  /// baru = true kalau dibuka langsung abis pesanan dibuat
  static String kodeAmbil(String kode, {bool baru = false}) =>
      '/kode-ambil/$kode${baru ? '?baru=1' : ''}';
}

/// dibikin lewat fungsi, bukan variabel global,
/// biar tiap SisaRasaApp (termasuk di tes) punya router sendiri dari awal
GoRouter buatRouter() {
  return GoRouter(
    initialLocation: Rute.utama,
    routes: [
      GoRoute(
        path: Rute.utama,
        builder: (context, state) => const HalamanUtama(),
      ),
      GoRoute(
        path: Rute.cari,
        builder: (context, state) => Cari(
          onBukaPaket: (paket) => context.push(Rute.paket(paket['id'])),
        ),
      ),
      // paket diambil dari PaketCubit pake id di alamat,
      // jadi halaman detail selalu dapet sisa porsi yg paling baru
      GoRoute(
        path: '/paket/:id',
        builder: (context, state) => DetailPaket(
          paket: context.read<PaketCubit>().cari(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: Rute.keranjang,
        builder: (context, state) => const Keranjang(),
      ),
      GoRoute(
        path: '/kode-ambil/:kode',
        builder: (context, state) {
          final kode = state.pathParameters['kode']!;
          final pesanan = context.read<PesananBloc>().state.firstWhere(
            (pesanan) => pesanan['kode'] == kode,
          );
          return KodeAmbil(
            pesanan: pesanan,
            pesananBaru: state.uri.queryParameters['baru'] == '1',
          );
        },
      ),
    ],
  );
}
