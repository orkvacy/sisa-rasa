import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/cubit/akun_cubit.dart';
import 'package:sisa_rasa/cubit/paket_cubit.dart';
import 'package:sisa_rasa/screens/akun.dart';
import 'package:sisa_rasa/screens/auth/daftar.dart';
import 'package:sisa_rasa/screens/auth/ketentuan.dart';
import 'package:sisa_rasa/screens/auth/masuk.dart';
import 'package:sisa_rasa/screens/auth/sambutan.dart';
import 'package:sisa_rasa/screens/beranda.dart';
import 'package:sisa_rasa/screens/cari.dart';
import 'package:sisa_rasa/screens/checkout.dart';
import 'package:sisa_rasa/screens/detail_paket.dart';
import 'package:sisa_rasa/screens/detail_pesanan.dart';
import 'package:sisa_rasa/screens/halaman_mitra.dart';
import 'package:sisa_rasa/screens/halaman_utama.dart';
import 'package:sisa_rasa/screens/keranjang.dart';
import 'package:sisa_rasa/screens/kode_ambil.dart';
import 'package:sisa_rasa/screens/mitra/dasbor.dart';
import 'package:sisa_rasa/screens/mitra/detail_pesanan_mitra.dart';
import 'package:sisa_rasa/screens/mitra/form_paket.dart';
import 'package:sisa_rasa/screens/mitra/halaman_utama_mitra.dart';
import 'package:sisa_rasa/screens/mitra/paket_mitra.dart';
import 'package:sisa_rasa/screens/mitra/ketik_kode.dart';
import 'package:sisa_rasa/screens/mitra/pesanan_masuk.dart';
import 'package:sisa_rasa/screens/mitra/rekening.dart';
import 'package:sisa_rasa/screens/mitra/saldo.dart';
import 'package:sisa_rasa/screens/mitra/scan_kode.dart';
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
  // layar umum, kebuka sebelum masuk (layar 12, 13 di SRS)
  static const sambutan = '/sambutan';
  static const masuk = '/masuk';
  static const daftar = '/daftar';
  static const ketentuan = '/ketentuan';

  /// masuk / daftar, abis itu balik ke [dari] (dipake tamu yg mau checkout)
  static String masukLalu(String dari) =>
      '$masuk?dari=${Uri.encodeComponent(dari)}';
  static String daftarLalu(String? dari) =>
      dari == null ? daftar : '$daftar?dari=${Uri.encodeComponent(dari)}';

  static const beranda = '/beranda';
  static const pesanan = '/pesanan';
  static const akun = '/akun';

  static const cari = '/beranda/cari';
  static const keranjang = '/beranda/keranjang';
  static const checkout = '/beranda/checkout';
  static String paket(String id) => '/beranda/paket/$id';
  // nama mitra dipake sebagai id sementara (data dummy belum punya id mitra),
  // di-encode biar spasi sama simbol aman di alamat
  static String mitra(String nama) =>
      '/beranda/mitra/${Uri.encodeComponent(nama)}';

  // pembayaran sama kode ambil nempel di tab pesanan,
  // jadi tombol kembalinya balik ke daftar pesanan
  static String pembayaran(String id) => '/pesanan/pembayaran/$id';

  static String detailPesanan(String id) => '/pesanan/detail/$id';

  /// kode QR layar penuh, dibuka dari pesanan yg kodenya ini
  static String kodeAmbil(String kode) => '/pesanan/kode-ambil/$kode';

  // sisi mitra (layar 9-11b di SRS), cuma kebuka kalau akun yg masuk perannya mitra
  static const mitraDasbor = '/mitra/dasbor';
  static const mitraPaket = '/mitra/paket';
  static const mitraPesanan = '/mitra/pesanan';
  static const mitraSaldo = '/mitra/saldo';
  static const mitraAkun = '/mitra/dasbor/akun';
  static const mitraPaketBaru = '/mitra/paket/baru';
  static const mitraRekening = '/mitra/saldo/rekening';
  // pindai / ketik kode ambil nempel di tab pesanan mitra
  static const mitraScan = '/mitra/pesanan/scan';
  static const mitraKetikKode = '/mitra/pesanan/ketik-kode';
  static String mitraUbahPaket(String id) => '/mitra/paket/ubah/$id';
  static String mitraDetailPesanan(String id) => '/mitra/pesanan/detail/$id';
}

