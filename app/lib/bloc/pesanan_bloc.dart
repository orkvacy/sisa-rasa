import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/bloc/pesanan_event.dart';
import 'package:sisa_rasa/data/pembayaran.dart';
import 'package:sisa_rasa/data/status_pesanan.dart';
import 'package:sisa_rasa/utils/format.dart';

class PesananBloc extends Bloc<PesananEvent, List<Map<String, dynamic>>> {
  // pembayaran dioper dari luar, defaultnya tiruan selama backend belum ada.
  // tahanPorsi / lepasPorsi nyambung ke PaketCubit (lihat main.dart).
  // stok sengaja diurus di sini, bukan di tiap layar: kalau batas bayar abis di dua layar
  // barengan, event batal yg kedua ditolak, jadi porsi pasti balik cuma sekali
  PesananBloc({
    this.pembayaran = const PembayaranTiruan(),
    this.tahanPorsi,
    this.lepasPorsi,
  }) : super([]) {
    on<PesananDibuat>(buatPesanan);
    on<PembayaranDicek>(cekPembayaran);
    on<PesananDibatalkan>(batalkanPesanan);
    on<StatusPesananDiubah>(ubahStatus);
    on<MetodeDiganti>(gantiMetode);
  }

  final LayananPembayaran pembayaran;
  final void Function(Map<String, int> porsiPaket)? tahanPorsi;
  final void Function(Map<String, int> porsiPaket)? lepasPorsi;
  var _nomorUrut = 0;

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

  void batalkanPesanan(
    PesananDibatalkan event,
    Emitter<List<Map<String, dynamic>>> emit,
  ) {
    final pesanan = cari(event.id);
    // F-55: pembeli cuma bisa batalin yg belum dibayar
    if (pesanan == null || pesanan['status'] != StatusPesanan.menungguBayar) {
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
  void ubahStatus(
    StatusPesananDiubah event,
    Emitter<List<Map<String, dynamic>>> emit,
  ) {
    final status = cari(event.id)?['status'];
    final boleh = switch (event.status) {
      StatusPesanan.siapDiambil => status == StatusPesanan.disiapkan,
      StatusPesanan.selesai =>
        status == StatusPesanan.disiapkan ||
            status == StatusPesanan.siapDiambil,
      _ => false,
    };
    if (!boleh) return;
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
