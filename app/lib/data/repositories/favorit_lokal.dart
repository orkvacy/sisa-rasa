import 'package:sisa_rasa/data/sumber/dummy_deals.dart';
import 'package:sisa_rasa/domain/repositories/layanan_favorit.dart';

/// favorit tanpa server: cuma di memori, ilang pas aplikasi ditutup.
/// data contoh ga punya id mitra, jadi nama mitranya dipake sebagai id
class FavoritLokal implements LayananFavorit {
  final _id = <String>[];

  @override
  Future<List<Map<String, dynamic>>> semua() async => [
    for (final id in _id)
      {
        'id': id,
        'nama': id,
        'jenis':
            dummyDeals.firstWhere(
                  (p) => p['mitra'] == id,
                  orElse: () => const {},
                )['jenisMitra']
                as String? ??
            'Mitra',
      },
  ];

  @override
  Future<void> atur(String idMitra, {required bool suka}) async {
    _id.remove(idMitra);
    if (suka) _id.insert(0, idMitra);
  }
}
