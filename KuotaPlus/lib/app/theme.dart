import 'package:flutter/material.dart';

/// Design token dari docs/UI-KuotaPlus.md.
abstract final class AppColors {
  static const primary = Color(0xFF1E40AF);
  static const onPrimary = Color(0xFFFFFFFF);
  static const background = Color(0xFFF6F7F9);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF111827);
  static const textMuted = Color(0xFF4B5563);
  static const border = Color(0xFFE5E7EB);
  static const success = Color(0xFF15803D);
  static const warning = Color(0xFFB45309);
  static const danger = Color(0xFFB91C1C);
  static const noData = Color(0xFF9CA3AF);

  // Tint latar untuk chip dan kartu status. Teks di atasnya memakai warna status aslinya (semua ≥ 4,5:1).
  static const primaryContainer = Color(0xFFEAF0FF);
  static const successContainer = Color(0xFFDCFCE7);
  static const warningContainer = Color(0xFFFEF3C7);
  static const dangerContainer = Color(0xFFFEE2E2);
  static const neutralContainer = Color(0xFFF3F4F6);

  /// Pasangan tint untuk warna status; warna lain jatuh ke tint netral.
  static Color containerOf(Color color) => switch (color) {
    primary => primaryContainer,
    success => successContainer,
    warning => warningContainer,
    danger => dangerContainer,
    _ => neutralContainer,
  };
}

/// Warna maskot Kuo. Sengaja tanpa hijau, kuning tua, dan merah supaya tidak terbaca sebagai status.
abstract final class MascotColors {
  static const body = AppColors.primary;
  static const light = Color(0xFFBFD3FF);
  static const ink = Color(0xFF0B1B4D);
  static const white = Color(0xFFFFFFFF);
}

abstract final class AppRadius {
  static const card = 16.0;
  static const control = 12.0;
}

/// Durasi dan kurva Material 3 bawaan Flutter. Widget tidak menulis milidetik sendiri.
abstract final class Motion {
  static const press = Durations.short3; // 150 ms
  static const fade = Durations.short4; // 200 ms
  static const enter = Durations.medium4; // 400 ms
  static const countUp = Durations.long3; // 600 ms
  static const standard = Easing.standard;
  static const enterCurve = Easing.emphasizedDecelerate;
  static const exitCurve = Easing.emphasizedAccelerate;

  /// Pengaturan "kurangi animasi" (Android) atau navigasi aksesibel aktif.
  static bool reduced(BuildContext context) {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  /// [duration], atau nol jika animasi harus dimatikan.
  static Duration of(BuildContext context, Duration duration) => reduced(context) ? Duration.zero : duration;
}

const fontFamily = 'PlusJakartaSans';
const _tabular = [FontFeature.tabularFigures()];

/// Angka utama layar (sisa kuota, total bayar). Hanya satu per layar; tabular supaya tidak bergeser saat berubah.
const displayNumber = TextStyle(
  fontFamily: fontFamily,
  fontSize: 36,
  height: 40 / 36,
  fontWeight: FontWeight.w700,
  color: AppColors.text,
  fontFeatures: _tabular,
);

/// Angka pendukung (pulsa, harga, jatah harian).
const secondaryNumber = TextStyle(
  fontFamily: fontFamily,
  fontSize: 24,
  height: 32 / 24,
  fontWeight: FontWeight.w600,
  color: AppColors.text,
  fontFeatures: _tabular,
);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.primary,
    secondaryContainer: AppColors.primaryContainer,
    onSecondaryContainer: AppColors.primary,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.textMuted,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
    error: AppColors.danger,
  );

  final controlShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control));
  const buttonSize = Size(48, 48);
  const buttonText = TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w600);

  return ThemeData(
    fontFamily: fontFamily,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 32, height: 40 / 32, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      titleLarge: TextStyle(fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400),
      labelLarge: TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500),
      bodySmall: TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500),
    ).apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primaryContainer,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.textMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) =>
            IconThemeData(color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.textMuted),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primaryContainer,
      side: const BorderSide(color: AppColors.border),
      labelStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, color: AppColors.text),
      shape: const StadiumBorder(),
      showCheckmark: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: buttonSize, shape: controlShape, textStyle: buttonText),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        shape: controlShape,
        textStyle: buttonText,
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: buttonSize, shape: controlShape, textStyle: buttonText),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    ),
  );
}
