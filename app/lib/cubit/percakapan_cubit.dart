import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/data/layanan_percakapan.dart';
import 'package:sisa_rasa/data/status_pesanan.dart';

/// percakapan pembeli - mitra per pesanan (F-67 s.d. F-70).
/// state: id pesanan -> daftar pesan, urut dari yg paling lama.
/// satu pesan: id, idPesanan, peran pengirim ('pembeli' / 'mitra'), teks, waktu,
/// status: 'mengirim' -> 'terkirim' -> 'dibaca', atau 'gagal' kalau ga nyampe server
class PercakapanCubit extends Cubit<Map<String, List<Map<String, dynamic>>>> {
  PercakapanCubit({required this.layanan}) : super(const {}) {
    _langganan = layanan.kejadian.listen(_terima);
  }

  final LayananPercakapan layanan;
  late final StreamSubscription<KejadianPercakapan> _langganan;
  final _acak = Random.secure();

  List<Map<String, dynamic>> pesan(String idPesanan) =>
      state[idPesanan] ?? const [];

  /// F-70: pesan dari lawan bicara yg belum dibaca [peran]
  int belumDibaca(String idPesanan, String peran) =>
      pesan(idPesanan)
          .where((p) => p['peran'] != peran && p['status'] != 'dibaca')
          .length;

  /// layar percakapan dibuka: ambil riwayat dari server (F-68)
  Future<void> muat(String idPesanan) async {
    final dariServer = await layanan.riwayat(idPesanan);
    if (isClosed) return;
    for (final p in dariServer) {
      _simpan(p);
    }
  }

  /// id unik dibikin di aplikasi, jadi kirim ulang ga bikin pesan dobel (NF-18)
  Future<void> kirim({
    required String idPesanan,
    required String peran,
    required String teks,
  }) async {
    final rapi = teks.trim();
    if (rapi.isEmpty) return;
    final id = List.generate(
      16,
      (_) => _acak.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final baru = {
      'id': id,
      'idPesanan': idPesanan,
      'peran': peran,
      'teks': rapi,
      'waktu': DateTime.now(),
      'status': 'mengirim',
    };
    _simpan(baru);
    await _kirimKeServer(baru);
  }

  /// pesan yg gagal dikirim, dicoba lagi pake id yg sama
  Future<void> kirimUlang(String idPesanan, String id) async {
    final lama = pesan(idPesanan).where((p) => p['id'] == id).firstOrNull;
    if (lama == null) return;
    _simpan({...lama, 'status': 'mengirim'});
    await _kirimKeServer(lama);
  }

  Future<void> _kirimKeServer(Map<String, dynamic> p) async {
    try {
      await layanan.kirim(p);
    } catch (_) {
      if (!isClosed) _simpan({...p, 'status': 'gagal'});
    }
  }

  /// pesan dari lawan bicara di percakapan ini ditandai udah dibaca [oleh]
  void tandaiDibaca(String idPesanan, String oleh) {
    if (belumDibaca(idPesanan, oleh) == 0) return;
    _tandai(idPesanan, oleh);
    layanan.tandaiDibaca(idPesanan, oleh);
  }

  void _terima(KejadianPercakapan k) {
    if (k['jenis'] == 'pesan') {
      _simpan(k['pesan']);
    } else if (k['jenis'] == 'dibaca') {
      _tandai(k['idPesanan'], k['oleh']);
    }
  }

  void _tandai(String idPesanan, String oleh) {
    emit({
      ...state,
      idPesanan: [
        for (final p in pesan(idPesanan))
          if (p['peran'] != oleh) {...p, 'status': 'dibaca'} else p,
      ],
    });
  }

  /// tambah atau timpa pesan berdasarkan id, status ga boleh mundur
  /// (misal 'dibaca' ketimpa 'terkirim' yg datengnya telat)
  void _simpan(Map<String, dynamic> p) {
    final daftar = [...pesan(p['idPesanan'])];
    final i = daftar.indexWhere((x) => x['id'] == p['id']);
    if (i == -1) {
      daftar.add(p);
      daftar.sort(
        (a, b) => (a['waktu'] as DateTime).compareTo(b['waktu'] as DateTime),
      );
    } else {
      final lama = daftar[i]['status'];
      final status = lama == 'dibaca' ? 'dibaca' : p['status'];
      daftar[i] = {...daftar[i], ...p, 'status': status};
    }
    emit({...state, p['idPesanan']: daftar});
  }

  @override
  Future<void> close() {
    _langganan.cancel();
    return super.close();
  }
}

/// percakapan tetap bisa dibuka sampai 2 jam setelah pesanan berakhir (F-67)
const jamPercakapanSetelahSelesai = 2;

/// 'tidakAda' (belum dibayar), 'terbuka', atau 'bacaSaja' (udah lewat batas)
String keadaanPercakapan(Map<String, dynamic> pesanan, {DateTime? sekarang}) {
  if (pesanan['dibayarPada'] == null) return 'tidakAda';
  final status = pesanan['status'];
  if (status == StatusPesanan.disiapkan ||
      status == StatusPesanan.siapDiambil) {
    return 'terbuka';
  }
  final DateTime? akhir = pesanan['diambilPada'] ?? pesanan['dibatalkanPada'];
  // pesanan berakhir tapi waktunya ga kecatet (misal tidak diambil): baca aja
  if (akhir == null) return 'bacaSaja';
  final batas = akhir.add(const Duration(hours: jamPercakapanSetelahSelesai));
  return (sekarang ?? DateTime.now()).isBefore(batas) ? 'terbuka' : 'bacaSaja';
}

/// pesan cepat bertemplat (F-69)
const pesanCepat = {
  'pembeli': [
    'Saya sudah sampai',
    'Saya dalam perjalanan',
    'Saya terlambat sekitar 10 menit',
  ],
  'mitra': [
    'Pesanan sudah siap',
    'Pesanan sedang disiapkan',
    'Silakan ambil di kasir depan',
  ],
};
