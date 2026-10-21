import 'package:sisa_rasa/domain/aturan/voucher.dart';
import 'package:sisa_rasa/domain/repositories/layanan_pesanan.dart';
import 'package:sisa_rasa/domain/repositories/layanan_voucher.dart';

/// voucher tanpa server: dua voucher contoh, perubahan cuma di memori.
/// syarat khusus pengguna baru ga dicek (ga ada riwayat pesanan di sini)
class VoucherTiruan implements LayananVoucher {
  VoucherTiruan() {
    final kini = DateTime.now();
    _voucher.addAll([
      {
        'id': 'v-hemat',
        'kode': 'SISAHEMAT',
        'judul': 'Hemat sore',
        'persen': 20,
        'maksPotongan': 10000,
        'minBelanja': 30000,
        'mulai': kini.subtract(const Duration(days: 1)),
        'berakhir': kini.add(const Duration(days: 30)),
        'kuota': null,
        'terpakai': 0,
        'khususBaru': false,
        'publik': true,
        'aktif': true,
      },
      {
        'id': 'v-pertama',
        'kode': 'PERTAMA',
        'judul': 'Pesanan pertama',
        'persen': 50,
        'maksPotongan': 15000,
        'minBelanja': 0,
        'mulai': kini.subtract(const Duration(days: 1)),
        'berakhir': kini.add(const Duration(days: 30)),
        'kuota': 100,
        'terpakai': 12,
        'khususBaru': true,
        'publik': true,
        'aktif': true,
      },
    ]);
  }

  final _voucher = <Map<String, dynamic>>[];
  var _urut = 0;

  bool _berlaku(Map<String, dynamic> v) {
    final kini = DateTime.now();
    final int? kuota = v['kuota'];
    return v['aktif'] == true &&
        !kini.isBefore(v['mulai']) &&
        kini.isBefore(v['berakhir']) &&
        (kuota == null || (v['terpakai'] as int) < kuota);
  }

  @override
  Future<List<Map<String, dynamic>>> tersedia() async => [
    for (final v in _voucher)
      if (v['publik'] == true && _berlaku(v)) {...v},
  ];

  @override
  Future<Map<String, dynamic>> cek(String kode, int subtotal) async {
    final dicari = kode.trim().toUpperCase().replaceAll(' ', '');
    final v = _voucher.where((v) => v['kode'] == dicari).firstOrNull;
    if (v == null || !_berlaku(v)) {
      throw const GagalLayanan('Kode voucher tidak ditemukan.');
    }
    if (subtotal < (v['minBelanja'] as int)) {
      throw const GagalLayanan('Belum memenuhi minimal belanja voucher ini.');
    }
    return {
      'voucher': {...v},
      'potongan': potonganVoucher(v, subtotal),
    };
  }

  @override
  Future<List<Map<String, dynamic>>> semua() async => [
    for (final v in _voucher.reversed) {...v},
  ];

  @override
  Future<Map<String, dynamic>> buat(Map<String, dynamic> isian) async {
    final kode = (isian['kode'] as String).trim().toUpperCase();
    if (_voucher.any((v) => v['kode'] == kode)) {
      throw GagalLayanan('Kode $kode sudah dipakai voucher lain.');
    }
    final v = {
      ...isian,
      'id': 'v-${++_urut}',
      'kode': kode,
      'terpakai': 0,
      'aktif': true,
    };
    _voucher.add(v);
    return {...v};
  }

  @override
  Future<Map<String, dynamic>> aturAktif(
    String id, {
    required bool aktif,
  }) async {
    final v = _voucher.firstWhere((v) => v['id'] == id);
    v['aktif'] = aktif;
    return {...v};
  }
}
