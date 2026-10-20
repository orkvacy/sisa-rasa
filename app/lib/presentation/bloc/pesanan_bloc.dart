import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/presentation/bloc/pesanan_event.dart';
import 'package:sisa_rasa/domain/repositories/layanan_pembayaran.dart';
import 'package:sisa_rasa/domain/repositories/layanan_pesanan.dart';
import 'package:sisa_rasa/domain/aturan/status_pesanan.dart';
import 'package:sisa_rasa/core/utils/format.dart';
import 'package:sisa_rasa/domain/aturan/pembayaran.dart';

class PesananBloc extends Bloc<PesananEvent, List<Map<String, dynamic>>> {
  // pembayaran dioper dari luar (injection.dart), tiruan selama backend belum ada.
  // tahanPorsi / lepasPorsi nyambung ke PaketCubit (lihat main.dart).
  // stok sengaja diurus di sini, bukan di tiap layar: kalau batas bayar abis di dua layar
  // barengan, event batal yg kedua ditolak, jadi porsi pasti balik cuma sekali
  //
  // kalau [server] diisi (aplikasi tersambung API), semua aksi dikirim ke server
  // dan isi pesanan diganti jawaban server. stok juga diurus server, jadi
  // tahanPorsi / lepasPorsi ga dipake, cukup [muatUlangPaket]
  PesananBloc({
    required this.pembayaran,
    this.tahanPorsi,
    this.lepasPorsi,
    this.server,
    this.muatUlangPaket,
  }) : super([]) {
    on<PesananDibuat>(buatPesanan);
    on<PembayaranDicek>(cekPembayaran);
    on<PesananDibatalkan>(batalkanPesanan);
    on<StatusPesananDiubah>(ubahStatus);
    on<MetodeDiganti>(gantiMetode);
    on<PesananDibatalkanMitra>(batalkanOlehMitra);
    on<PesananDimuat>(muat);
    on<PesananDikosongkan>((event, emit) => emit(const []));
  }

  final LayananPembayaran pembayaran;
  final void Function(Map<String, int> porsiPaket)? tahanPorsi;
  final void Function(Map<String, int> porsiPaket)? lepasPorsi;
  final LayananPesanan? server;
  final void Function()? muatUlangPaket;
  var _nomorUrut = 0;

  final _galat = StreamController<String>.broadcast();

  /// pesan galat dari server, ditampilin jadi snackbar (main.dart, checkout)
  Stream<String> get galat => _galat.stream;

  @override
  Future<void> close() {
    _galat.close();
    return super.close();
  }

  /// jalanin [aksi] ke server, pesanan hasilnya gantiin yg lama di daftar.
  /// galat dikirim ke [galat], daftarnya ga diubah
  Future<Map<String, dynamic>?> _keServer(
    Emitter<List<Map<String, dynamic>>> emit,
    Future<Map<String, dynamic>> Function(LayananPesanan server) aksi, {
    bool stokBerubah = false,
  }) async {
    try {
      final pesanan = await aksi(server!);
      emit(
        [
          pesanan,
          for (final lama in state)
            if (lama['id'] != pesanan['id']) lama,
        ]..sort(_terbaru),
      );
      if (stokBerubah) muatUlangPaket?.call();
      return pesanan;
    } on GagalLayanan catch (e) {
      if (!_galat.isClosed) _galat.add(e.pesan);
      return null;
    }
  }

  static int _terbaru(Map<String, dynamic> a, Map<String, dynamic> b) =>
      (b['dibuat'] as DateTime).compareTo(a['dibuat'] as DateTime);

