import 'package:flutter/material.dart';

/// warna khusus Sisa Rasa yang ga ada tempatnya di ColorScheme
/// (momen dampak sama warna mendesak). nilainya dari variabel figma "Sisa Rasa / Warna"
@immutable
class SisaRasaColors extends ThemeExtension<SisaRasaColors> {
  final Color moment;
  final Color onMoment;
  final Color urgent;
  final Color urgentContainer;

  const SisaRasaColors({
    required this.moment,
    required this.onMoment,
    required this.urgent,
    required this.urgentContainer,
  });

  static const terang = SisaRasaColors(
    moment: Color(0xFF1A382B),
    onMoment: Color(0xFFFFFFFF),
    urgent: Color(0xFF9A4A0B),
    urgentContainer: Color(0xFFFBEBDD),
  );

  static const gelap = SisaRasaColors(
    moment: Color(0xFF12261D),
    onMoment: Color(0xFFEAF3EE),
    urgent: Color(0xFFF0A35E),
    urgentContainer: Color(0xFF3A2A1C),
  );

  /// biar di widget cukup tulis SisaRasaColors.of(context).moment
  static SisaRasaColors of(BuildContext context) =>
      Theme.of(context).extension<SisaRasaColors>()!;

  @override
  SisaRasaColors copyWith({
    Color? moment,
    Color? onMoment,
    Color? urgent,
    Color? urgentContainer,
  }) {
    return SisaRasaColors(
      moment: moment ?? this.moment,
      onMoment: onMoment ?? this.onMoment,
      urgent: urgent ?? this.urgent,
      urgentContainer: urgentContainer ?? this.urgentContainer,
    );
  }

  @override
  SisaRasaColors lerp(ThemeExtension<SisaRasaColors>? other, double t) {
    if (other is! SisaRasaColors) return this;
    return SisaRasaColors(
      moment: Color.lerp(moment, other.moment, t)!,
      onMoment: Color.lerp(onMoment, other.onMoment, t)!,
      urgent: Color.lerp(urgent, other.urgent, t)!,
      urgentContainer: Color.lerp(urgentContainer, other.urgentContainer, t)!,
    );
  }
}

/// gaya teks yang ga masuk TextTheme: kode ambil SR-xxxx pake JetBrains Mono
class SisaRasaText {
  /// ukuran 40 buat tiket, 18-22 buat daftar (pake copyWith(fontSize:))
  static const code = TextStyle(
    fontFamily: 'JetBrainsMono',
    fontWeight: FontWeight.w700,
    fontSize: 40,
    height: 48 / 40,
    letterSpacing: 40 * 0.05,
  );

  /// angka jam sama harga harus lurus sejajar
  static const tabular = [FontFeature.tabularFigures()];
}

/// tema aplikasi (terang + gelap), nilainya dari docs/DESAIN.md bagian 2-4
class SisaRasaTema {
  static const _radiusKontrol = 16.0;

  static ThemeData terang() => _bangun(
        ColorScheme(
          brightness: Brightness.light,
          primary: const Color(0xFF1A382B), // accent/leaf
          onPrimary: const Color(0xFFFFFFFF), // accent/on
          primaryContainer: const Color(0xFFE2E9E3), // accent/soft
          onPrimaryContainer: const Color(0xFF1A382B),
          secondary: const Color(0xFF5E5A53),
          onSecondary: const Color(0xFFFFFFFF),
          error: const Color(0xFFB3261E), // signal/error
          onError: const Color(0xFFFFFFFF),
          surface: const Color(0xFFF6F3EE), // bg/ground
          onSurface: const Color(0xFF1D1C19), // text/primary
          onSurfaceVariant: const Color(0xFF5E5A53), // text/secondary
          surfaceContainerLowest: const Color(0xFFFFFFFF), // bg/surface
          inverseSurface: const Color(0xFF1D1C19), // bg/inverse
          onInverseSurface: const Color(0xFFFFFFFF), // text/inverse
          outline: const Color(0xFF8F887D), // line/control
          outlineVariant: const Color(0xFFE4DED4), // line/default
          scrim: const Color(0xFF1D1C19), // bg/scrim
        ),
        SisaRasaColors.terang,
      );

