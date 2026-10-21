import 'dart:math';

/// jarak garis lurus dua titik di bumi (rumus haversine), dalam km.
/// cukup buat "seberapa dekat", bukan jarak tempuh lewat jalan
double jarakKm(double lat1, double lng1, double lat2, double lng2) {
  const jariJariBumi = 6371.0;
  double rad(double derajat) => derajat * pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      pow(sin(dLat / 2), 2) +
      cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(dLng / 2), 2);
  return 2 * jariJariBumi * asin(sqrt(a));
}

/// "350 m", "1,2 km", "12 km". di bawah 1 km dibuletin ke 50 m terdekat
String teksJarak(double km) {
  if (km < 1) {
    final meter = max(50, (km * 1000 / 50).round() * 50);
    return meter >= 1000 ? '1 km' : '$meter m';
  }
  if (km < 10) return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  return '${km.round()} km';
}
