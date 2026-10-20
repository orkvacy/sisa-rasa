/// alamat server Go. kosong = semua pakai tiruan di HP.
/// diisi pas build / run, misal:
///   flutter run --dart-define=API_URL=https://api.sisarasa.web.id
const alamatApi = String.fromEnvironment('API_URL');

/// web client ID Google (sama kayak GOOGLE_CLIENT_ID di server), bukan rahasia.
/// kosong = tombol "Masuk dengan Google" ga ditampilin:
///   flutter run --dart-define=API_URL=... --dart-define=GOOGLE_CLIENT_ID=xxx.apps.googleusercontent.com
const googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
