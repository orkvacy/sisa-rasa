import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sisa_rasa/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/cubit/akun_cubit.dart';
import 'package:sisa_rasa/cubit/keranjang_cubit.dart';
import 'package:sisa_rasa/cubit/paket_cubit.dart';
import 'package:sisa_rasa/cubit/saldo_cubit.dart';
import 'package:sisa_rasa/data/layanan_akun.dart';
import 'package:sisa_rasa/router.dart';
import 'package:sisa_rasa/theme/tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // sesi yg tersimpan dicek dulu sebelum layar pertama digambar,
  // biar yg udah masuk ga sempet liat layar Sambutan
  final akun = AkunCubit(layanan: AkunTiruan());
  await akun.pulihkan();
  runApp(SisaRasaApp(akun: akun));
}

class SisaRasaApp extends StatefulWidget {
  /// [akun] boleh kosong (di tes), nanti dibikin sendiri dan mulai dari [akunAwal]
  const SisaRasaApp({this.akun, this.akunAwal = const {}, super.key});

  final AkunCubit? akun;
  final Map<String, String> akunAwal;

  @override
  State<SisaRasaApp> createState() => _SisaRasaAppState();
}

class _SisaRasaAppState extends State<SisaRasaApp> {
  // akun dibikin di sini (bukan di BlocProvider) soalnya router butuh dengerin akunnya
  late final akun =
      widget.akun ?? AkunCubit(layanan: AkunTiruan(), awal: widget.akunAwal);
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
        BlocProvider(create: (context) => PaketCubit()),
        BlocProvider(create: (context) => KeranjangCubit()),
        BlocProvider(create: (context) => SaldoCubit()),
        // PesananBloc nahan / ngelepas stok lewat PaketCubit yg dipasang di atasnya
        BlocProvider(
          create: (context) {
            final paket = context.read<PaketCubit>();
            return PesananBloc(
              tahanPorsi: paket.kurangiStok,
              lepasPorsi: paket.kembalikanStok,
            );
          },
        ),
      ],
      // MaterialApp.router: akar aplikasi, halamannya diatur GoRouter (lihat router.dart)
      child: MaterialApp.router(
        title: 'Sisa Rasa',
        debugShowCheckedModeBanner: false,
        // tema dari figma v3 (token warna + tipografi), lihat theme/tema.dart
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