  Future<void> muat(
    PesananDimuat event,
    Emitter<List<Map<String, dynamic>>> emit,
  ) async {
    if (server == null) return;
    try {
      final daftar = await server!.daftar();
      // yg lagi dicek pembayarannya jangan sampai tombolnya balik aktif
      final mengecek = {
        for (final p in state)
          if (p['mengecek'] == true) p['id'],
      };
      emit([
        for (final p in daftar)
          mengecek.contains(p['id']) ? {...p, 'mengecek': true} : p,
      ]);
    } on GagalLayanan {
      // dimuat berkala: kalau sinyal putus, coba lagi di putaran berikutnya
    }
  }

  /// diteruskan ke layar pembayaran buat nampilin keterangan "disimulasikan"
  bool get modeUji => pembayaran.modeUji;

  Map<String, dynamic>? cari(String id) {
    for (final pesanan in state) {
      if (pesanan['id'] == id) return pesanan;
    }
    return null;
  }

  /// pesanan punya satu akun aja, urutannya tetap yg terbaru di depan
  static List<Map<String, dynamic>> milik(
    List<Map<String, dynamic>> daftar,
    String idAkun,
  ) {
    return [
      for (final pesanan in daftar)
        if (pesanan['idAkun'] == idAkun) pesanan,
    ];
  }

  // ganti satu pesanan di list tanpa ngubah urutannya
  List<Map<String, dynamic>> _ubah(
    String id,
    Map<String, dynamic> Function(Map<String, dynamic> lama) ubah,
  ) {
    return [
      for (final pesanan in state)
        if (pesanan['id'] == id) ubah(pesanan) else pesanan,
    ];
  }

  // nomor pesanan SR-yymmddxxx, contoh SR-260914552
  String _buatNomor(DateTime waktu) {
    String dua(int angka) => angka.toString().padLeft(2, '0');
    final acak = Random().nextInt(1000).toString().padLeft(3, '0');
    return 'SR-${dua(waktu.year % 100)}${dua(waktu.month)}${dua(waktu.day)}$acak';
  }

