import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/core/sesi_aktif.dart';
import 'package:sisa_rasa/core/utils/format.dart';
import 'package:sisa_rasa/presentation/bloc/pesanan_event.dart';
import 'package:sisa_rasa/presentation/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/presentation/cubit/akun_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/keranjang_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/paket_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/percakapan_cubit.dart';
import 'package:sisa_rasa/presentation/cubit/saldo_cubit.dart';
import 'package:sisa_rasa/injection.dart';
import 'package:sisa_rasa/presentation/router.dart';
import 'package:sisa_rasa/core/theme/tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  daftarkanDependensi();
  // tersambung server: jam asli, sama kayak server
  if (pakaiServer) jamTetap = null;
  // sesi yg tersimpan dicek dulu sebelum layar pertama digambar,
  // biar yg udah masuk ga sempet liat layar Sambutan
  final akun = AkunCubit(layanan: sl());
  await akun.pulihkan();
  runApp(SisaRasaApp(akun: akun));
}

class SisaRasaApp extends StatefulWidget {
  /// [akun] boleh kosong (di tes), nanti dibikin sendiri dan mulai dari [akunAwal].
  /// dependensinya harus udah didaftarin dulu lewat daftarkanDependensi()
  const SisaRasaApp({this.akun, this.akunAwal = const {}, super.key});

  final AkunCubit? akun;
  final Map<String, String> akunAwal;

  @override
  State<SisaRasaApp> createState() => _SisaRasaAppState();
}

class _SisaRasaAppState extends State<SisaRasaApp> {
  // akun dibikin di sini (bukan di BlocProvider) soalnya router butuh dengerin akunnya
  late final akun =
      widget.akun ?? AkunCubit(layanan: sl(), awal: widget.akunAwal);
  // router dibikin sekali aja, kalau di build bakal ke-reset tiap digambar ulang
  late final GoRouter router = buatRouter(akun: akun);
  // buat nampilin galat dari server di layar mana pun
  final pesanGalat = GlobalKey<ScaffoldMessengerState>();

  @override
  void dispose() {
    router.dispose();
    akun.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // MultiBlocProvider: cubit sama bloc dipasang paling luar,
    // biar semua halaman yg dibuka lewat router bisa akses
    return MultiBlocProvider(
      providers: [
        // BlocProvider: nyediain satu cubit/bloc biar bisa diambil halaman di bawahnya
        BlocProvider.value(value: akun),
        // isi tiap cubit diambil dari repository yg didaftarin di injection.dart
        BlocProvider(create: (context) => PaketCubit(layanan: sl())..muat()),
        BlocProvider(create: (context) => KeranjangCubit()),
        BlocProvider(create: (context) => SaldoCubit(layanan: sl())),
        BlocProvider(create: (context) => PercakapanCubit(layanan: sl())),
        // PesananBloc nahan / ngelepas stok lewat PaketCubit yg dipasang di atasnya
        BlocProvider(
          create: (context) {
            final paket = context.read<PaketCubit>();
            // tersambung server: stok diurus server, paket cukup dimuat ulang
            return pakaiServer
                ? PesananBloc(
                    pembayaran: sl(),
                    server: sl(),
                    muatUlangPaket: paket.muat,
                  )
                : PesananBloc(
                    pembayaran: sl(),
                    tahanPorsi: paket.kurangiStok,
                    lepasPorsi: paket.kembalikanStok,
                  );
          },
        ),
      ],
      // _Sinkron: nyocokin data di HP sama server selama aplikasi kebuka
      child: _Sinkron(
        pesanGalat: pesanGalat,
        // MaterialApp.router: akar aplikasi, halamannya diatur GoRouter (lihat presentation/router.dart)
        child: MaterialApp.router(
          scaffoldMessengerKey: pesanGalat,
          title: 'Sisa Rasa',
          debugShowCheckedModeBanner: false,
          // tema dari figma v3 (token warna + tipografi), lihat core/theme/tema.dart
          theme: SisaRasaTema.terang(),
          darkTheme: SisaRasaTema.gelap(),
          // dikunci terang dulu, layar-layar masih pake Warna statis.
          // ganti ke ThemeMode.system kalau semua layar udah pindah ke tema
          themeMode: ThemeMode.light,
          // halaman awal (yg ada navigation bar nya) ditentuin router di Rute.utama
          routerConfig: router,
        ),
      ),
    );
  }
}

/// kerja di belakang layar selama aplikasi kebuka:
/// - token akun yg lagi masuk dioper ke klien API (SesiAktif)
/// - tersambung server: pesanan dimuat ulang tiap 5 detik dan paket tiap 20 detik,
///   biar HP mitra liat pesanan baru dan HP pembeli liat status + stok terbaru
/// - galat dari server ditampilin jadi snackbar
class _Sinkron extends StatefulWidget {
  const _Sinkron({required this.pesanGalat, required this.child});

  final GlobalKey<ScaffoldMessengerState> pesanGalat;
  final Widget child;

  @override
  State<_Sinkron> createState() => _SinkronState();
}

class _SinkronState extends State<_Sinkron> {
  final _langganan = <StreamSubscription<Object?>>[];
  Timer? _detak;
  var _putaran = 0;

  @override
  void initState() {
    super.initState();
    final akun = context.read<AkunCubit>();
    final pesanan = context.read<PesananBloc>();
    final paket = context.read<PaketCubit>();

    void tampilkan(String pesan) => widget.pesanGalat.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(pesan)));

    _langganan
      ..add(pesanan.galat.listen(tampilkan))
      ..add(paket.galat.listen(tampilkan))
      ..add(context.read<SaldoCubit>().galat.listen(tampilkan))
      ..add(akun.stream.listen(_akunBerubah));
    _akunBerubah(akun.state);

    if (pakaiServer) {
      _detak = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!akun.sudahMasuk) return;
        pesanan.add(PesananDimuat());
        if (++_putaran % 4 == 0) {
          paket.muat();
          // saldo mitra: pencairan harian dan rekening dari server
          final nama = akun.state['nama'];
          if (akun.state['peran'] == 'mitra' && nama != null) {
            context.read<SaldoCubit>().muat(nama);
          }
        }
      });
    }
  }

  String? _idAkun;

  void _akunBerubah(Map<String, String> akun) {
    sl<SesiAktif>().token = akun['token'];
    if (!pakaiServer || akun['id'] == _idAkun) return;
    _idAkun = akun['id'];
    // ganti akun / keluar: pesanan akun lama dibuang, lalu ambil punya akun baru
    context.read<PercakapanCubit>().kosongkan();
    final pesanan = context.read<PesananBloc>()..add(PesananDikosongkan());
    if (akun['id'] != null) pesanan.add(PesananDimuat());
  }

  @override
  void dispose() {
    _detak?.cancel();
    for (final l in _langganan) {
      l.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
