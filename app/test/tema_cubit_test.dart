import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisa_rasa/presentation/cubit/tema_cubit.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('TemaCubit mulai dengan ThemeMode.system secara default', () {
    final cubit = TemaCubit();
    expect(cubit.state, ThemeMode.system);
    cubit.close();
  });

  test('TemaCubit.ganti mengubah state dan menyimpan ke penyimpanan', () async {
    final cubit = TemaCubit();
    await cubit.ganti(ThemeMode.dark);
    expect(cubit.state, ThemeMode.dark);

    final cubitBaru = TemaCubit();
    await cubitBaru.pulihkan();
    expect(cubitBaru.state, ThemeMode.dark);

    await cubitBaru.ganti(ThemeMode.light);
    expect(cubitBaru.state, ThemeMode.light);

    cubit.close();
    cubitBaru.close();
  });

  test('TemaCubit.label mengembalikan label bahasa Indonesia yang benar', () {
    expect(TemaCubit.label(ThemeMode.system), 'Ikuti sistem');
    expect(TemaCubit.label(ThemeMode.light), 'Terang');
    expect(TemaCubit.label(ThemeMode.dark), 'Gelap');
  });
}
