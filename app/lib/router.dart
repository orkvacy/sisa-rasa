import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/cubit/paket_cubit.dart';
import 'package:sisa_rasa/screens/akun.dart';
import 'package:sisa_rasa/screens/beranda.dart';
import 'package:sisa_rasa/screens/cari.dart';
import 'package:sisa_rasa/screens/checkout.dart';
import 'package:sisa_rasa/screens/detail_paket.dart';
import 'package:sisa_rasa/screens/halaman_utama.dart';
import 'package:sisa_rasa/screens/keranjang.dart';
import 'package:sisa_rasa/screens/kode_ambil.dart';
import 'package:sisa_rasa/screens/pembayaran.dart';
import 'package:sisa_rasa/screens/pesanan.dart';

/// semua alamat halaman dikumpulin di sini (NF-05),
/// jadi ga ada lagi MaterialPageRoute yg kesebar di tiap layar.
///
/// tiap tab punya cabang sendiri (/beranda, /pesanan, /akun).
/// layar lain nempel di cabang tab asalnya, tapi digambar full layar (navigasi bawah ketutup).
/// pindah halaman pake context.push(Rute.xxx), balik pake context.pop(),
/// context.go(Rute.xxx) dipake kalau semua layar di belakangnya mau ditutup
abstract final class Rute {
  static const beranda = '/beranda';
  static const pesanan = '/pesanan';
  static const akun = '/akun';

  static const cari = '/beranda/cari';
  static const keranjang = '/beranda/keranjang';
  static const checkout = '/beranda/checkout';
  static String paket(String id) => '/beranda/paket/$id';

  // pembayaran sama kode ambil nempel di tab pesanan,
  // jadi tombol kembalinya balik ke daftar pesanan
  static String pembayaran(String id) => '/pesanan/pembayaran/$id';

  /// baru = true kalau dibuka langsung abis pesanan lunas
  static String kodeAmbil(String kode, {bool baru = false}) =>
      '/pesanan/kode-ambil/$kode${baru ? '?baru=1' : ''}';
}

/// dibikin lewat fungsi, bukan variabel global,
/// biar tiap SisaRasaApp (termasuk di tes) punya router sama navigator sendiri dari awal
GoRouter buatRouter() {
  // navigator paling luar, layar full (detail, checkout, dll) ditaruh di sini
  final akar = GlobalKey<NavigatorState>();

  GoRoute layarPenuh(String path, GoRouterWidgetBuilder builder) {
    return GoRoute(path: path, parentNavigatorKey: akar, builder: builder);
  }

  return GoRouter(
    navigatorKey: akar,
    initialLocation: Rute.beranda,
    routes: [
      GoRoute(path: '/', redirect: (context, state) => Rute.beranda),
      // StatefulShellRoute: tab bawah, isi tiap tab ga ke-reset pas pindah tab
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HalamanUtama(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rute.beranda,
                builder: (context, state) => Beranda(
                  onBukaPaket: (paket) => context.push(Rute.paket(paket['id'])),
                ),
                routes: [
                  layarPenuh(
                    'cari',
                    (context, state) => Cari(
                      onBukaPaket: (paket) =>
                          context.push(Rute.paket(paket['id'])),
                    ),
                  ),
                  // paket diambil dari PaketCubit pake id di alamat,
                  // jadi halaman detail selalu dapet sisa porsi yg paling baru
                  layarPenuh(
                    'paket/:id',
                    (context, state) => DetailPaket(
                      paket: context.read<PaketCubit>().cari(
                        state.pathParameters['id']!,
                      ),
                    ),
                  ),
                  layarPenuh(
                    'keranjang',
                    (context, state) => const Keranjang(),
                  ),
                  layarPenuh('checkout', (context, state) => const Checkout()),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rute.pesanan,
                builder: (context, state) => Pesanan(
                  onBukaKode: (pesanan) =>
                      context.push(Rute.kodeAmbil(pesanan['kode'])),
                  onBayar: (pesanan) =>
                      context.push(Rute.pembayaran(pesanan['id'])),
                  onCariPaket: () => context.go(Rute.beranda),
                ),
                routes: [
                  layarPenuh(
                    'pembayaran/:id',
                    (context, state) =>
                        Pembayaran(idPesanan: state.pathParameters['id']!),
                  ),
                  layarPenuh('kode-ambil/:kode', (context, state) {
                    final kode = state.pathParameters['kode']!;
                    final pesanan = context
                        .read<PesananBloc>()
                        .state
                        .firstWhere((pesanan) => pesanan['kode'] == kode);
                    return KodeAmbil(
                      pesanan: pesanan,
                      pesananBaru: state.uri.queryParameters['baru'] == '1',
                    );
                  }),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rute.akun,
                builder: (context, state) => const Akun(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
