import 'dart:async';

import 'package:sisa_rasa/domain/repositories/layanan_percakapan.dart';

/// pengganti server selama backend belum ada. pembeli sama mitra ada di satu HP
/// (pindah lewat Ganti akun), jadi "real time"-nya cukup lewat stream di memori
class PercakapanTiruan implements LayananPercakapan {
  PercakapanTiruan({this.jeda = const Duration(milliseconds: 300)});

  /// pura-puranya waktu bolak-balik ke server
  final Duration jeda;

  final _kejadian = StreamController<KejadianPercakapan>.broadcast();
  final _tersimpan = <String, Map<String, Map<String, dynamic>>>{};

  @override
  Stream<KejadianPercakapan> get kejadian => _kejadian.stream;

  @override
  Future<List<Map<String, dynamic>>> riwayat(String idPesanan) async =>
      _tersimpan[idPesanan]?.values.toList() ?? [];

  @override
  Future<void> kirim(Map<String, dynamic> pesan) async {
    await Future<void>.delayed(jeda);
    final percakapan = _tersimpan.putIfAbsent(pesan['idPesanan'], () => {});
    // id yg sama ga dicatet ulang
    final tercatat = percakapan.putIfAbsent(
      pesan['id'],
      () => {...pesan, 'status': 'terkirim'},
    );
    _kejadian.add({'jenis': 'pesan', 'pesan': tercatat});
  }

  @override
  Future<void> tandaiDibaca(String idPesanan, String oleh) async {
    final percakapan = _tersimpan[idPesanan];
    if (percakapan == null) return;
    for (final p in percakapan.values) {
      if (p['peran'] != oleh) p['status'] = 'dibaca';
    }
    _kejadian.add({'jenis': 'dibaca', 'idPesanan': idPesanan, 'oleh': oleh});
  }

  void tutup() => _kejadian.close();
}
