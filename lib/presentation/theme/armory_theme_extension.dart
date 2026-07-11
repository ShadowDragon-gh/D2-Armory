import 'package:flutter/material.dart';

import 'armory_palette.dart';

/// Brand tokens that have no [ColorScheme] slot.
///
/// Access via `context.armory` (see [ArmoryThemeX]) or
/// `Theme.of(context).extension<ArmoryColors>()!`.
@immutable
class ArmoryColors extends ThemeExtension<ArmoryColors> {
  const ArmoryColors({
    required this.borderStronger,
    required this.textMuted,
    required this.textDisabled,
    required this.accent50,
    required this.accent200,
    required this.accent600,
    required this.accent800,
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
    required this.info,
    required this.infoBg,
    required this.tooltipSurface,
    required this.masterworkGold,
    required this.statPenaltyRed,
  });

  final Color borderStronger;
  final Color textMuted;
  final Color textDisabled;
  final Color accent50;
  final Color accent200;
  final Color accent600;
  final Color accent800;
  final Color success;
  final Color successBg;
  final Color warning;
  final Color warningBg;
  final Color info;
  final Color infoBg;
  final Color tooltipSurface;
  final Color masterworkGold;
  final Color statPenaltyRed;

  static const dark = ArmoryColors(
    borderStronger: ArmoryPalette.borderStronger,
    textMuted: ArmoryPalette.textMuted,
    textDisabled: ArmoryPalette.textDisabled,
    accent50: ArmoryPalette.accent50,
    accent200: ArmoryPalette.accent200,
    accent600: ArmoryPalette.accent600,
    accent800: ArmoryPalette.accent800,
    success: ArmoryPalette.success,
    successBg: ArmoryPalette.successBg,
    warning: ArmoryPalette.warning,
    warningBg: ArmoryPalette.warningBg,
    info: ArmoryPalette.info,
    infoBg: ArmoryPalette.infoBg,
    tooltipSurface: ArmoryPalette.tooltipSurface,
    masterworkGold: ArmoryPalette.masterworkGold,
    statPenaltyRed: ArmoryPalette.statPenaltyRed,
  );

  @override
  ArmoryColors copyWith({
    Color? borderStronger,
    Color? textMuted,
    Color? textDisabled,
    Color? accent50,
    Color? accent200,
    Color? accent600,
    Color? accent800,
    Color? success,
    Color? successBg,
    Color? warning,
    Color? warningBg,
    Color? info,
    Color? infoBg,
    Color? tooltipSurface,
    Color? masterworkGold,
    Color? statPenaltyRed,
  }) {
    return ArmoryColors(
      borderStronger: borderStronger ?? this.borderStronger,
      textMuted: textMuted ?? this.textMuted,
      textDisabled: textDisabled ?? this.textDisabled,
      accent50: accent50 ?? this.accent50,
      accent200: accent200 ?? this.accent200,
      accent600: accent600 ?? this.accent600,
      accent800: accent800 ?? this.accent800,
      success: success ?? this.success,
      successBg: successBg ?? this.successBg,
      warning: warning ?? this.warning,
      warningBg: warningBg ?? this.warningBg,
      info: info ?? this.info,
      infoBg: infoBg ?? this.infoBg,
      tooltipSurface: tooltipSurface ?? this.tooltipSurface,
      masterworkGold: masterworkGold ?? this.masterworkGold,
      statPenaltyRed: statPenaltyRed ?? this.statPenaltyRed,
    );
  }

  @override
  ArmoryColors lerp(ThemeExtension<ArmoryColors>? other, double t) {
    if (other is! ArmoryColors) return this;
    return ArmoryColors(
      borderStronger: Color.lerp(borderStronger, other.borderStronger, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      accent50: Color.lerp(accent50, other.accent50, t)!,
      accent200: Color.lerp(accent200, other.accent200, t)!,
      accent600: Color.lerp(accent600, other.accent600, t)!,
      accent800: Color.lerp(accent800, other.accent800, t)!,
      success: Color.lerp(success, other.success, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoBg: Color.lerp(infoBg, other.infoBg, t)!,
      tooltipSurface: Color.lerp(tooltipSurface, other.tooltipSurface, t)!,
      masterworkGold: Color.lerp(masterworkGold, other.masterworkGold, t)!,
      statPenaltyRed: Color.lerp(statPenaltyRed, other.statPenaltyRed, t)!,
    );
  }
}

/// Shorthand for reading the brand tokens at a call site.
///
/// Falls back to [ArmoryColors.dark] (the only variant this single-theme app
/// registers) so widgets also work under minimal test-harness themes.
extension ArmoryThemeX on BuildContext {
  ArmoryColors get armory =>
      Theme.of(this).extension<ArmoryColors>() ?? ArmoryColors.dark;
}
