/// akun contoh buat testing, gantiin login dulu sampai backend jadi.
/// peran: 'pembeli' atau 'mitra' (admin nyusul di sprint akhir)
const List<Map<String, String>> dummyAkun = [
  {
    'id': 'u1',
    'nama': 'Rani Amelia',
    'email': 'rani.amelia@gmail.com',
    'peran': 'pembeli',
  },
  {
    'id': 'u2',
    'nama': 'Dimas Pratama',
    'email': 'dimas.pratama@contoh.id',
    'peran': 'pembeli',
  },
  {
    'id': 'm1',
    'nama': 'Ibis Hotel',
    'email': 'dapur.ibis@contoh.id',
    'peran': 'mitra',
  },
];

/// nama pembeli yg ditampilin ke mitra, dipendekin: "Rani Amelia" -> "Rani A."
String namaPembeli(String idAkun) {
  final akun = dummyAkun.where((a) => a['id'] == idAkun).firstOrNull;
  if (akun == null) return 'Pembeli';
  final kata = akun['nama']!.split(' ');
  return kata.length == 1 ? kata.first : '${kata.first} ${kata[1][0]}.';
}
