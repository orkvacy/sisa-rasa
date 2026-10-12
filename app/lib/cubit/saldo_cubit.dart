import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sisa_rasa/data/dummy_akun.dart';
import 'package:sisa_rasa/data/pembayaran.dart';
import 'package:sisa_rasa/data/status_pesanan.dart';

/// bank yg bisa dipilih buat rekening pencairan (F-49)
const bankPencairan = ['BCA', 'Mandiri', 'BRI', 'BNI', 'BSI', 'CIMB Niaga'];

/// rekening pencairan + riwayat saldo lama tiap mitra (F-48 s.d. F-50).
/// key-nya nama mitra, isinya {'rekening': {...} / null, 'riwayat': [...]}.
///
/// riwayat di sini cuma catatan sebelum aplikasi dibuka (pura-puranya dari server),
/// dana masuk dari pesanan yg selesai hari ini dihitung langsung dari PesananBloc.
/// pencairan beneran jalan di server tiap 09.00 (NF-11), aplikasi cuma nampilin hasilnya
class SaldoCubit extends Cubit<Map<String, Map<String, dynamic>>> {
  SaldoCubit({DateTime? sekarang}) : super(_awal(sekarang ?? DateTime.now()));

  static Map<String, Map<String, dynamic>> _awal(DateTime sekarang) {
    final hariIni = DateTime(sekarang.year, sekarang.month, sekarang.day);
    final kemarin = hariIni.subtract(const Duration(days: 1));
    DateTime pada(DateTime hari, int jam, int menit) =>
        hari.add(Duration(hours: jam, minutes: menit));

    final lama = [
      _masuk('SR-8XQ1', 'Nur H.', 18000, pada(kemarin, 17, 40)),
      _masuk('SR-3MD2', 'Yoga', 24000, pada(kemarin, 17, 5)),
      _masuk('SR-6PL9', 'Sari W.', 30000, pada(kemarin, 16, 50)),
    ];
    return {
      'Ibis Hotel': {
        'rekening': {
          'bank': 'BCA',
          'nomor': '1234567890',
          'nama': 'IBIS HOTEL',
        },
        'riwayat': [
          _masuk('SR-4HB2', 'Yoga', 14000, pada(hariIni, 12, 10)),
          // saldo kemarin dicairin semua pagi ini
          {
            'jenis': 'cair',
            'jumlah': lama.fold<int>(0, (n, e) => n + (e['jumlah'] as int)),
            'bank': 'BCA',
            'nomor': '1234567890',
            'status': 'Berhasil',
            'waktu': pada(hariIni, 9, 2),
          },
          ...lama,
        ],
      },
    };
  }

  static Map<String, dynamic> _masuk(
    String kode,
    String pembeli,
    int jual,
    DateTime waktu,
  ) => {
    'jenis': 'masuk',
    'kode': kode,
    'pembeli': pembeli,
    'jual': jual,
    'komisi': komisi(jual),
    'jumlah': jual - komisi(jual),
    'waktu': waktu,
  };

  Map<String, dynamic>? rekening(String mitra) => state[mitra]?['rekening'];

  /// F-49: satu mitra satu rekening, rekening baru menggantikan yg lama
  void simpanRekening(
    String mitra, {
    required String bank,
    required String nomor,
    required String nama,
  }) {
    final lama = state[mitra] ?? {'riwayat': <Map<String, dynamic>>[]};
    emit({
      ...state,
      mitra: {
        ...lama,
        'rekening': {'bank': bank, 'nomor': nomor, 'nama': nama},
      },
    });
  }

  /// riwayat lengkap satu mitra, terbaru di atas: catatan lama + dana masuk
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
            'pembeli': namaPembeli(p['idAkun']),
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

/// saldo yg belum dicairkan: semua dana masuk dikurangi pencairan yg berhasil
int saldoTersedia(List<Map<String, dynamic>> riwayat) {
  var saldo = 0;
  for (final e in riwayat) {
    if (e['jenis'] == 'masuk') saldo += e['jumlah'] as int;
    if (e['jenis'] == 'cair' && e['status'] == 'Berhasil') {
      saldo -= e['jumlah'] as int;
    }
  }
  return saldo;
}

/// total satu jenis ('masuk' / 'cair') sejak senin minggu ini
int totalMingguIni(
  List<Map<String, dynamic>> riwayat,
  String jenis, {
  DateTime? sekarang,
}) {
  final kini = sekarang ?? DateTime.now();
  final senin = DateTime(
    kini.year,
    kini.month,
    kini.day,
  ).subtract(Duration(days: kini.weekday - 1));
  return riwayat
      .where(
        (e) => e['jenis'] == jenis && !(e['waktu'] as DateTime).isBefore(senin),
      )
      .fold(0, (n, e) => n + (e['jumlah'] as int));
}

/// "BCA · 1234", nomor rekening cuma 4 angka terakhir yg ditampilin
String rekeningSingkat(String bank, String nomor) {
  final akhir = nomor.length > 4 ? nomor.substring(nomor.length - 4) : nomor;
  return '$bank · $akhir';
}

/// F-49: nama pemilik rekening harus sama dengan nama usaha.
/// sementara dibandingin sama nama akun, nanti server nanya ke bank (cek rekening)
bool namaRekeningCocok(String namaRekening, String namaUsaha) {
  String rapi(String s) =>
      s.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
  return rapi(namaRekening).isNotEmpty && rapi(namaRekening) == rapi(namaUsaha);
}
