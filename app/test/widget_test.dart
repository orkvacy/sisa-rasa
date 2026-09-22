import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sisa_rasa/main.dart';

void main() {
  testWidgets('beranda nampilin nama aplikasi sama daftar paket',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SisaRasaApp());

    // nama aplikasi harus muncul di app bar
    expect(find.text('Sisa Rasa'), findsOneWidget);

    // judul daftar paket harus ada
    expect(find.text('Paket hari ini'), findsOneWidget);

    // kolom cari harus ada
    expect(find.byType(TextField), findsOneWidget);
  });
}