  /// cadangan kalau event ga bawa kunci: tetap unik, cuma ga bisa dipake ngulang
  String _kunciAcak() {
    final acak = Random.secure();
    return List.generate(
      16,
      (_) => acak.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  // kode acak SR-xxxx, huruf O/I sama angka 0/1 dibuang biar ga ketuker pas dibaca
  String _buatKode() {
    const huruf = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final acak = Random();
    var kode = 'SR-';
    for (var i = 0; i < 4; i++) {
      kode += huruf[acak.nextInt(huruf.length)];
    }
    return kode;
  }

  Future<void> buatPesanan(
    PesananDibuat event,
    Emitter<List<Map<String, dynamic>>> emit,
  ) async {
    if (server != null) {
      await _keServer(
        emit,
        (server) => server.buat(
          isi: event.keranjang,
          metode: event.metode,
          kunci: event.kunci ?? _kunciAcak(),
        ),
        stokBerubah: true,
      );
      return;
    }
    Map<String, dynamic> cariPaket(String id) {
      return event.daftarPaket.firstWhere((paket) => paket['id'] == id);
    }

    final pertama = cariPaket(event.keranjang.keys.first);
    final isi = <Map<String, dynamic>>[];
    var subtotal = 0;
    var hargaNormal = 0;
    var porsi = 0;

    for (final id in event.keranjang.keys) {
      final paket = cariPaket(id);
      final jumlah = event.keranjang[id]!;
      isi.add({
        'nama': paket['nama'],
        'deskripsi': paket['deskripsi'],
        'foto': paket['foto'],
        'jumlah': jumlah,
        'harga': paket['hargaDiskon'],
      });
      subtotal += (paket['hargaDiskon'] as int) * jumlah;
      hargaNormal += (paket['hargaAsli'] as int) * jumlah;
      porsi += jumlah;
    }

    final biaya = biayaLayanan(subtotal);

    // F-40: porsi ditahan 15 menit, tapi ga boleh lewat jam tutup ambil
    final menit = min(
      menitBatasBayar,
      max(1, (pertama['tutup'] as int) - jamSekarang),
    );
    _nomorUrut++;
    final sekarang = DateTime.now();
    final id = 'ps-${sekarang.millisecondsSinceEpoch}-$_nomorUrut';

    final pesanan = {
      'id': id,
      // nomor yg ditampilin ke pembeli, beda sama kode ambil
      'nomor': _buatNomor(sekarang),
      'dibuat': sekarang,
      'idAkun': event.idAkun,
      'namaPembeli': namaSingkat(event.namaPembeli),
      'status': StatusPesanan.menungguBayar,
      // kode ambil baru dibikin setelah lunas (F-11)
      'kode': null,
      'metode': event.metode,
      'mitra': pertama['mitra'],
      'alamat': pertama['alamat'],
      'foto': pertama['foto'],
      'mulai': pertama['mulai'],
      'tutup': pertama['tutup'],
      'dipesan': jamSekarang,
      'isi': isi,
      // id paket -> jumlah, dipake buat balikin stok kalau batal
      'porsiPaket': {...event.keranjang},
      'porsi': porsi,
      'hargaNormal': hargaNormal,
      'subtotal': subtotal,
      'biayaLayanan': biaya,
      'total': subtotal + biaya,
      'hemat': hargaNormal - subtotal,
      // batasBayar buat hitung mundur, batasMenit buat ditulis "sampai 16.35"
      'batasBayar': DateTime.now().add(Duration(minutes: menit)),
      'batasMenit': jamSekarang + menit,
      'tagihan': <String, String>{},
      'mengecek': false,
    };

    // F-23: porsi langsung dikurangin pas pesanan dibuat, ditahan sampe dibayar
    tahanPorsi?.call({...event.keranjang});
    // list baru, pesanan terbaru ditaruh paling depan
    emit([pesanan, ...state]);

    // tagihan (QR / nomor VA) nyusul setelah penyedia pembayaran jawab
    final tagihan = await pembayaran.buatTagihan(
      idPesanan: id,
      metode: event.metode,
      total: subtotal + biaya,
    );
    emit(_ubah(id, (lama) => {...lama, 'tagihan': tagihan}));
  }

  Future<void> cekPembayaran(
    PembayaranDicek event,
    Emitter<List<Map<String, dynamic>>> emit,
  ) async {
    final pesanan = cari(event.id);
    if (pesanan == null || pesanan['status'] != StatusPesanan.menungguBayar) {
      return;
    }

    emit(_ubah(event.id, (lama) => {...lama, 'mengecek': true}));
    if (server != null) {
      // status lunas + kode ambil dari server (NF-10)
      final hasil = await _keServer(emit, (s) => s.cekBayar(event.id));
      if (hasil == null) {
        emit(_ubah(event.id, (lama) => {...lama, 'mengecek': false}));
      }
      return;
    }
    final lunas = await pembayaran.sudahLunas(event.id);

    // bisa aja keburu dibatalin pas lagi nunggu jawaban
    if (cari(event.id)?['status'] != StatusPesanan.menungguBayar) return;

    emit(
      _ubah(
        event.id,
        (lama) => {
          ...lama,
          'mengecek': false,
          if (lunas) ...{
            'status': StatusPesanan.disiapkan,
            'kode': _buatKode(),
            'dibayar': jamSekarang,
            'dibayarPada': DateTime.now(),
          },
        },
      ),
    );
  }

  Future<void> batalkanPesanan(
    PesananDibatalkan event,
    Emitter<List<Map<String, dynamic>>> emit,
  ) async {
    final pesanan = cari(event.id);
    // F-55: pembeli cuma bisa batalin yg belum dibayar
    if (pesanan == null || pesanan['status'] != StatusPesanan.menungguBayar) {
      return;
    }
    if (server != null) {
      await _keServer(
        emit,
        (s) =>
            s.batal(event.id, alasan: event.alasan, otomatis: event.otomatis),
        stokBerubah: true,
      );
      return;
    }
    emit(
      _ubah(
        event.id,
        (lama) => {
          ...lama,
          'status': StatusPesanan.dibatalkan,
          'alasan': event.alasan,
          'otomatis': event.otomatis,
          'dibatalkanPada': DateTime.now(),
          'mengecek': false,
        },
      ),
    );
    // F-40: porsi yg tadinya ditahan dibalikin ke stok
    lepasPorsi?.call(Map<String, int>.from(pesanan['porsiPaket']));
  }

  /// mitra batalin pesanan yg udah dibayar: status batal, dana dikembalikan penuh (F-42).
  /// porsinya ga dibalikin ke stok, soalnya biasanya batal karena makanannya ga ada
  Future<void> batalkanOlehMitra(
    PesananDibatalkanMitra event,
    Emitter<List<Map<String, dynamic>>> emit,
  ) async {
    final status = cari(event.id)?['status'];
    if (status != StatusPesanan.disiapkan &&
        status != StatusPesanan.siapDiambil) {
      return;
    }
    if (server != null) {
      await _keServer(emit, (s) => s.batalMitra(event.id, event.alasan));
      return;
    }
    emit(
      _ubah(
        event.id,
        (lama) => {
          ...lama,
          'status': StatusPesanan.dibatalkan,
          'alasan': event.alasan,
          'olehMitra': true,
          'dibatalkanPada': DateTime.now(),
        },
      ),
    );
  }

  /// ganti metode bayar selama belum lunas: tagihan lama dibuang, minta yg baru
  Future<void> gantiMetode(
    MetodeDiganti event,
    Emitter<List<Map<String, dynamic>>> emit,
  ) async {
    final pesanan = cari(event.id);
    if (pesanan == null ||
        pesanan['status'] != StatusPesanan.menungguBayar ||
        pesanan['metode'] == event.metode) {
      return;
    }
    if (server != null) {
      emit(
        _ubah(
          event.id,
          (lama) => {
            ...lama,
            'metode': event.metode,
            'tagihan': <String, String>{},
          },
        ),
      );
      await _keServer(emit, (s) => s.gantiMetode(event.id, event.metode));
      return;
    }
    emit(
      _ubah(
        event.id,
        (lama) => {
          ...lama,
          'metode': event.metode,
          'tagihan': <String, String>{},
        },
      ),
    );
    final tagihan = await pembayaran.buatTagihan(
      idPesanan: event.id,
      metode: event.metode,
      total: pesanan['total'],
    );
    // bisa aja keburu diganti lagi / dibatalin pas nunggu tagihan
    final sekarang = cari(event.id);
    if (sekarang?['metode'] != event.metode ||
        sekarang?['status'] != StatusPesanan.menungguBayar) {
      return;
    }
    emit(_ubah(event.id, (lama) => {...lama, 'tagihan': tagihan}));
  }

  /// tahapan yg diubah mitra: disiapkan -> siap diambil (F-43) -> selesai (F-20).
  /// selain urutan itu ditolak, misalnya pesanan yg belum dibayar
  Future<void> ubahStatus(
    StatusPesananDiubah event,
    Emitter<List<Map<String, dynamic>>> emit,
  ) async {
    final status = cari(event.id)?['status'];
    final boleh = switch (event.status) {
      StatusPesanan.siapDiambil => status == StatusPesanan.disiapkan,
      StatusPesanan.selesai =>
        status == StatusPesanan.disiapkan ||
            status == StatusPesanan.siapDiambil,
      _ => false,
    };
    if (!boleh) return;
    if (server != null) {
      await _keServer(emit, (s) => s.ubahStatus(event.id, event.status));
      return;
    }
    emit(
      _ubah(
        event.id,
        (lama) => {
          ...lama,
          'status': event.status,
          if (event.status == StatusPesanan.selesai)
            'diambilPada': DateTime.now(),
        },
      ),
    );
  }
}
