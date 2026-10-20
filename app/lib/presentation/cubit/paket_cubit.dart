import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/domain/repositories/layanan_paket.dart';
import 'package:sisa_rasa/domain/repositories/layanan_pesanan.dart';
import 'package:sisa_rasa/core/utils/format.dart';

// nyimpen daftar paket + sisa porsinya
// state nya List paket, tiap ada yg berubah emit list baru
class PaketCubit extends Cubit<List<Map<String, dynamic>>> {
  // mulai kosong, isinya diambil dari LayananPaket lewat muat()
  PaketCubit({required this.layanan}) : super(const []);

  final LayananPaket layanan;

  final _galat = StreamController<String>.broadcast();

  /// pesan galat dari server, ditampilin jadi snackbar di main.dart
  Stream<String> get galat => _galat.stream;

  /// dipanggil pas aplikasi dibuka, dan berkala kalau tersambung server
  /// (stok berubah karena pembeli lain pesan)
  Future<void> muat() async {
    try {
      final daftar = await layanan.semua();
      if (!isClosed) emit(daftar);
    } on GagalLayanan catch (e) {
      if (!_galat.isClosed) _galat.add(e.pesan);
    }
  }

  /// status verifikasi gerai mitra yang lagi masuk (F-37).
  /// null kalau gagal dimuat, banner di dasbor ga ditampilin
  Future<Map<String, dynamic>?> statusGerai() async {
    try {
      return await layanan.statusGerai();
    } on GagalLayanan {
      return null;
    }
  }

  /// unggah foto paket yang dipilih mitra. null kalau gagal (pesannya ke [galat])
  Future<String?> unggahFoto(String jalur) async {
    try {
      return await layanan.unggahFoto(jalur);
    } on GagalLayanan catch (e) {
      if (!_galat.isClosed) _galat.add(e.pesan);
      return null;
    }
  }

  /// perubahan dari mitra: layar langsung keubah duluan (di atas), baru dikirim
  /// ke server. kalau server nolak, daftar dimuat ulang biar balik ke data asli
  void _kirim(Future<void> Function() aksi) {
    if (layanan.lokal) return;
    unawaited(() async {
      try {
        await aksi();
      } on GagalLayanan catch (e) {
        if (!_galat.isClosed) _galat.add(e.pesan);
      }
      await muat();
    }());
  }

  @override
  Future<void> close() {
    _galat.close();
    return super.close();
  }

  Map<String, dynamic> cari(String id) {
    return state.firstWhere((paket) => paket['id'] == id);
  }

  // dipanggil pas pesanan dibuat, sisa porsi dikurangin sesuai isi keranjang
  // porsinya ditahan buat pembeli selama nunggu dibayar (F-23, F-40)
  void kurangiStok(Map<String, int> keranjang) {
    emit([
      for (final paket in state)
        {
          ...paket,
          'sisaPorsi': paket['sisaPorsi'] - (keranjang[paket['id']] ?? 0),
        },
    ]);
  }

  // kebalikannya, dipanggil pas pesanan batal sebelum dibayar (F-40)
  void kembalikanStok(Map<String, int> porsiPaket) {
    emit([
      for (final paket in state)
        {
          ...paket,
          'sisaPorsi': paket['sisaPorsi'] + (porsiPaket[paket['id']] ?? 0),
        },
    ]);
  }

  // mitra ubah sisa porsi langsung dari daftar (F-44)
  void ubahSisa(String id, int sisa) {
    _kirim(() => layanan.aturSisa(id, sisa));
    emit([
      for (final paket in state)
        if (paket['id'] == id) {...paket, 'sisaPorsi': sisa} else paket,
    ]);
  }

  // mitra tutup / buka gerai sementara, paketnya ga tampil buat pembeli (F-51)
  void aturGerai(String mitra, {required bool buka}) {
    _kirim(() => layanan.aturGerai(tutup: !buka));
    emit([
      for (final paket in state)
        if (paket['mitra'] == mitra) {...paket, 'geraiTutup': !buka} else paket,
    ]);
  }

  bool geraiBuka(String mitra) =>
      !state.any((p) => p['mitra'] == mitra && p['geraiTutup'] == true);

  /// paket yg boleh keliatan di sisi pembeli: belum lewat jam tutup (F-25),
  /// gerainya buka (F-51), dan ga dinonaktifkan mitra (F-45)
  static bool tampilUntukPembeli(Map<String, dynamic> paket) =>
      paket['tutup'] > jamSekarang &&
      paket['geraiTutup'] != true &&
      paket['nonaktif'] != true;

  var _nomorBaru = 0;

  /// mitra nambah paket (F-15), langsung tersedia sampai jam tutup ambil.
  /// data gerai (alamat, jarak, jenis) disalin dari paket mitra yg udah ada
  String tambahPaket(Map<String, dynamic> isian) {
    final gerai = state.where((p) => p['mitra'] == isian['mitra']).firstOrNull;
    _nomorBaru++;
    final id = 'pm-${DateTime.now().millisecondsSinceEpoch}-$_nomorBaru';
    _kirim(() => layanan.tambah(isian));
    emit([
      ...state,
      {
        'jenisMitra': gerai?['jenisMitra'] ?? 'Mitra',
        'alamat': gerai?['alamat'] ?? '',
        'jarak': gerai?['jarak'] ?? '',
        'foto': gerai?['foto'] ?? 'assets/images/paket/buffet_hotel.jpg',
        'geraiTutup': gerai?['geraiTutup'] ?? false,
        ...isian,
        'id': id,
        'sisaPorsi': isian['totalPorsi'],
      },
    ]);
    return id;
  }

  /// mitra ubah paket (F-18). kalau jumlah porsinya diganti,
  /// sisa porsi ikut geser sebanyak selisihnya
  void ubahPaket(String id, Map<String, dynamic> isian) {
    // server butuh isian lengkap (foto, halal, dst), jadi digabung sama data lama
    _kirim(() => layanan.ubah(id, {...cari(id), ...isian}));
    emit([
      for (final paket in state)
        if (paket['id'] == id)
          {
            ...paket,
            ...isian,
            'sisaPorsi':
                ((paket['sisaPorsi'] as int) +
                        (isian['totalPorsi'] as int) -
                        (paket['totalPorsi'] as int))
                    .clamp(0, isian['totalPorsi'] as int),
          }
        else
          paket,
    ]);
  }

  void hapusPaket(String id) {
    _kirim(() => layanan.hapus(id));
    emit([
      for (final paket in state)
        if (paket['id'] != id) paket,
    ]);
  }

  /// aktif / nonaktifin paket, yg nonaktif ga tampil buat pembeli (F-45)
  void aturAktif(String id, {required bool aktif}) {
    _kirim(() => layanan.aturAktif(id, aktif: aktif));
    emit([
      for (final paket in state)
        if (paket['id'] == id) {...paket, 'nonaktif': !aktif} else paket,
    ]);
  }
}
