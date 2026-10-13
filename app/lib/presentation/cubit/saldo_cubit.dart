import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/domain/aturan/pembayaran.dart';
import 'package:sisa_rasa/domain/aturan/status_pesanan.dart';
import 'package:sisa_rasa/domain/repositories/layanan_saldo.dart';

/// rekening pencairan + riwayat saldo tiap mitra (F-48 s.d. F-50).
/// key-nya nama mitra, isinya {'rekening': {...} / null, 'riwayat': [...]}.
///
/// riwayat dari LayananSaldo cuma catatan yg udah ada di server,
/// dana masuk dari pesanan yg selesai hari ini dihitung langsung dari PesananBloc
class SaldoCubit extends Cubit<Map<String, Map<String, dynamic>>> {
  SaldoCubit({required this.layanan}) : super(const {});

  final LayananSaldo layanan;

  /// dipanggil pas masuk ke halaman mitra, cukup sekali per mitra
  Future<void> muat(String mitra) async {
    if (state.containsKey(mitra)) return;
    final rekening = await layanan.rekening(mitra);
    final riwayat = await layanan.riwayat(mitra);
    if (isClosed) return;
    emit({
      ...state,
      mitra: {'rekening': rekening, 'riwayat': riwayat},
    });
  }

  Map<String, dynamic>? rekening(String mitra) => state[mitra]?['rekening'];

  /// F-49: satu mitra satu rekening, rekening baru menggantikan yg lama
  Future<void> simpanRekening(
    String mitra, {
    required String bank,
    required String nomor,
    required String nama,
  }) async {
    final rekening = {'bank': bank, 'nomor': nomor, 'nama': nama};
    final lama = state[mitra] ?? {'riwayat': <Map<String, dynamic>>[]};
    emit({
      ...state,
      mitra: {...lama, 'rekening': rekening},
    });
    await layanan.simpanRekening(mitra, rekening);
  }

  /// riwayat lengkap satu mitra, terbaru di atas: catatan dari server + dana masuk
  /// dari pesanan yg selesai / tidak diambil (F-48, F-56)
  List<Map<String, dynamic>> riwayat(
    String mitra,
    List<Map<String, dynamic>> semuaPesanan,
  ) {
    final hasil = <Map<String, dynamic>>[
      for (final p in semuaPesanan)
        if (p['mitra'] == mitra &&
            (p['status'] == StatusPesanan.selesai ||
                p['status'] == StatusPesanan.tidakDiambil))
          {
            'jenis': 'masuk',
            'kode': p['kode'],
            'pembeli': p['namaPembeli'],
            'jual': p['subtotal'],
            'komisi': komisi(p['subtotal']),
            'jumlah': penerimaanBersih(p),
            'waktu': p['diambilPada'] ?? p['dibayarPada'] ?? p['dibuat'],
          },
      ...?(state[mitra]?['riwayat'] as List<Map<String, dynamic>>?),
    ];
    hasil.sort(
      (a, b) => (b['waktu'] as DateTime).compareTo(a['waktu'] as DateTime),
    );
    return hasil;
  }
}
