import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Autumn accent palette on a clean dark/light base.
// Background stays near-black (dark) or clean white (light).
// Only the ACCENT colors carry autumn character.
// ─────────────────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  // ── Shared Autumn Accents (same in both modes) ──────────────────────────────
  static const Color accentOrange = Color(0xFFFF6B2B); // vibrant burnt orange
  static const Color accentGreen = Color(0xFF5FAF7A); // autumn sage green
  static const Color accentBlue = Color(0xFF4DA6B3); // muted teal
  static const Color accentGold = Color(0xFFFFA940); // harvest amber

  // Keep these as aliases for legacy code that still references the old names
  static const Color accentPrimary = accentOrange;
  static const Color accentSecondary = accentGreen;

  // ── Dark base ───────────────────────────────────────────────────────────────
  static const Color backgroundDark = Color(0xFF0F0F14); // near-black
  static const Color surfaceDark = Color(0xFF1A1A22); // solid dark card
  static const Color surfaceMid = Color(0xFF23232F); // elevated dark
  static const Color textMain = Color(0xFFF0F0F5); // near-white
  static const Color textMuted = Color(0xFF7A7A9A); // muted grey
  static const Color separator = Color(0xFF2A2A3A); // subtle line

  // ── Light base ──────────────────────────────────────────────────────────────
  static const Color bgLight = Color(0xFFF7F7FA); // off-white
  static const Color surfaceLight = Color(0xFFFFFFFF); // white cards
  static const Color surfaceMidL = Color(0xFFEEEEF4); // light elevated
  static const Color textMainL = Color(0xFF12121A); // near-black text
  static const Color textMutedL = Color(0xFF6A6A8A); // muted
  static const Color separatorL = Color(0xFFE0E0EC); // light divider

  // ── Dark Theme ─────────────────────────────────────────────────────────────
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: backgroundDark,
    primaryColor: accentOrange,
    colorScheme: const ColorScheme.dark(
      primary: accentOrange,
      secondary: accentGreen,
      tertiary: accentBlue,
      surface: surfaceDark,
      onSurface: textMain,
      onPrimary: Colors.white,
    ),
    cardColor: surfaceDark,
    dividerColor: separator,
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: textMain,
        fontWeight: FontWeight.bold,
        fontSize: 32,
      ),
      titleLarge: TextStyle(
        color: textMain,
        fontWeight: FontWeight.w600,
        fontSize: 22,
      ),
      bodyLarge: TextStyle(color: textMain, fontSize: 16),
      bodyMedium: TextStyle(color: textMuted, fontSize: 14),
    ),
    extensions: const [
      AppColors(
        bg: backgroundDark,
        surface: surfaceDark,
        surfaceMid: surfaceMid,
        primary: accentOrange,
        secondary: accentGreen,
        gold: accentGold,
        blue: accentBlue,
        text: textMain,
        muted: textMuted,
        sep: separator,
      ),
    ],
    useMaterial3: true,
  );

  // ── Light Theme ────────────────────────────────────────────────────────────
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: bgLight,
    primaryColor: accentOrange,
    colorScheme: const ColorScheme.light(
      primary: accentOrange,
      secondary: accentGreen,
      tertiary: accentBlue,
      surface: surfaceLight,
      onSurface: textMainL,
      onPrimary: Colors.white,
    ),
    cardColor: surfaceLight,
    dividerColor: separatorL,
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: textMainL,
        fontWeight: FontWeight.bold,
        fontSize: 32,
      ),
      titleLarge: TextStyle(
        color: textMainL,
        fontWeight: FontWeight.w600,
        fontSize: 22,
      ),
      bodyLarge: TextStyle(color: textMainL, fontSize: 16),
      bodyMedium: TextStyle(color: textMutedL, fontSize: 14),
    ),
    extensions: const [
      AppColors(
        bg: bgLight,
        surface: surfaceLight,
        surfaceMid: surfaceMidL,
        primary: accentOrange,
        secondary: accentGreen,
        gold: accentGold,
        blue: accentBlue,
        text: textMainL,
        muted: textMutedL,
        sep: separatorL,
      ),
    ],
    useMaterial3: true,
  );
}

// ── ThemeExtension: the single source of truth for any widget ─────────────────
class AppColors extends ThemeExtension<AppColors> {
  final Color bg, surface, surfaceMid;
  final Color primary, secondary, gold, blue;
  final Color text, muted, sep;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceMid,
    required this.primary,
    required this.secondary,
    required this.gold,
    required this.blue,
    required this.text,
    required this.muted,
    required this.sep,
  });

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ??
      const AppColors(
        bg: AppTheme.backgroundDark,
        surface: AppTheme.surfaceDark,
        surfaceMid: AppTheme.surfaceMid,
        primary: AppTheme.accentOrange,
        secondary: AppTheme.accentGreen,
        gold: AppTheme.accentGold,
        blue: AppTheme.accentBlue,
        text: AppTheme.textMain,
        muted: AppTheme.textMuted,
        sep: AppTheme.separator,
      );

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceMid,
    Color? primary,
    Color? secondary,
    Color? gold,
    Color? blue,
    Color? text,
    Color? muted,
    Color? sep,
  }) => AppColors(
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    surfaceMid: surfaceMid ?? this.surfaceMid,
    primary: primary ?? this.primary,
    secondary: secondary ?? this.secondary,
    gold: gold ?? this.gold,
    blue: blue ?? this.blue,
    text: text ?? this.text,
    muted: muted ?? this.muted,
    sep: sep ?? this.sep,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMid: Color.lerp(surfaceMid, other.surfaceMid, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      blue: Color.lerp(blue, other.blue, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      sep: Color.lerp(sep, other.sep, t)!,
    );
  }
}
