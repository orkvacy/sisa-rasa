import 'package:flutter/material.dart';

/// Mengubah angka jadi format rupiah, contoh 18000 jadi Rp18.000
String _rupiah(int nilai) {
  final teks = nilai.toString();
  final hasil = StringBuffer();
  for (var i = 0; i < teks.length; i++) {
    if (i > 0 && (teks.length - i) % 3 == 0) {
      hasil.write('.');
    }
    hasil.write(teks[i]);
  }
  return 'Rp${hasil.toString()}';
}

/// Satu kartu paket makanan di halaman beranda.
class KartuPaket extends StatelessWidget {
  final Map<String, dynamic> paket;

  const KartuPaket({super.key, required this.paket});

  @override
  Widget build(BuildContext context) {
    // hitung persen diskonnya dari harga asli dan harga setelah potong
    final int hargaAsli = paket['hargaAsli'];
    final int hargaDiskon = paket['hargaDiskon'];
    final int persen = ((hargaAsli - hargaDiskon) / hargaAsli * 100).round();

    // Container: bungkus luar kartu, dikasih warna putih, garis tepi, dan sudut membulat
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(14),
      ),
      // Padding: jarak dalam kartu biar isinya nggak nempel ke garis tepi
      child: Padding(
        padding: const EdgeInsets.all(12),
        // Row: nyusun kotak foto di kiri dan info paket di kanan
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Container: kotak foto paket, sementara masih pakai warna + ikon
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: paket['warna'],
                borderRadius: BorderRadius.circular(10),
              ),
              // Icon: gambar makanan sementara, nanti diganti foto asli
              child: Icon(
                paket['ikon'],
                size: 36,
                color: Colors.black54,
              ),
            ),

            // SizedBox: jarak antara kotak foto dan kolom info
            const SizedBox(width: 12),

            // Expanded: maksa kolom info ngisi sisa ruang di samping foto
            Expanded(
              // Column: numpuk nama paket, mitra, jam ambil, dan harga ke bawah
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text: nama paketnya
                  Text(
                    paket['nama'],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  // SizedBox: jarak tipis di bawah nama paket
                  const SizedBox(height: 2),

                  // Text: nama mitra yang jual
                  Text(
                    paket['mitra'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Row: baris kecil buat jam ambil dan jarak mitra
                  Row(
                    children: [
                      // Icon: jam, nandain slot waktu pengambilan
                      Icon(
                        Icons.schedule,
                        size: 13,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      // Text: rentang jam ambilnya
                      Text(
                        paket['slotAmbil'],
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Icon: penanda lokasi buat jarak
                      Icon(
                        Icons.place,
                        size: 13,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      // Text: jarak ke tempat mitra
                      Text(
                        paket['jarak'],
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Row: harga di kiri, sisa porsi di kanan, makanya dipisah spaceBetween
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Row: nempelin harga coret sama harga diskon biar sebaris
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Text: harga asli, dicoret pakai lineThrough
                          Text(
                            _rupiah(hargaAsli),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Text: harga setelah diskon, dibikin menonjol
                          Text(
                            _rupiah(hargaDiskon),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),

                      // Container: label kecil buat persen diskon sama sisa porsi
                      Container(
                        // Padding pakai symmetric karena kiri-kanan dan atas-bawah beda ukuran
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        // Text: info diskon dan sisa porsinya
                        child: Text(
                          '-$persen% · sisa ${paket['sisaPorsi']}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
