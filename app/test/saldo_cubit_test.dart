import 'package:flutter_test/flutter_test.dart';
import 'package:sisa_rasa/cubit/saldo_cubit.dart';
import 'package:sisa_rasa/data/status_pesanan.dart';

void main() {
  // rabu siang, biar "minggu ini" nyakup kemarin juga
  final sekarang = DateTime(2026, 10, 14, 16, 20);
  late SaldoCubit cubit;

  setUp(() => cubit = SaldoCubit(sekarang: sekarang));
  tearDown(() => cubit.close());

  Map<String, dynamic> pesanan(String status, {int subtotal = 20000}) => {
    'mitra': 'Ibis Hotel',
    'kode': 'SR-AB12',
    'idAkun': 'u1',
    'status': status,
    'subtotal': subtotal,
    'dibuat': sekarang,
    'diambilPada': sekarang,
  };

  test('saldo awal: dana masuk dikurangi pencairan pagi ini', () {
    final riwayat = cubit.riwayat('Ibis Hotel', const []);
    expect(saldoTersedia(riwayat), 12600);
    expect(totalMingguIni(riwayat, 'cair', sekarang: sekarang), 64800);
  });

  test(
    'pesanan selesai / tidak diambil nambah saldo, dipotong komisi (F-48)',
    () {
      final riwayat = cubit.riwayat('Ibis Hotel', [
        pesanan(StatusPesanan.selesai),
        pesanan(StatusPesanan.tidakDiambil),
        // belum diambil, belum masuk saldo
        pesanan(StatusPesanan.siapDiambil),
      ]);
      expect(saldoTersedia(riwayat), 12600 + 18000 + 18000);
      expect(riwayat.first['jumlah'], 18000);
      expect(riwayat.first['pembeli'], 'Rani A.');
    },
  );

  test('nama rekening harus sama dengan nama usaha (F-49)', () {
    expect(namaRekeningCocok(' ibis   hotel ', 'Ibis Hotel'), isTrue);
    expect(namaRekeningCocok('IBIS', 'Ibis Hotel'), isFalse);

    cubit.simpanRekening(
      'Ibis Hotel',
      bank: 'BRI',
      nomor: '9876543210',
      nama: 'IBIS HOTEL',
    );
    expect(cubit.rekening('Ibis Hotel')!['bank'], 'BRI');
    expect(rekeningSingkat('BRI', '9876543210'), 'BRI · 3210');
  });
}
