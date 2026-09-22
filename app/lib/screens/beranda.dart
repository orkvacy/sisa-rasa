import 'package:flutter/material.dart';
import 'package:sisa_rasa/data/dummy_deals.dart';
import 'package:sisa_rasa/widgets/kartu_paket.dart';

/// landing page
class Beranda extends StatelessWidget {
  const Beranda({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold: kerangka halaman, nyediain appBar, body, sama navigasi bawah
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),

      // appBar: bar atas, isinya nama aplikasi sama ikon notifikasi
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // Text: nama aplikasinya
        title: const Text(
          'Sisa Rasa',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E7D32),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            // icon notif
            child: Icon(
              Icons.notifications_none,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),

      // biar ga ketutup bawah hp
      body: SafeArea(
        // biar bisa scroll kalau over
        child: SingleChildScrollView(
          //numpuk kolom cari, judul, n daftar kartu dari atas ke bawah
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // jarak kiri-kanan sama tapi beda sama atas-bawah
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari paket atau mitra',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: Icon(
                      Icons.search,
                      color: Colors.grey.shade400,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // bagian judul daftar
                    const Text(
                      'Paket hari ini',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${dummyDeals.length} tersedia',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // box sebelum ke card
              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.all(16),
                // tumpuk di bawah
                child: Column(
                  children: [
                    for (final paket in dummyDeals) ...[
                      KartuPaket(paket: paket),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: const Color(0xFF2E7D32),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_outlined),
            label: 'Pesanan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Akun',
          ),
        ],
      ),
    );
  }
}