  static ThemeData gelap() => _bangun(
        ColorScheme(
          brightness: Brightness.dark,
          primary: const Color(0xFF7FC3A0),
          onPrimary: const Color(0xFF0F1A14),
          primaryContainer: const Color(0xFF1E2C25),
          onPrimaryContainer: const Color(0xFF7FC3A0),
          secondary: const Color(0xFFB3ADA4),
          onSecondary: const Color(0xFF171513),
          error: const Color(0xFFF2B8B5),
          onError: const Color(0xFF171513),
          surface: const Color(0xFF171513),
          onSurface: const Color(0xFFF2EFEA),
          onSurfaceVariant: const Color(0xFFB3ADA4),
          surfaceContainerLowest: const Color(0xFF1B211E),
          inverseSurface: const Color(0xFFF2EFEA),
          onInverseSurface: const Color(0xFF1B211E),
          outline: const Color(0xFF7A746B),
          outlineVariant: const Color(0xFF34302B),
          scrim: const Color(0xFF000000),
        ),
        SisaRasaColors.gelap,
      );

  static ThemeData _bangun(ColorScheme cs, SisaRasaColors ekstensi) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      fontFamily: 'PlusJakartaSans',
      textTheme: _teks(cs),
      extensions: [ekstensi],
      // tap target 48 dp walau chip tingginya 36
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: cs.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(color: cs.outlineVariant, space: 1),
      // satu tombol utama per layar, tinggi 52, radius 16
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusKontrol),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            height: 20 / 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: cs.onSurface,
          side: BorderSide(color: cs.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusKontrol),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            height: 20 / 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _garisIsian(cs.outline),
        enabledBorder: _garisIsian(cs.outline),
        focusedBorder: _garisIsian(cs.primary, lebar: 2),
        errorBorder: _garisIsian(cs.error),
        focusedErrorBorder: _garisIsian(cs.error, lebar: 2),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerLowest,
        selectedColor: cs.inverseSurface,
        side: BorderSide(color: cs.outlineVariant),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: cs.onInverseSurface,
        ),
        checkmarkColor: cs.onInverseSurface,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.inverseSurface,
        contentTextStyle: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: cs.onInverseSurface,
        ),
        actionTextColor: cs.onInverseSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
    );
  }

  static OutlineInputBorder _garisIsian(Color warna, {double lebar = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(_radiusKontrol),
      borderSide: BorderSide(color: warna, width: lebar),
    );
  }

  /// tabel tipografi DESAIN.md bagian 3. letterSpacing = persen x ukuran
  static TextTheme _teks(ColorScheme cs) {
    TextStyle gaya(
      double ukuran,
      double tinggi,
      FontWeight berat,
      double spasiPersen,
    ) {
      return TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: ukuran,
        height: tinggi / ukuran,
        fontWeight: berat,
        letterSpacing: ukuran * spasiPersen,
        color: cs.onSurface,
      );
    }

    return TextTheme(
      displaySmall: gaya(36, 40, FontWeight.w800, -0.035), // judul layar
      headlineMedium: gaya(28, 34, FontWeight.w800, -0.03), // judul app bar
      headlineSmall: gaya(26, 32, FontWeight.w800, -0.03), // header jam, judul detail
      titleLarge: gaya(28, 32, FontWeight.w800, -0.02), // harga besar
      titleMedium: gaya(18, 24, FontWeight.w800, -0.015), // judul bagian
      titleSmall: gaya(16, 22, FontWeight.w700, -0.01), // nama kartu
      bodyLarge: gaya(16, 24, FontWeight.w400, 0), // isi
      bodyMedium: gaya(14, 20, FontWeight.w500, 0), // pendukung
      labelLarge: gaya(16, 20, FontWeight.w700, 0), // tombol
      labelSmall: gaya(12, 16, FontWeight.w600, 0), // keterangan, min 11
    );
  }
}
