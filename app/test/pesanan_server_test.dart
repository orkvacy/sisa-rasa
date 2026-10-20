import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sisa_rasa/core/sesi_aktif.dart';
import 'package:sisa_rasa/data/repositories/paket_api.dart';
import 'package:sisa_rasa/data/repositories/pembayaran_tiruan.dart';
import 'package:sisa_rasa/data/repositories/pesanan_api.dart';
import 'package:sisa_rasa/data/sumber/klien_api.dart';
import 'package:sisa_rasa/domain/aturan/status_pesanan.dart';
import 'package:sisa_rasa/domain/repositories/layanan_pesanan.dart';
import 'package:sisa_rasa/presentation/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/presentation/bloc/pesanan_event.dart';

/// satu pesanan dalam bentuk JSON backend/internal/toko
Map<String, dynamic> pesananJson({
  String id = 'ps-1',
  String status = StatusPesanan.menungguBayar,
  String? kode,
}) => {
  'id': id,
  'nomor': 'SR-2610201234',
  'idAkun': 'pembeli-1',
  'idMitra': 'mitra-1',
  'namaPembeli': 'Rani A.',
  'mitra': 'Ibis Hotel',
  'alamat': 'Jl. Mulawarman 2',
  'foto': 'assets/images/paket/american_breakfast.jpg',
  'mulai': 900,
  'tutup': 1020,
  'status': status,
  'metode': 'qris',
  'kode': kode,
  'isi': [
    {
      'idPaket': 'pk-1',
      'nama': 'American Breakfast Set',
      'deskripsi': '',
      'foto': '',
      'harga': 34000,
      'hargaAsli': 85000,
      'jumlah': 2,
    },
  ],
  'porsiPaket': {'pk-1': 2},
  'porsi': 2,
  'subtotal': 68000,
  'hargaNormal': 170000,
  'biayaLayanan': 6800,
  'total': 74800,
  'hemat': 102000,
  'dipesan': 980,
  'dibuat': '2026-10-20T08:20:00Z',
  'batasBayar': '2026-10-20T08:35:00Z',
  'batasMenit': 995,
  'dibayarPada': kode == null ? null : '2026-10-20T08:21:00Z',
  'dibayar': kode == null ? null : 981,
  'diambilPada': null,
  'dibatalkanPada': null,
  'alasan': null,
  'otomatis': false,
  'olehMitra': false,
  'tagihan': {
    'isiQr': 'SISARASA-UJI|ps-1|74800',
    'nomorVa': '8077 0812 0000 0001',
  },
};

