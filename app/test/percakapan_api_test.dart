import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sisa_rasa/core/sesi_aktif.dart';
import 'package:sisa_rasa/data/repositories/percakapan_api.dart';
import 'package:sisa_rasa/data/sumber/klien_api.dart';
import 'package:sisa_rasa/presentation/cubit/percakapan_cubit.dart';

Map<String, dynamic> pesanJson(String id, String peran, String status) => {
  'id': id,
  'idPesanan': 'ps-1',
  'peran': peran,
  'teks': 'Halo $id',
  'waktu': '2026-10-20T08:20:00Z',
  'status': status,
};

void main() {
  late List<http.Request> terkirim;
  late SesiAktif sesi;

  PercakapanApi api(Future<http.Response> Function(http.Request) jawab) {
    terkirim = [];
    sesi = SesiAktif()..token = 'tok-1';
    return PercakapanApi(
      KlienApi(
        alamat: 'https://api.tes',
        sesi: sesi,
        klien: MockClient((req) {
          terkirim.add(req);
          return jawab(req);
        }),
      ),
      // tes manggil tarik() sendiri, detaknya dibikin jarang
      jeda: const Duration(hours: 1),
    );
  }

  test('tarik: pesan baru masuk ke cubit, tarikan berikutnya pakai waktu server', () async {
    var putaran = 0;
    final layanan = api((req) async {
      putaran++;
      return http.Response(
        jsonEncode({
          'pesan': putaran == 1
              ? [pesanJson('a1', 'mitra', 'terkirim')]
              : [pesanJson('a1', 'mitra', 'dibaca')],
          'sekarang': '2026-10-20T08:21:00Z',
        }),
        200,
      );
    });
    final cubit = PercakapanCubit(layanan: layanan);

    await layanan.tarik();
    await Future<void>.delayed(Duration.zero);
    expect(terkirim.single.url.path, '/v1/pesan/baru');
    expect(terkirim.single.url.query, isEmpty);
    expect(cubit.belumDibaca('ps-1', 'pembeli'), 1);

    // putaran kedua: mundur 10 detik dari waktu server, status naik jadi dibaca
    await layanan.tarik();
    await Future<void>.delayed(Duration.zero);
    expect(
      terkirim.last.url.queryParameters['setelah'],
      '2026-10-20T08:20:50.000Z',
    );
    expect(cubit.belumDibaca('ps-1', 'pembeli'), 0);

    // keluar: ga narik apa-apa
    sesi.token = null;
    await layanan.tarik();
    expect(terkirim, hasLength(2));
    await cubit.close();
    layanan.tutup();
  });

  test(
    'kirim: id dari aplikasi ikut dikirim, gagal jadi status gagal',
    () async {
      var gagal = false;
      final layanan = api((req) async {
        if (gagal) throw http.ClientException('putus');
        final isi = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'pesan': pesanJson(isi['id'] as String, 'pembeli', 'terkirim'),
          }),
          200,
        );
      });
      final cubit = PercakapanCubit(layanan: layanan);

      await cubit.kirim(
        idPesanan: 'ps-1',
        peran: 'pembeli',
        teks: 'Saya sudah sampai',
      );
      final isi = jsonDecode(terkirim.single.body) as Map<String, dynamic>;
      expect(terkirim.single.url.path, '/v1/pesanan/ps-1/pesan');
      expect(isi['teks'], 'Saya sudah sampai');
      expect(isi['id'], hasLength(32));
      // kejadian dari stream nyampe di putaran event berikutnya
      await Future<void>.delayed(Duration.zero);
      expect(cubit.pesan('ps-1').single['status'], 'terkirim');

      gagal = true;
      await cubit.kirim(idPesanan: 'ps-1', peran: 'pembeli', teks: 'Lagi');
      expect(cubit.pesan('ps-1').last['status'], 'gagal');
      await cubit.close();
      layanan.tutup();
    },
  );
}
