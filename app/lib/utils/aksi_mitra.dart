import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// buka aplikasi peta, dicari pake alamat mitra (F-52, F-54)
Future<void> bukaPeta(BuildContext context, String alamat) async {
  final url = Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': alamat,
  });
  final berhasil = await launchUrl(url, mode: LaunchMode.externalApplication);
  if (!berhasil && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Aplikasi peta tidak bisa dibuka')),
    );
  }
}

/// telepon / WhatsApp mitra (F-52). nomornya diisi mitra di profil usaha (F-64),
/// jadi selama belum ada backend tombolnya cuma ngasih tau dulu
void hubungiMitra(BuildContext context, String mitra) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text('Nomor $mitra belum tersedia di versi ini')),
    );
}
