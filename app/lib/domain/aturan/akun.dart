import 'dart:math';

String rapikanEmail(String email) => email.trim().toLowerCase();

/// format email sederhana: ada@nama.domain
bool emailValid(String email) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(email.trim());

/// F-29: minimal 8 karakter
const panjangSandiMinimal = 8;

/// "rani.amelia@gmail.com" -> "rani•••@gmail.com", buat ditampilin di layar kode
String samarkanEmail(String email) {
  final rapi = rapikanEmail(email);
  final at = rapi.indexOf('@');
  if (at <= 0) return rapi;
  final depan = rapi.substring(0, at);
  return '${depan.substring(0, min(4, depan.length))}•••${rapi.substring(at)}';
}
