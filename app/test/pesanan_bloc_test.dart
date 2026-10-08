import 'package:flutter_test/flutter_test.dart';
import 'package:sisa_rasa/bloc/pesanan_bloc.dart';
import 'package:sisa_rasa/bloc/pesanan_event.dart';
import 'package:sisa_rasa/data/dummy_deals.dart';
import 'package:sisa_rasa/data/pembayaran.dart';
import 'package:sisa_rasa/data/status_pesanan.dart';

/// nunggu sampe state bloc memenuhi [cek]
Future<void> tunggu(
  PesananBloc bloc,
  bool Function(List<Map<String, dynamic>> state) cek,
) async {
  if (!cek(bloc.state)) await bloc.stream.firstWhere(cek);
}

void main() {
  late PesananBloc bloc;
  late List<Map<String, int>> ditahan;
  late List<Map<String, int>> dilepas;

  setUp(() {
    ditahan = [];
    dilepas = [];
    bloc = PesananBloc(
      pembayaran: const PembayaranTiruan(jeda: Duration.zero),
      tahanPorsi: ditahan.add,
      lepasPorsi: dilepas.add,
    );
  });

  tearDown(() => bloc.close());

  Future<String> pesanSandwich(int jumlah) async {
    bloc.add(
      PesananDibuat(
        idAkun: 'u1',
        keranjang: {'p1': jumlah},
        daftarPaket: dummyDeals,
        metode: MetodeBayar.qris,
      ),
    );
    await tunggu(
      bloc,
      (s) => s.isNotEmpty && (s.first['tagihan'] as Map).isNotEmpty,
    );
    return bloc.state.first['id'];
  }

  test('pesanan baru menunggu bayar, porsi ditahan, belum ada kode', () async {
    await pesanSandwich(2);
    final pesanan = bloc.state.first;

    expect(pesanan['status'], StatusPesanan.menungguBayar);
    expect(pesanan['kode'], isNull);
    // biaya layanan 10% dari 28.000
    expect(pesanan['biayaLayanan'], 2800);
    expect(pesanan['total'], 28000 + 2800);
    expect(pesanan['hemat'], (35000 - 14000) * 2);
    expect(ditahan, [
      {'p1': 2},
    ]);
  });

  test('cek bayar yg lunas jadi disiapkan dan dapet kode SR- (F-11)', () async {
    final id = await pesanSandwich(1);
    bloc.add(PembayaranDicek(id));
    await tunggu(bloc, (s) => s.first['status'] == StatusPesanan.disiapkan);

    expect(bloc.state.first['kode'], matches(RegExp(r'^SR-[A-Z2-9]{4}$')));
    expect(bloc.state.first['mengecek'], isFalse);
  });

  test('batal dua kali barengan, porsi cuma dibalikin sekali (F-40)', () async {
    final id = await pesanSandwich(2);
    bloc.add(PesananDibatalkan(id, alasan: 'habis waktu'));
    bloc.add(PesananDibatalkan(id, alasan: 'habis waktu'));
    await tunggu(bloc, (s) => s.first['status'] == StatusPesanan.dibatalkan);
    await Future<void>.delayed(Duration.zero);

    expect(dilepas, [
      {'p1': 2},
    ]);
    expect(bloc.state.first['alasan'], 'habis waktu');
  });

  test('pesanan yg udah lunas ga bisa dibatalin pembeli (F-55)', () async {
    final id = await pesanSandwich(1);
    bloc.add(PembayaranDicek(id));
    await tunggu(bloc, (s) => s.first['status'] == StatusPesanan.disiapkan);

    bloc.add(PesananDibatalkan(id, alasan: 'berubah pikiran'));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.first['status'], StatusPesanan.disiapkan);
    expect(dilepas, isEmpty);
  });

  test('tahapan dari mitra: siap diambil lalu selesai, ga bisa loncat dari belum bayar', () async {
    final id = await pesanSandwich(1);

    // belum dibayar: ditolak
    bloc.add(StatusPesananDiubah(id, StatusPesanan.siapDiambil));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.first['status'], StatusPesanan.menungguBayar);

    bloc.add(PembayaranDicek(id));
    await tunggu(bloc, (s) => s.first['status'] == StatusPesanan.disiapkan);
    expect(bloc.state.first['dibayarPada'], isA<DateTime>());

    bloc.add(StatusPesananDiubah(id, StatusPesanan.siapDiambil));
    await tunggu(bloc, (s) => s.first['status'] == StatusPesanan.siapDiambil);
    bloc.add(StatusPesananDiubah(id, StatusPesanan.selesai));
    await tunggu(bloc, (s) => s.first['status'] == StatusPesanan.selesai);
    expect(bloc.state.first['diambilPada'], isA<DateTime>());
    expect(bloc.state.first['nomor'], matches(RegExp(r'^SR-\d{9}$')));
  });

  test('ganti metode sebelum lunas, tagihan dibikin ulang', () async {
    final id = await pesanSandwich(1);
    expect(bloc.state.first['tagihan']['isiQr'], isNotNull);

    bloc.add(MetodeDiganti(id, MetodeBayar.vaMandiri));
    await tunggu(
      bloc,
      (s) =>
          s.first['metode'] == MetodeBayar.vaMandiri &&
          (s.first['tagihan'] as Map).containsKey('nomorVa'),
    );
    expect(
      MetodeBayar.nama(bloc.state.first['metode']),
      'Virtual Account Mandiri',
    );
  });

  test(
    'mitra batalin pesanan lunas: status batal, porsi ga dibalikin (F-42)',
    () async {
      final id = await pesanSandwich(1);
      // belum dibayar: mitra ga bisa batalin
      bloc.add(PesananDibatalkanMitra(id, alasan: 'Paket sudah habis.'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.first['status'], StatusPesanan.menungguBayar);

      bloc.add(PembayaranDicek(id));
      await tunggu(bloc, (s) => s.first['status'] == StatusPesanan.disiapkan);
      bloc.add(PesananDibatalkanMitra(id, alasan: 'Paket sudah habis.'));
      await tunggu(bloc, (s) => s.first['status'] == StatusPesanan.dibatalkan);
      expect(bloc.state.first['olehMitra'], isTrue);
      expect(dilepas, isEmpty);
    },
  );
}
