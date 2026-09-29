import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/bloc/pesanan_event.dart';
import 'package:sisa_rasa/utils/format.dart';

/// daftar pesanan, yg terbaru paling atas
/// pake bloc (bukan cubit) biar keliatan bedanya: di sini ubahnya lewat event
class PesananBloc extends Bloc<PesananEvent, List<Map<String, dynamic>>> {
  PesananBloc() : super([]) {
    on<PesananDibuat>(buatPesanan);
  }

  void buatPesanan(
    PesananDibuat event,
    Emitter<List<Map<String, dynamic>>> emit,
  ) {
    // kode acak SR-xxxx, huruf O/I sama angka 0/1 dibuang biar ga ketuker pas dibaca
    const huruf = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // pake regex nanti
    final acak = Random();
    var kode = 'SR-';
    for (var i = 0; i < 4; i++) {
      kode += huruf[acak.nextInt(huruf.length)];
    }

    Map<String, dynamic> cari(String id) {
      return event.daftarPaket.firstWhere((paket) => paket['id'] == id);
    }

    final pertama = cari(event.keranjang.keys.first);
    final isi = <Map<String, dynamic>>[];
    var total = 0;
    var hargaNormal = 0;
    var porsi = 0;

    for (final id in event.keranjang.keys) {
      final paket = cari(id);
      final jumlah = event.keranjang[id]!;
      isi.add({'nama': paket['nama'], 'jumlah': jumlah});
      total += (paket['hargaDiskon'] as int) * jumlah;
      hargaNormal += (paket['hargaAsli'] as int) * jumlah;
      porsi += jumlah;
    }

    final pesanan = {
      'kode': kode,
      'mitra': pertama['mitra'],
      'alamat': pertama['alamat'],
      'foto': pertama['foto'],
      'mulai': pertama['mulai'],
      'tutup': pertama['tutup'],
      'dipesan': jamSekarang,
      'isi': isi,
      'porsi': porsi,
      'total': total,
      'hemat': hargaNormal - total,
    };

    // list baru, pesanan terbaru ditaruh paling depan
    emit([pesanan, ...state]);
  }
}
