import 'package:flutter/painting.dart';

/// Raw design tokens from the D2 Armory brand handover
/// (doc/design/d2-armory-brand-handover.html). Kept 1:1 with the handover's
/// `:root` block so the two stay diff-able.
///
/// Rarity and weapon-element colors are game-derived domain lookups and live
/// in `core/destiny/`; they are deliberately not duplicated here.
abstract final class ArmoryPalette {
  // Surfaces — elevation ramp, darkest to lightest.
  static const surface0 = Color(0xFF0D1013); // page canvas / window frame
  static const surface1 = Color(0xFF12161B); // base app background
  static const surface2 = Color(0xFF1C232B); // raised card / panel
  static const surface3 = Color(0xFF232B34); // elevated panel / popover
  static const surface4 = Color(0xFF2E3742); // hover state on surface-3

  // Borders.
  static const border = Color(0xFF2A323B); // default hairline
  static const borderStrong = Color(0xFF3A4552); // emphasized divider
  static const borderStronger = Color(0xFF5A6672); // heavy divider / active

  // Text.
  static const textPrimary = Color(0xFFECEFF2);
  static const textSecondary = Color(0xFF8A95A1);
  static const textMuted = Color(0xFF5A6672);
  static const textDisabled = Color(0xFF3A4552);

  // Accent — vault bronze.
  static const accent50 = Color(0xFFF7E9D6);
  static const accent200 = Color(0xFFE0A355); // hover on accent-500
  static const accent500 = Color(0xFFC98A3C); // brand primary
  static const accent600 = Color(0xFFB3742C); // pressed
  static const accent800 = Color(0xFF6B4419);
  static const onAccent = Color(0xFF1C130A); // text/icon on accent-500 fill

  // Semantic.
  static const success = Color(0xFF4CAF6D);
  static const successBg = Color(0xFF1C2B21);
  static const danger = Color(0xFFD1453B);
  static const dangerBg = Color(0xFF2B1C1C);
  static const warning = Color(0xFFD1A13C);
  static const warningBg = Color(0xFF2B2416);
  static const info = Color(0xFF4A90C9);
  static const infoBg = Color(0xFF1A232B);

  /// Surface-3 at ~94% alpha — tooltip/popover chrome floating over item art.
  static const tooltipSurface = Color(0xF0232B34);

  // Scrim blacks layered over CDN art (item icons, emblems, screenshots);
  // deliberately pure black rather than a surface tone. Suffix = opacity %.
  static const scrim26 = Color(0x42000000);
  static const scrim35 = Color(0x59000000);
  static const scrim87 = Color(0xDD000000);

  // Domain colors: game meaning (masterwork tier, reduced stats), kept
  // visually distinct from the brand bronze.
  static const masterworkGold = Color(0xFFE5C15B);
  static const statPenaltyRed = Color(0xFFB84C43);

  /// The bar segment for a stat gain granted by an equipped weapon *mod*, kept
  /// visually distinct from the gold masterwork segment.
  static const statModBlue = Color(0xFF4A90C9);

  /// Gradient stops for the translucent gold wash on masterworked item tiles.
  static const masterworkGlow = Color(0x42E5C15B);
  static const masterworkGlowEnd = Color(0x00E5C15B);

  // Gear-tier diamond colours (the tile overlay): grey for tiers 1-3, purple at
  // tier 4, gold at tier 5 — matching the in-game / DIM display.
  static const tierDiamondGrey = Color(0xFFB9C0C9);
  static const tierDiamondPurple = Color(0xFF9C64E0);
  static const tierDiamondGold = Color(0xFFE5C15B);

  /// The diamond colour for a gear [tier] (1-5): grey up to 3, purple at 4,
  /// gold at 5.
  static Color tierDiamond(int tier) => tier >= 5
      ? tierDiamondGold
      : tier == 4
          ? tierDiamondPurple
          : tierDiamondGrey;
}

/// Font families bundled under assets/fonts/ (see pubspec.yaml).
abstract final class ArmoryFonts {
  static const display = 'Rajdhani';
  static const body = 'Inter';
  static const mono = 'JetBrains Mono';
}

/// Corner radius scale from the handover (sm 4 / md 8 / lg 12).
abstract final class ArmoryRadius {
  static const smRadius = Radius.circular(4);
  static const mdRadius = Radius.circular(8);
  static const lgRadius = Radius.circular(12);

  static const sm = BorderRadius.all(smRadius);
  static const md = BorderRadius.all(mdRadius);
  static const lg = BorderRadius.all(lgRadius);
}

/// Shadow scale from the handover (black at 40/45/50% alpha).
abstract final class ArmoryShadows {
  static const sm = [
    BoxShadow(color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 2),
  ];
  static const md = [
    BoxShadow(color: Color(0x73000000), offset: Offset(0, 4), blurRadius: 12),
  ];
  static const lg = [
    BoxShadow(color: Color(0x80000000), offset: Offset(0, 12), blurRadius: 32),
  ];
}
