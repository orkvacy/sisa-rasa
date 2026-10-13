import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// jaga aturan lapisan Clean Architecture (B-04, NF-04).
/// arah ketergantungan cuma boleh: presentation -> domain <- data
void main() {
  /// isi baris import semua berkas .dart di [folder]
  Map<String, List<String>> impor(String folder) => {
    for (final f in Directory(folder).listSync(recursive: true))
      if (f is File && f.path.endsWith('.dart'))
        f.path: [
          for (final baris in f.readAsLinesSync())
            if (baris.startsWith('import ')) baris,
        ],
  };

  /// berkas di [folder] yg import salah satu dari [dilarang]
  List<String> pelanggaran(String folder, List<String> dilarang) => [
    for (final MapEntry(key: berkas, value: daftar) in impor(folder).entries)
      for (final baris in daftar)
        if (dilarang.any(baris.contains)) '$berkas: $baris',
  ];

  test(
    'presentation ga boleh nyentuh data/, cuma lewat kontrak di domain/',
    () {
      expect(
        pelanggaran('lib/presentation', ['package:sisa_rasa/data/']),
        isEmpty,
      );
    },
  );

  test(
    'domain berdiri sendiri: tanpa Flutter, data/, maupun presentation/',
    () {
      expect(
        pelanggaran('lib/domain', [
          'package:flutter/',
          'package:flutter_bloc/',
          'package:sisa_rasa/data/',
          'package:sisa_rasa/presentation/',
        ]),
        isEmpty,
      );
    },
  );

  test('data ga boleh nyentuh presentation/', () {
    expect(
      pelanggaran('lib/data', ['package:sisa_rasa/presentation/']),
      isEmpty,
    );
  });

  test('NF-02: ga ada warna ditulis langsung di presentation/', () {
    final langsung = [
      for (final f in Directory('lib/presentation').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            f.readAsStringSync().contains('Color(0x'))
          f.path,
    ];
    expect(langsung, isEmpty);
  });
}
