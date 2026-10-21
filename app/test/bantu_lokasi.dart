import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/domain/repositories/layanan_lokasi.dart';
import 'package:sisa_rasa/presentation/cubit/lokasi_cubit.dart';

/// lokasi buat tes yang masang layar langsung (tanpa SisaRasaApp)
class LokasiUji implements LayananLokasi {
  const LokasiUji([this.posisi]);

  /// null = izin lokasi belum dikasih
  final Posisi? posisi;

  @override
  Future<Posisi> posisiSaya({bool minta = true}) async =>
      posisi ?? (throw const GagalLokasi('Izin lokasi belum diberikan.'));

  @override
  Future<void> bukaSetelan({required bool gpsMati}) async {}
}

BlocProvider<LokasiCubit> lokasiUji([Posisi? posisi]) =>
    BlocProvider(create: (_) => LokasiCubit(layanan: LokasiUji(posisi)));