/// GoRouter dengerin AkunCubit lewat ini, biar pas ganti akun redirect-nya jalan lagi
class _DengarAkun extends ChangeNotifier {
  _DengarAkun(Stream<Object?> stream) {
    _langganan = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _langganan;

  @override
  void dispose() {
    _langganan.cancel();
    super.dispose();
  }
}

/// dibikin lewat fungsi, bukan variabel global,
/// biar tiap SisaRasaApp (termasuk di tes) punya router sama navigator sendiri dari awal
GoRouter buatRouter({required AkunCubit akun}) {
  // navigator paling luar, layar full (detail, checkout, dll) ditaruh di sini
  final akar = GlobalKey<NavigatorState>();

  GoRoute layarPenuh(String path, GoRouterWidgetBuilder builder) {
    return GoRoute(path: path, parentNavigatorKey: akar, builder: builder);
  }

  return GoRouter(
    navigatorKey: akar,
    refreshListenable: _DengarAkun(akun.stream),
    redirect: (context, state) {
      final lokasi = state.matchedLocation;
      // ketentuan boleh dibuka siapa aja, termasuk dari form daftar
      if (lokasi == Rute.ketentuan) return null;
      final layarUmum =
          lokasi == Rute.sambutan ||
          lokasi == Rute.masuk ||
          lokasi == Rute.daftar;

      // belum masuk dan belum milih "Lihat paket dulu"
      if (akun.state.isEmpty) return layarUmum ? null : Rute.sambutan;

      // tamu cuma boleh lihat-lihat. pesanan, akun, checkout harus masuk dulu,
      // abis masuk langsung dibalikin ke halaman yg tadi dituju
      if (akun.tamu) {
        if (lokasi == Rute.sambutan) return Rute.beranda;
        final perluAkun =
            lokasi.startsWith(Rute.pesanan) ||
            lokasi.startsWith(Rute.akun) ||
            lokasi == Rute.checkout ||
            lokasi.startsWith('/mitra');
        if (perluAkun) return Rute.masukLalu(state.uri.toString());
        return null;
      }

      // udah masuk: layar sambutan / masuk / daftar ga perlu lagi
      if (layarUmum) return state.uri.queryParameters['dari'] ?? Rute.beranda;

      // F-26 / F-32: halaman yg kebuka ditentuin peran akun yg lagi masuk.
      // mitra ga bisa buka halaman pembeli, pembeli ga bisa buka halaman mitra
      final mitra = akun.state['peran'] == 'mitra';
      final diHalamanMitra = lokasi.startsWith('/mitra');
      if (mitra && !diHalamanMitra) return Rute.mitraDasbor;
      if (!mitra && diHalamanMitra) return Rute.beranda;
      return null;
    },
    initialLocation: Rute.beranda,
    routes: [
      GoRoute(path: '/', redirect: (context, state) => Rute.beranda),
      GoRoute(
        path: Rute.sambutan,
        builder: (context, state) => const Sambutan(),
      ),
      GoRoute(
        path: Rute.masuk,
        builder: (context, state) =>
            Masuk(dari: state.uri.queryParameters['dari']),
      ),
      GoRoute(
        path: Rute.daftar,
        builder: (context, state) =>
            Daftar(dari: state.uri.queryParameters['dari']),
      ),
      GoRoute(
        path: Rute.ketentuan,
        builder: (context, state) => const Ketentuan(),
      ),
      // StatefulShellRoute: tab bawah, isi tiap tab ga ke-reset pas pindah tab
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HalamanUtama(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rute.beranda,
                builder: (context, state) => Beranda(
                  onBukaMitra: (nama) => context.push(Rute.mitra(nama)),
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
                    'mitra/:nama',
                    (context, state) =>
                        HalamanMitra(nama: state.pathParameters['nama']!),
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
                  onBukaDetail: (pesanan) =>
                      context.push(Rute.detailPesanan(pesanan['id'])),
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
                  layarPenuh(
                    'detail/:id',
                    (context, state) =>
                        DetailPesanan(idPesanan: state.pathParameters['id']!),
                  ),
                  layarPenuh(
                    'kode-ambil/:kode',
                    (context, state) =>
                        KodeAmbil(kode: state.pathParameters['kode']!),
                  ),
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
      // tab mitra: Dasbor, Paket, (tombol pindai di tengah), Pesanan, Saldo
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HalamanUtamaMitra(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rute.mitraDasbor,
                builder: (context, state) => const Dasbor(),
                routes: [layarPenuh('akun', (context, state) => const Akun())],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rute.mitraPaket,
                builder: (context, state) => const PaketMitra(),
                routes: [
                  layarPenuh('baru', (context, state) => const FormPaket()),
                  layarPenuh(
                    'ubah/:id',
                    (context, state) =>
                        FormPaket(idPaket: state.pathParameters['id']),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rute.mitraPesanan,
                builder: (context, state) => const PesananMasuk(),
                routes: [
                  layarPenuh('scan', (context, state) => const ScanKode()),
                  layarPenuh(
                    'ketik-kode',
                    (context, state) => const KetikKode(),
                  ),
                  layarPenuh(
                    'detail/:id',
                    (context, state) => DetailPesananMitra(
                      idPesanan: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rute.mitraSaldo,
                builder: (context, state) => const Saldo(),
                routes: [
                  layarPenuh(
                    'rekening',
                    (context, state) => const RekeningPencairan(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
