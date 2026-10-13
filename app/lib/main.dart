import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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
            return PesananBloc(
              pembayaran: sl(),
              tahanPorsi: paket.kurangiStok,
              lepasPorsi: paket.kembalikanStok,
            );
          },
        ),
      ],
      // MaterialApp.router: akar aplikasi, halamannya diatur GoRouter (lihat presentation/router.dart)
      child: MaterialApp.router(
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
    );
  }
}
