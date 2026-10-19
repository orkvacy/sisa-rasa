import 'package:flutter_test/flutter_test.dart';
import 'package:sisa_rasa/data/repositories/paket_lokal.dart';
import 'package:sisa_rasa/presentation/cubit/paket_cubit.dart';

void main() {
  late PaketCubit cubit;

  setUp(() async {
    cubit = PaketCubit(layanan: PaketLokal());
    await cubit.muat();
  });
  tearDown(() => cubit.close());

  Map<String, dynamic> isian({int porsi = 5, int tutup = 18 * 60}) => {
    'mitra': 'Ibis Hotel',
    'nama': 'Nasi Kuning',
    'deskripsi': '',
    'kategori': 'Hidangan utama',
    'hargaAsli': 30000,
    'hargaDiskon': 12000,
    'totalPorsi': porsi,
    'mulai': 16 * 60,
    'tutup': tutup,
    'mejaBerbagi': false,
  };

  test('paket baru langsung tersedia, data gerai ikut mitranya (F-15)', () {
    final id = cubit.tambahPaket(isian());
    final paket = cubit.cari(id);

    expect(paket['sisaPorsi'], 5);
    expect(paket['alamat'], 'Jl. Mulawarman 2, Samarinda');
    expect(PaketCubit.tampilUntukPembeli(paket), isTrue);
  });

  test('jumlah porsi diubah, sisa porsi ikut geser tapi ga minus (F-18)', () {
    final id = cubit.tambahPaket(isian(porsi: 5));
    cubit.ubahSisa(id, 1); // 4 porsi udah kepesen

    cubit.ubahPaket(id, isian(porsi: 8));
    expect(cubit.cari(id)['sisaPorsi'], 4);

    cubit.ubahPaket(id, isian(porsi: 2));
    expect(cubit.cari(id)['sisaPorsi'], 0);
  });

  test('nonaktif dan gerai tutup disembunyikan dari pembeli (F-45, F-51)', () {
    final id = cubit.tambahPaket(isian());
    cubit.aturAktif(id, aktif: false);
    expect(PaketCubit.tampilUntukPembeli(cubit.cari(id)), isFalse);

    cubit.aturAktif(id, aktif: true);
    cubit.aturGerai('Ibis Hotel', buka: false);
    expect(PaketCubit.tampilUntukPembeli(cubit.cari(id)), isFalse);
  });

  test('hapus paket (F-18)', () {
    final id = cubit.tambahPaket(isian());
    cubit.hapusPaket(id);
    expect(cubit.state.any((p) => p['id'] == id), isFalse);
  });
}
