# Sisa Rasa — aplikasi mobile

Kode Flutter aplikasi Sisa Rasa (pembeli, mitra, dan admin dalam satu
aplikasi). Penjelasan aplikasi, cara kerja, dan cara menghubungkan ke database
ada di [README utama](../README.md).

## Menjalankan

```powershell
flutter pub get

# data tiruan di HP, tanpa server
flutter run

# tersambung ke server Go (lihat ../backend/README.md)
flutter run --dart-define=API_URL=http://10.0.2.2:8080
```

## Tes

```powershell
flutter analyze
flutter test
```

## Build APK

```powershell
flutter build apk --release --split-per-abi --dart-define=API_URL=https://api.sisarasa.web.id --dart-define=GOOGLE_CLIENT_ID=<web client id>
```

Hasilnya di `build/app/outputs/flutter-apk/`. Untuk hampir semua HP Android
sekarang pakai `app-arm64-v8a-release.apk`.