void main() {
  group('PesananApi', () {
    late List<http.Request> terkirim;

    KlienApi klien(Future<http.Response> Function(http.Request) jawab) {
      terkirim = [];
      final sesi = SesiAktif()..token = 'tok-1';
      return KlienApi(
        alamat: 'https://api.tes',
        sesi: sesi,
        klien: MockClient((req) {
          terkirim.add(req);
          return jawab(req);
        }),
      );
    }

    test(
      'buat pesanan ngirim Idempotency-Key + token, JSON jadi map layar',
      () async {
        final api = PesananApi(
          klien(
            (_) async =>
                http.Response(jsonEncode({'pesanan': pesananJson()}), 201),
          ),
        );
        final p = await api.buat(
          isi: {'pk-1': 2},
          metode: 'qris',
          kunci: 'kunci-1234',
        );

        final req = terkirim.single;
        expect(req.url.path, '/v1/pesanan');
        expect(req.headers['Idempotency-Key'], 'kunci-1234');
        expect(req.headers['Authorization'], 'Bearer tok-1');
        expect(jsonDecode(req.body), {
          'isi': {'pk-1': 2},
          'metode': 'qris',
        });

        expect(p['dibuat'], isA<DateTime>());
        expect(p['batasBayar'], isA<DateTime>());
        expect(p['porsiPaket'], isA<Map<String, int>>());
        expect(p['tagihan'], isA<Map<String, String>>());
        expect(p['isi'], hasLength(1));
        expect(p['mengecek'], isFalse);
        expect(p['dibayarPada'], isNull);
      },
    );

    test('pesan galat dari server diteruskan apa adanya', () async {
      final api = PesananApi(
        klien(
          (_) async => http.Response(
            jsonEncode({
              'pesan': 'Sisa American Breakfast Set tinggal 1 porsi.',
            }),
            409,
          ),
        ),
      );
      expect(
        () => api.buat(isi: {'pk-1': 2}, metode: 'qris', kunci: 'kunci-1234'),
        throwsA(
          isA<GagalLayanan>().having(
            (g) => g.pesan,
            'pesan',
            'Sisa American Breakfast Set tinggal 1 porsi.',
          ),
        ),
      );
    });

    test('server ga bisa dihubungi jadi pesan yang bisa dibaca', () async {
      final api = PesananApi(
        klien((_) async => throw http.ClientException('putus')),
      );
      expect(
        api.daftar,
        throwsA(
          isA<GagalLayanan>().having(
            (g) => g.pesan,
            'pesan',
            contains('terhubung'),
          ),
        ),
      );
    });

    test('ubah paket ngirim isian lengkap ke server', () async {
      final api = PaketApi(klien((_) async => http.Response('{}', 200)));
      await api.ubah('pk-1', {
        'id': 'pk-1',
        'nama': 'Breakfast',
        'kategori': 'Hidangan utama',
        'foto': 'assets/images/paket/american_breakfast.jpg',
        'halal': true,
        'hargaAsli': 85000,
        'hargaDiskon': 34000,
        'totalPorsi': 8,
        'mulai': 900,
        'tutup': 1020,
        'sisaPorsi': 3,
      });
      final isi = jsonDecode(terkirim.single.body) as Map<String, dynamic>;
      expect(terkirim.single.method, 'PUT');
      expect(isi['halal'], isTrue);
      expect(isi['foto'], isNotEmpty);
      // field di luar isian (id, sisa) ga ikut dikirim
      expect(isi.containsKey('sisaPorsi'), isFalse);
      expect(isi.containsKey('id'), isFalse);
    });
  });

  group('PesananBloc tersambung server', () {
    test(
      'buat pesanan: isinya dari server, paket dimuat ulang, kunci diteruskan',
      () async {
        final server = _ServerPalsu();
        var paketDimuat = 0;
        final bloc = PesananBloc(
          pembayaran: const PembayaranTiruan(jeda: Duration.zero),
          server: server,
          muatUlangPaket: () => paketDimuat++,
        );
        bloc.add(
          PesananDibuat(
            idAkun: 'pembeli-1',
            namaPembeli: 'Rani Amelia',
            keranjang: {'pk-1': 2},
            daftarPaket: const [],
            metode: 'qris',
            kunci: 'kunci-checkout',
          ),
        );
        await bloc.stream.first;
        expect(bloc.state.single['nomor'], 'SR-2610201234');
        expect(server.kunci, 'kunci-checkout');
        expect(paketDimuat, 1);

        // cek bayar: status + kode dari server
        bloc.add(PembayaranDicek('ps-1'));
        await bloc.stream.firstWhere(
          (s) => s.single['status'] == StatusPesanan.disiapkan,
        );
        expect(bloc.state.single['kode'], 'SR-AB12');
        await bloc.close();
      },
    );

    test('server nolak: daftar ga berubah, pesannya keluar di galat', () async {
      final server = _ServerPalsu()..tolak = 'Jam ambil sudah lewat.';
      final bloc = PesananBloc(
        pembayaran: const PembayaranTiruan(jeda: Duration.zero),
        server: server,
      );
      final galat = bloc.galat.first;
      bloc.add(
        PesananDibuat(
          idAkun: 'pembeli-1',
          namaPembeli: 'Rani',
          keranjang: {'pk-1': 1},
          daftarPaket: const [],
          metode: 'qris',
        ),
      );
      expect(await galat, 'Jam ambil sudah lewat.');
      expect(bloc.state, isEmpty);
      await bloc.close();
    });

    test(
      'dimuat berkala: daftar diganti isi server, dikosongkan pas ganti akun',
      () async {
        final server = _ServerPalsu();
        final bloc = PesananBloc(
          pembayaran: const PembayaranTiruan(jeda: Duration.zero),
          server: server,
        );
        bloc.add(PesananDimuat());
        await bloc.stream.first;
        expect(bloc.state, hasLength(2));
        bloc.add(PesananDikosongkan());
        await bloc.stream.first;
        expect(bloc.state, isEmpty);
        await bloc.close();
      },
    );
  });
}

/// server pura-pura buat bloc, jawabannya udah dalam bentuk map layar
class _ServerPalsu implements LayananPesanan {
  String? kunci;
  String? tolak;

  Map<String, dynamic> _p(Map<String, dynamic> json) =>
      PesananApi.dariServer(json);

  @override
  Future<Map<String, dynamic>> buat({
    required Map<String, int> isi,
    required String metode,
    required String kunci,
  }) async {
    if (tolak != null) throw GagalLayanan(tolak!);
    this.kunci = kunci;
    return _p(pesananJson());
  }

  @override
  Future<Map<String, dynamic>> cekBayar(String id) async =>
      _p(pesananJson(status: StatusPesanan.disiapkan, kode: 'SR-AB12'));

  @override
  Future<List<Map<String, dynamic>>> daftar() async => [
    _p(pesananJson(id: 'ps-1')),
    _p(pesananJson(id: 'ps-2')),
  ];

  @override
  Future<Map<String, dynamic>> batal(
    String id, {
    required String alasan,
    bool otomatis = false,
  }) async => _p(pesananJson(status: StatusPesanan.dibatalkan));

  @override
  Future<Map<String, dynamic>> gantiMetode(String id, String metode) async =>
      _p(pesananJson());

  @override
  Future<Map<String, dynamic>> ubahStatus(String id, String status) async =>
      _p(pesananJson(status: status, kode: 'SR-AB12'));

  @override
  Future<Map<String, dynamic>> batalMitra(String id, String alasan) async =>
      _p(pesananJson(status: StatusPesanan.dibatalkan, kode: 'SR-AB12'));
}
