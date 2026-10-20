/// akun contoh buat testing, gantiin login dulu sampai backend jadi.
/// peran: 'pembeli', 'mitra', atau 'admin'
/// kata sandi semua akun contoh di atas, khusus buat nyoba layar Masuk.
/// cuma dipake AkunTiruan, server asli ga punya akun ini
const sandiUji = 'sisarasa123';

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
  {
    'id': 'a1',
    'nama': 'Admin Sisa Rasa',
    'email': 'admin@contoh.id',
    'peran': 'admin',
  },
];
