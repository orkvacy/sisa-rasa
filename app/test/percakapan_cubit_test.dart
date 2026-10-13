import 'package:flutter_test/flutter_test.dart';
import 'package:sisa_rasa/data/repositories/percakapan_tiruan.dart';
import 'package:sisa_rasa/presentation/cubit/percakapan_cubit.dart';
import 'package:sisa_rasa/domain/aturan/status_pesanan.dart';
import 'package:sisa_rasa/domain/aturan/percakapan.dart';

/// server tiruan yg bisa disuruh gagal, buat nguji kirim ulang (NF-18)
class _ServerRewel extends PercakapanTiruan {
  _ServerRewel() : super(jeda: Duration.zero);

  bool gagal = false;
  int diterima = 0;

  @override
  Future<void> kirim(Map<String, dynamic> pesan) async {
    diterima++;
    if (gagal) throw Exception('koneksi putus');
    await super.kirim(pesan);
  }
}

void main() {
  late _ServerRewel server;
  late PercakapanCubit cubit;

  setUp(() {
    server = _ServerRewel();
    cubit = PercakapanCubit(layanan: server);
  });
  tearDown(() async {
    await cubit.close();
    server.tutup();
  });

  Future<void> tunggu() => Future<void>.delayed(Duration.zero);

  test(
    'pesan terkirim, lawan bicara liat belum dibaca, lalu dibaca (F-70)',
    () async {
      await cubit.kirim(idPesanan: 'x1', peran: 'pembeli', teks: ' Halo ');
      await tunggu();
      expect(cubit.pesan('x1').single['teks'], 'Halo');
      expect(cubit.pesan('x1').single['status'], 'terkirim');
      expect(cubit.belumDibaca('x1', 'mitra'), 1);
      // pengirim sendiri ga ngitung pesannya sebagai belum dibaca
      expect(cubit.belumDibaca('x1', 'pembeli'), 0);

      cubit.tandaiDibaca('x1', 'mitra');
      await tunggu();
      expect(cubit.belumDibaca('x1', 'mitra'), 0);
      expect(cubit.pesan('x1').single['status'], 'dibaca');
    },
  );

  test('gagal kirim, kirim ulang pake id yg sama, ga dobel (NF-18)', () async {
    server.gagal = true;
    await cubit.kirim(idPesanan: 'x1', peran: 'mitra', teks: 'Sudah siap');
    final pesan = cubit.pesan('x1').single;
    expect(pesan['status'], 'gagal');

    server.gagal = false;
    await cubit.kirimUlang('x1', pesan['id']);
    // dikirim dua kali lagi, misal tombol kepencet dobel
    await cubit.kirimUlang('x1', pesan['id']);
    await tunggu();
    expect(server.diterima, 3);
    expect(cubit.pesan('x1'), hasLength(1));
    expect(cubit.pesan('x1').single['status'], 'terkirim');
    expect(await server.riwayat('x1'), hasLength(1));
  });

  test('pesan kosong ga dikirim', () async {
    await cubit.kirim(idPesanan: 'x1', peran: 'pembeli', teks: '   ');
    expect(cubit.pesan('x1'), isEmpty);
  });

  test('percakapan kebuka sejak dibayar sampe 2 jam abis selesai (F-67)', () {
    final sekarang = DateTime(2026, 10, 14, 18);
    Map<String, dynamic> pesanan(String status, {DateTime? diambil}) => {
      'status': status,
      'dibayarPada': status == StatusPesanan.menungguBayar
          ? null
          : DateTime(2026, 10, 14, 16),
      'diambilPada': diambil,
    };

    expect(keadaanPercakapan(pesanan(StatusPesanan.menungguBayar)), 'tidakAda');
    expect(keadaanPercakapan(pesanan(StatusPesanan.disiapkan)), 'terbuka');
    expect(
      keadaanPercakapan(
        pesanan(StatusPesanan.selesai, diambil: DateTime(2026, 10, 14, 17)),
        sekarang: sekarang,
      ),
      'terbuka',
    );
    expect(
      keadaanPercakapan(
        pesanan(StatusPesanan.selesai, diambil: DateTime(2026, 10, 14, 15)),
        sekarang: sekarang,
      ),
      'bacaSaja',
    );
  });
}
