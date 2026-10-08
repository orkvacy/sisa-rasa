import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/data/dummy_akun.dart';

/// akun yg lagi dipake. sementara dipilih dari dummyAkun,
/// nanti diisi dari hasil login
class AkunCubit extends Cubit<Map<String, String>> {
  AkunCubit() : super(dummyAkun.first);

  void ganti(String id) {
    emit(dummyAkun.firstWhere((akun) => akun['id'] == id));
  }
}

String namaPeran(String peran) => switch (peran) {
  'mitra' => 'Mitra',
  'admin' => 'Admin',
  _ => 'Pembeli',
};

/// dua huruf depan nama, dipake di avatar. "Rani Amelia" -> "RA"
String inisial(String nama) {
  final kata = nama.trim().split(RegExp(r'\s+'));
  if (kata.length == 1) return kata.first.substring(0, 1).toUpperCase();
  return (kata[0][0] + kata[1][0]).toUpperCase();
}
