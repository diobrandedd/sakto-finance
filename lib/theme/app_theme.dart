import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const background = Color(0xFFF2F1ED);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A1A1E);
  static const muted = Color(0xFF8C8C96);
  static const border = Color(0xFFE4E3DF);
  static const accent = Color(0xFF0E9E94);
  static const accentLight = Color(0xFFE6F7F6);
  static const green = Color(0xFF16A34A);
  static const greenLight = Color(0xFFDCFCE7);
  static const red = Color(0xFFDC2626);
  static const redLight = Color(0xFFFEE2E2);
  static const amber = Color(0xFFD97706);
  static const amberLight = Color(0xFFFEF3C7);
  static const blue = Color(0xFF3B82F6);
  static const purple = Color(0xFF9333EA);
  static const coral = Color(0xFFF97316);
  static const pink = Color(0xFFEC4899);

  static const accountPalette = [blue, green, purple, coral, accent, pink];
}

@immutable
class SaktoColors extends ThemeExtension<SaktoColors> {
  const SaktoColors({
    required this.background,
    required this.surface,
    required this.text,
    required this.muted,
    required this.border,
    required this.accent,
    required this.accentLight,
  });

  final Color background;
  final Color surface;
  final Color text;
  final Color muted;
  final Color border;
  final Color accent;
  final Color accentLight;

  static const light = SaktoColors(
    background: AppColors.background,
    surface: AppColors.surface,
    text: AppColors.text,
    muted: AppColors.muted,
    border: AppColors.border,
    accent: AppColors.accent,
    accentLight: AppColors.accentLight,
  );

  bool get isDark => background.computeLuminance() < 0.45;

  @override
  SaktoColors copyWith({
    Color? background,
    Color? surface,
    Color? text,
    Color? muted,
    Color? border,
    Color? accent,
    Color? accentLight,
  }) => SaktoColors(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    text: text ?? this.text,
    muted: muted ?? this.muted,
    border: border ?? this.border,
    accent: accent ?? this.accent,
    accentLight: accentLight ?? this.accentLight,
  );

  @override
  SaktoColors lerp(ThemeExtension<SaktoColors>? other, double t) {
    if (other is! SaktoColors) return this;
    return SaktoColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentLight: Color.lerp(accentLight, other.accentLight, t)!,
    );
  }
}

extension SaktoThemeX on BuildContext {
  SaktoColors get sakto =>
      Theme.of(this).extension<SaktoColors>() ?? SaktoColors.light;
}

ThemeData buildAppTheme(
  SaktoColors colors, {
  bool transparentScaffold = false,
}) {
  final body = GoogleFonts.dmSansTextTheme();
  final display = GoogleFonts.outfitTextTheme();
  final brightness = colors.isDark ? Brightness.dark : Brightness.light;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: transparentScaffold
        ? Colors.transparent
        : colors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: colors.accent,
      brightness: brightness,
      primary: colors.accent,
      surface: colors.surface,
      error: AppColors.red,
    ),
    extensions: [colors],
    textTheme: body.copyWith(
      displayLarge: display.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: colors.text,
      ),
      displayMedium: display.displayMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: colors.text,
      ),
      headlineLarge: display.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: colors.text,
      ),
      headlineMedium: display.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: colors.text,
      ),
      titleLarge: body.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: colors.text,
      ),
      titleMedium: body.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: colors.text,
      ),
      bodyLarge: body.bodyLarge?.copyWith(color: colors.text),
      bodyMedium: body.bodyMedium?.copyWith(color: colors.text),
      bodySmall: body.bodySmall?.copyWith(color: colors.muted),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: transparentScaffold
          ? Colors.transparent
          : colors.background,
      foregroundColor: colors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surface,
      indicatorColor: colors.accentLight,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? colors.accent
              : colors.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? colors.accent
              : colors.muted,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: colors.surface.withValues(alpha: transparentScaffold ? 0.92 : 1),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: colors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: colors.accent, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: colors.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );
}

Color hexColor(String value) {
  final normalized = value.replaceAll('#', '');
  return Color(int.parse('FF$normalized', radix: 16));
}

String colorHex(Color color) =>
    '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
