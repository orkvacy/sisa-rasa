import 'package:sisa_rasa/data/sumber/klien_api.dart';
import 'package:sisa_rasa/domain/repositories/layanan_favorit.dart';

/// mitra favorit di server Go (backend/internal/toko/favorit.go)
class FavoritApi implements LayananFavorit {
  FavoritApi(this.klien);

  final KlienApi klien;

  @override
  Future<List<Map<String, dynamic>>> semua() async {
    final hasil = await klien.get('/v1/favorit');
    return [
      for (final m in hasil['mitra'] as List)
        Map<String, dynamic>.from(m as Map),
    ];
  }

  @override
  Future<void> atur(String idMitra, {required bool suka}) => suka
      ? klien.put('/v1/favorit/$idMitra', null)
      : klien.delete('/v1/favorit/$idMitra');
}
