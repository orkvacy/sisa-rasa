import 'dart:async';

import 'package:sisa_rasa/data/sumber/klien_api.dart';
import 'package:sisa_rasa/domain/repositories/layanan_pesanan.dart';
import 'package:sisa_rasa/domain/repositories/layanan_percakapan.dart';

/// percakapan lewat server Go. pesan baru (dan tanda dibaca) ditarik berkala dari
/// GET /v1/pesan/baru buat semua pesanan sekaligus, jadi angka belum dibaca di
/// daftar pesanan ikut jalan walau layar percakapannya belum dibuka.
/// nanti bisa diganti WebSocket (NF-17) tanpa ngubah cubit / layar
class PercakapanApi implements LayananPercakapan {
  PercakapanApi(this.klien, {Duration jeda = const Duration(seconds: 4)}) {
    _detak = Timer.periodic(jeda, (_) => tarik());
  }

  final KlienApi klien;
  final _kejadian = StreamController<KejadianPercakapan>.broadcast();
  Timer? _detak;

  /// waktu server dari tarikan terakhir, null = tarik semua
  DateTime? _setelah;
  String? _token;
  var _menarik = false;

  @override
  Stream<KejadianPercakapan> get kejadian => _kejadian.stream;

  /// ambil pesan yang berubah sejak tarikan terakhir
  Future<void> tarik() async {
    final token = klien.sesi.token;
    if (token != _token) {
      // ganti akun / keluar: mulai dari awal
      _token = token;
      _setelah = null;
    }
    if (token == null || _menarik) return;
    _menarik = true;
    try {
      // mundur 10 detik biar pesan yang disimpan pas tarikan sebelumnya
      // lagi jalan ga kelewat. yang dobel disaring cubit lewat id
      final setelah = _setelah?.subtract(const Duration(seconds: 10));
      final jalur = setelah == null
          ? '/v1/pesan/baru'
          : '/v1/pesan/baru?setelah='
                '${Uri.encodeQueryComponent(setelah.toUtc().toIso8601String())}';
      final hasil = await klien.get(jalur);
      if (klien.sesi.token != token) return;
      for (final p in hasil['pesan'] as List) {
        _kejadian.add({'jenis': 'pesan', 'pesan': dariServer(p as Map)});
      }
      _setelah = DateTime.parse(hasil['sekarang'] as String);
    } on GagalLayanan {
      // sinyal putus: dicoba lagi di putaran berikutnya
    } finally {
      _menarik = false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> riwayat(String idPesanan) async {
    final hasil = await klien.get('/v1/pesanan/$idPesanan/pesan');
    return [for (final p in hasil['pesan'] as List) dariServer(p as Map)];
  }

  @override
  Future<void> kirim(Map<String, dynamic> pesan) async {
    final hasil = await klien.post('/v1/pesanan/${pesan['idPesanan']}/pesan', {
      'id': pesan['id'],
      'teks': pesan['teks'],
    });
    _kejadian.add({
      'jenis': 'pesan',
      'pesan': dariServer(hasil['pesan'] as Map),
    });
  }

  @override
  Future<void> tandaiDibaca(String idPesanan, String oleh) async {
    try {
      await klien.post('/v1/pesanan/$idPesanan/pesan/dibaca');
    } on GagalLayanan {
      // ga penting banget: tanda dibaca dikirim lagi pas layar dibuka lagi
    }
  }

  /// JSON server -> map pesan yang dipakai cubit
  static Map<String, dynamic> dariServer(Map json) => {
    ...Map<String, dynamic>.from(json),
    'waktu': DateTime.parse(json['waktu'] as String).toLocal(),
  };

  void tutup() {
    _detak?.cancel();
    _kejadian.close();
  }
}
