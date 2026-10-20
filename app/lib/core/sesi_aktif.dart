/// token sesi akun yang lagi masuk, dibaca klien API tiap kirim request.
/// diisi dari AkunCubit (lihat main.dart), jadi repository di data/
/// ga perlu tau soal cubit
class SesiAktif {
  String? token;
}
