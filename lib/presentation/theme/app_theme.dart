import 'package:flutter/material.dart';

import 'armory_palette.dart';
import 'armory_theme_extension.dart';

/// Builds the app-wide D2 Armory dark theme from the brand tokens in
/// [ArmoryPalette]. Token-to-slot mapping is documented in
/// doc/theme_implementation_plan.md.
ThemeData buildArmoryTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: ArmoryPalette.accent500,
    onPrimary: ArmoryPalette.onAccent,
    primaryContainer: ArmoryPalette.accent800,
    onPrimaryContainer: ArmoryPalette.accent50,
    secondary: ArmoryPalette.textSecondary,
    onSecondary: ArmoryPalette.surface0,
    secondaryContainer: ArmoryPalette.surface3,
    onSecondaryContainer: ArmoryPalette.textPrimary,
    tertiary: ArmoryPalette.info,
    onTertiary: ArmoryPalette.surface0,
    tertiaryContainer: ArmoryPalette.infoBg,
    onTertiaryContainer: ArmoryPalette.textPrimary,
    error: ArmoryPalette.danger,
    onError: ArmoryPalette.textPrimary,
    errorContainer: ArmoryPalette.dangerBg,
    onErrorContainer: ArmoryPalette.textPrimary,
    surface: ArmoryPalette.surface1,
    onSurface: ArmoryPalette.textPrimary,
    onSurfaceVariant: ArmoryPalette.textSecondary,
    surfaceDim: ArmoryPalette.surface0,
    surfaceBright: ArmoryPalette.surface4,
    surfaceContainerLowest: ArmoryPalette.surface0,
    surfaceContainerLow: ArmoryPalette.surface2,
    surfaceContainer: ArmoryPalette.surface2,
    surfaceContainerHigh: ArmoryPalette.surface3,
    surfaceContainerHighest: ArmoryPalette.surface4,
    outline: ArmoryPalette.borderStrong,
    outlineVariant: ArmoryPalette.border,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: ArmoryPalette.textPrimary,
    onInverseSurface: ArmoryPalette.surface1,
    inversePrimary: ArmoryPalette.accent800,
    // No M3 primary-tint wash on elevated surfaces — elevation comes from the
    // explicit surface ramp instead.
    surfaceTint: Color(0x00000000),
  );

  // Display/headline/title slots use Rajdhani; body and label slots inherit
  // Inter from ThemeData(fontFamily:). This partial theme is merged over the
  // default dark TextTheme, so sizes stay Material-standard unless set here.
  const textTheme = TextTheme(
    displayLarge: TextStyle(
        fontFamily: ArmoryFonts.display,
        fontWeight: FontWeight.w700,
        letterSpacing: 1),
    displayMedium: TextStyle(
        fontFamily: ArmoryFonts.display,
        fontWeight: FontWeight.w700,
        letterSpacing: 1),
    displaySmall: TextStyle(
        fontFamily: ArmoryFonts.display,
        fontWeight: FontWeight.w700,
        letterSpacing: 1),
    headlineLarge: TextStyle(
        fontFamily: ArmoryFonts.display,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5),
    headlineMedium: TextStyle(
        fontFamily: ArmoryFonts.display,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5),
    headlineSmall: TextStyle(
        fontFamily: ArmoryFonts.display,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5),
    titleLarge: TextStyle(
        fontFamily: ArmoryFonts.display,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5),
    titleMedium: TextStyle(
        fontFamily: ArmoryFonts.display,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4),
    titleSmall: TextStyle(
        fontFamily: ArmoryFonts.display,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3),
    // Shared uppercase section-label style (callers uppercase the text).
    labelSmall:
        TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
  );

  // The handover's accent interaction states: hover accent-200, pressed
  // accent-600, resting accent-500.
  final accentButtonStyle = ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return ArmoryPalette.surface3;
      if (states.contains(WidgetState.pressed)) return ArmoryPalette.accent600;
      if (states.contains(WidgetState.hovered)) return ArmoryPalette.accent200;
      return ArmoryPalette.accent500;
    }),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? ArmoryPalette.textDisabled
          : ArmoryPalette.onAccent,
    ),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(0),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: ArmoryRadius.md),
    ),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: ArmoryFonts.body,
    textTheme: textTheme,
    scaffoldBackgroundColor: ArmoryPalette.surface1,
    iconTheme: const IconThemeData(color: ArmoryPalette.textPrimary),
    appBarTheme: const AppBarTheme(
      backgroundColor: ArmoryPalette.surface1,
      foregroundColor: ArmoryPalette.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: ArmoryFonts.display,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
        color: ArmoryPalette.textPrimary,
      ),
    ),
    cardTheme: const CardThemeData(
      color: ArmoryPalette.surface2,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: ArmoryRadius.lg,
        side: BorderSide(color: ArmoryPalette.border),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: ArmoryPalette.surface3,
      shape: RoundedRectangleBorder(borderRadius: ArmoryRadius.lg),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: ArmoryPalette.tooltipSurface,
        borderRadius: ArmoryRadius.sm,
        border: Border.all(color: ArmoryPalette.borderStrong),
      ),
      textStyle: const TextStyle(
        fontFamily: ArmoryFonts.body,
        fontSize: 12,
        color: ArmoryPalette.textPrimary,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(style: accentButtonStyle),
    elevatedButtonTheme: ElevatedButtonThemeData(style: accentButtonStyle),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: ArmoryPalette.accent500),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ArmoryPalette.accent500,
        side: const BorderSide(color: ArmoryPalette.borderStrong),
        shape: const RoundedRectangleBorder(borderRadius: ArmoryRadius.md),
      ),
    ),
    inputDecorationTheme: const InputDecorationThemeData(
      filled: true,
      fillColor: ArmoryPalette.surface2,
      hintStyle: TextStyle(color: ArmoryPalette.textMuted),
      border: OutlineInputBorder(
        borderRadius: ArmoryRadius.md,
        borderSide: BorderSide(color: ArmoryPalette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: ArmoryRadius.md,
        borderSide: BorderSide(color: ArmoryPalette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: ArmoryRadius.md,
        borderSide: BorderSide(color: ArmoryPalette.accent500, width: 1.5),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: ArmoryPalette.border,
      thickness: 1,
    ),
    scrollbarTheme: const ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(ArmoryPalette.borderStronger),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: ArmoryPalette.surface3,
      contentTextStyle: TextStyle(
        fontFamily: ArmoryFonts.body,
        color: ArmoryPalette.textPrimary,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: ArmoryRadius.md),
    ),
    extensions: const [ArmoryColors.dark],
  );
}
