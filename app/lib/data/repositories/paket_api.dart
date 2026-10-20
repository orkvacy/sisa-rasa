import 'package:sisa_rasa/data/sumber/klien_api.dart';
import 'package:sisa_rasa/domain/repositories/layanan_paket.dart';

/// paket dari server Go (backend/internal/toko)
class PaketApi implements LayananPaket {
  PaketApi(this.klien);

  final KlienApi klien;

  @override
  bool get lokal => false;

  @override
  Future<List<Map<String, dynamic>>> semua() async {
    final hasil = await klien.get('/v1/paket');
    return [
      for (final paket in hasil['paket'] as List)
        Map<String, dynamic>.from(paket as Map),
    ];
  }

  /// cuma field yang diterima server (IsianPaket di backend)
  static Map<String, dynamic> _isian(Map<String, dynamic> isian) => {
    'nama': isian['nama'],
    'deskripsi': isian['deskripsi'] ?? '',
    'kategori': isian['kategori'],
    'foto': isian['foto'] ?? '',
    'halal': isian['halal'] ?? false,
    'mejaBerbagi': isian['mejaBerbagi'] ?? false,
    'hargaAsli': isian['hargaAsli'],
    'hargaDiskon': isian['hargaDiskon'],
    'totalPorsi': isian['totalPorsi'],
    'mulai': isian['mulai'],
    'tutup': isian['tutup'],
  };

  @override
  Future<void> tambah(Map<String, dynamic> isian) =>
      klien.post('/v1/mitra/paket', _isian(isian));

  @override
  Future<void> ubah(String id, Map<String, dynamic> isian) =>
      klien.put('/v1/mitra/paket/$id', _isian(isian));

  @override
  Future<void> hapus(String id) => klien.delete('/v1/mitra/paket/$id');

  @override
  Future<void> aturSisa(String id, int sisa) =>
      klien.patch('/v1/mitra/paket/$id/sisa', {'sisa': sisa});

  @override
  Future<void> aturAktif(String id, {required bool aktif}) =>
      klien.patch('/v1/mitra/paket/$id/aktif', {'aktif': aktif});

  @override
  Future<void> aturGerai({required bool tutup}) =>
      klien.put('/v1/mitra/gerai/tutup', {'tutup': tutup});

  /// server ngecilin + ngebuang EXIF, lalu nyimpen ke R2. balikin URL fotonya
  @override
  Future<String> unggahFoto(String jalur) async {
    final hasil = await klien.unggah('/v1/mitra/foto', 'foto', jalur);
    return hasil['foto'] as String;
  }
}
