import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sisa_rasa/core/sesi_aktif.dart';
import 'package:sisa_rasa/data/repositories/saldo_api.dart';
import 'package:sisa_rasa/data/sumber/klien_api.dart';
import 'package:sisa_rasa/domain/aturan/saldo.dart';
import 'package:sisa_rasa/presentation/cubit/saldo_cubit.dart';

void main() {
  SaldoApi api(Future<http.Response> Function(http.Request) jawab) => SaldoApi(
    KlienApi(
      alamat: 'https://api.tes',
      sesi: SesiAktif()..token = 'tok-1',
      klien: MockClient(jawab),
    ),
  );

  test('riwayat pencairan dari server jadi entri cair, Diproses ikut ngurangin saldo', () async {
    final cubit = SaldoCubit(
      layanan: api(
        (_) async => http.Response(
          jsonEncode({
            'rekening': {
              'bank': 'BCA',
              'nomor': '1234567890',
              'nama': 'IBIS HOTEL',
            },
            'tersedia': 0,
            'riwayat': [
              {
                'id': 'c1',
                'jumlah': 34200,
                'bank': 'BCA',
                'nomor': '1234567890',
                'nama': 'IBIS HOTEL',
                'status': 'Diproses',
                'waktu': '2026-10-21T01:00:00Z',
              },
            ],
          }),
          200,
        ),
      ),
    );
    await cubit.muat('Ibis Hotel');
    expect(cubit.rekening('Ibis Hotel')!['bank'], 'BCA');

    // satu pesanan selesai 38rb -> masuk 34.200, pencairan Diproses 34.200
    final riwayat = cubit.riwayat('Ibis Hotel', [
      {
        'mitra': 'Ibis Hotel',
        'status': 'selesai',
        'kode': 'SR-AB12',
        'namaPembeli': 'Rani A.',
        'subtotal': 38000,
        'diambilPada': DateTime(2026, 10, 20, 16),
      },
    ]);
    expect(riwayat.first['jenis'], 'cair');
    expect(riwayat.first['waktu'], isA<DateTime>());
    expect(saldoTersedia(riwayat), 0);
    await cubit.close();
  });

  test(
    'server nolak rekening: balik ke rekening lama, pesannya keluar',
    () async {
      final cubit = SaldoCubit(
        layanan: api((req) async {
          if (req.method == 'PUT') {
            return http.Response(
              jsonEncode({'pesan': 'Nama tidak cocok.'}),
              422,
            );
          }
          return http.Response(
            jsonEncode({
              'rekening': {
                'bank': 'BCA',
                'nomor': '1234567890',
                'nama': 'IBIS HOTEL',
              },
              'tersedia': 0,
              'riwayat': <Object>[],
            }),
            200,
          );
        }),
      );
      await cubit.muat('Ibis Hotel');
      final galat = cubit.galat.first;
      await cubit.simpanRekening(
        'Ibis Hotel',
        bank: 'BRI',
        nomor: '9876543210',
        nama: 'X',
      );
      expect(await galat, 'Nama tidak cocok.');
      expect(cubit.rekening('Ibis Hotel')!['bank'], 'BCA');
      await cubit.close();
    },
  );
}
