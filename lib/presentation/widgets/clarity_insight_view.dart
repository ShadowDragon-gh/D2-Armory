import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/destiny/destiny_buckets.dart';
import '../../domain/models/clarity_insight.dart';
import '../providers/clarity_provider.dart';
import '../theme/armory_palette.dart';
import 'class_emblem.dart';

/// Community-insight rendering (Clarity), shared by every surface that shows
/// a plug's effect:
///
/// - [ClarityInsightText] renders the structured insight document.
/// - [ClarityInsightExpander] is the inline "Community Insight" toggle used in
///   list rows (detail panel, intrinsic/catalyst sections); it renders nothing
///   when Clarity has no entry for the hash, so uncovered rows are untouched.
/// - [ClarityAttribution] is the credit footer for surfaces that render
///   insight text directly (the gear modal's Community Insights panel).
///
/// Attribution: Clarity requires crediting them as the (external) source and
/// linking https://d2clarity.com plus their Discord near the insights — the
/// expander footer and [ClarityAttribution] carry this.

const _clarityUrl = 'https://d2clarity.com';
const _clarityDiscordUrl = 'https://d2clarity.com/discord';

/// The insight document: one block per [ClarityLine], `spacer` lines as gaps,
/// inline spans styled by their Clarity classNames (damage types, ammo,
/// champions, bold, links). Icon-only marker spans render the game's icons —
/// element glyphs and champion icons from the manifest, ammo and class marks
/// from local vectors — falling back to the marker's colored word when no
/// icon is available.
class ClarityInsightText extends ConsumerWidget {
  const ClarityInsightText({super.key, required this.lines, this.fontSize = 12});

  final List<ClarityLine> lines;
  final double fontSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final markerIcons = ref.watch(clarityMarkerIconsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          if (line.isSpacer)
            SizedBox(height: fontSize * 0.6)
          else if (line.content.isNotEmpty)
            Text.rich(
              TextSpan(
                children: [
                  for (var i = 0; i < line.content.length; i++)
                    _inlineSpan(
                      line.content[i],
                      nextText: i + 1 < line.content.length
                          ? line.content[i + 1].text
                          : '',
                      markerIcons: markerIcons,
                    ),
                ],
              ),
              style: TextStyle(
                fontSize: fontSize,
                height: 1.35,
                // `bold` can sit on the line as well as on a span.
                fontWeight:
                    line.classNames.contains('bold') ? FontWeight.w600 : null,
                color: ArmoryPalette.textPrimary.withValues(alpha: 0.85),
              ),
            ),
      ],
    );
  }

  InlineSpan _inlineSpan(
    ClaritySpan span, {
    required String nextText,
    required Map<String, String> markerIcons,
  }) {
    final text = span.text;
    if (text.isEmpty) return _markerSpan(span.classNames, nextText, markerIcons);

    final link = span.link;
    if (link != null && _isAllowedLink(link)) {
      // Links via WidgetSpan + GestureDetector: TextSpan tap recognizers need
      // explicit lifecycle management a build method cannot provide.
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: _LinkText(text: text, url: link, fontSize: fontSize),
      );
    }

    final color = _colorOf(span.classNames);
    final bold = span.classNames.contains('bold');
    return TextSpan(
      text: text,
      style: (color != null || bold)
          ? TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.w600 : null,
            )
          : null,
    );
  }

  /// An icon-only marker span (no text; meaning carried by classNames):
  /// class marks and ammo pips render from local vectors, element glyphs and
  /// champion icons from their manifest art (tinted for elements), and
  /// `enhancedArrow` stays the gold arrow the app uses for enhanced traits.
  /// Markers with no icon available render as their colored word instead.
  InlineSpan _markerSpan(
      List<String> classNames, String nextText, Map<String, String> icons) {
    final name = _markerClassOf(classNames);
    if (name == null) return const TextSpan();
    if (name == 'enhancedArrow') {
      return const TextSpan(
          text: '▲', style: TextStyle(color: ArmoryPalette.masterworkGold));
    }

    final size = fontSize + 3;
    Widget? icon;
    final classType = _classTypeByClassName[name];
    if (classType != null) {
      icon = ClassEmblem(classType: classType, size: size);
    }
    final ammoSvg = _ammoSvgByClassName[name];
    if (ammoSvg != null) {
      // The ammo art is wider than tall (a 1434×1024 viewBox).
      icon = SvgPicture.string(ammoSvg, width: size * 1.4, height: size);
    }
    final url = icons[name];
    if (icon == null && url != null) {
      final damageType = kClarityDamageTypeByClassName[name];
      final tint = damageType == null ? null : DamageType.color(damageType);
      icon = CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        color: tint,
        colorBlendMode: tint == null ? null : BlendMode.srcIn,
        errorWidget: (_, _, _) => _markerWordWidget(name, nextText),
      );
    }
    if (icon == null) return _markerWordSpan(name, nextText);
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.only(right: 3),
        child: icon,
      ),
    );
  }

  /// The colored-word stand-in for a marker with no icon (manifest not open,
  /// or its image failed to load). The data often already spells the word
  /// right after the marker (`<primary icon>Primary weapons`), so the word is
  /// emitted only when the following text does not repeat it, with a
  /// separating space when the text runs straight on
  /// (`<stasis icon>40 Slow` → "Stasis 40 Slow").
  TextSpan _markerWordSpan(String name, String nextText) {
    if (nextText.trimLeft().toLowerCase().startsWith(name.toLowerCase())) {
      return const TextSpan();
    }
    final word = name[0].toUpperCase() + name.substring(1);
    final needsSpace = nextText.isNotEmpty && !nextText.startsWith(' ');
    return TextSpan(
      text: needsSpace ? '$word ' : word,
      style: TextStyle(color: _colorOf([name])),
    );
  }

  Widget _markerWordWidget(String name, String nextText) {
    final text = _markerWordSpan(name, nextText).text;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Text(text,
        style: TextStyle(
            fontSize: fontSize, height: 1.35, color: _colorOf([name])));
  }

  /// The first recognized marker className, or null for an unknown marker.
  static String? _markerClassOf(List<String> classNames) {
    for (final name in classNames) {
      if (name == 'enhancedArrow' ||
          kClarityDamageTypeByClassName.containsKey(name) ||
          kClarityChampionByClassName.containsKey(name) ||
          _classTypeByClassName.containsKey(name) ||
          _ammoSvgByClassName.containsKey(name)) {
        return name;
      }
    }
    return null;
  }

  static Color? _colorOf(List<String> classNames) {
    for (final name in classNames) {
      if (name == 'enhancedArrow') return ArmoryPalette.masterworkGold;
      final damageType = kClarityDamageTypeByClassName[name];
      if (damageType != null) return DamageType.color(damageType);
      final accent = _accentByClassName[name];
      if (accent != null) return accent;
    }
    return null;
  }

  /// Ammo word-fallback tints, matching the in-game ammo colors.
  static const _accentByClassName = {
    'primary': ArmoryPalette.textPrimary,
    'special': ArmoryPalette.success,
    'heavy': ArmoryPalette.tierDiamondPurple,
  };

  /// Clarity className → DestinyClass, drawn with the app's [ClassEmblem].
  static const _classTypeByClassName = {
    'titan': 0,
    'hunter': 1,
    'warlock': 2,
  };

  /// Ammo pip glyphs from the community destiny-icons set (CC0 / public
  /// domain), embedded like the TunedStat glyph — the manifest has no ammo
  /// icon definitions. Colors are baked in to match the in-game pips.
  static const _ammoSvgByClassName = {
    'primary': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1434 1024">'
        '<path fill="#ffffff" d="M716.8 243.2c38.4 0 89.6 128 89.6 179.2h-179.2c0-51.2 51.2-179.2 89.6-179.2z"/>'
        '<path fill="#ffffff" d="M627.2 473.6h179.2v294.4h-179.2v-294.4z"/>'
        '<path fill="#ffffff" d="M179.2 1024l-179.2-179.2v-665.6l179.2-179.2h1075.2l179.2 179.2v665.6l-179.2 179.2zM230.4 896h972.8l102.4-102.4v-563.2l-102.4-102.4h-972.8l-102.4 102.4v563.2z"/>'
        '</svg>',
    'special': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1434 1024">'
        '<path fill="#7af48b" d="M588.8 243.2c38.4 0 89.6 128 89.6 179.2h-179.2c0-51.2 51.2-179.2 89.6-179.2z"/>'
        '<path fill="#7af48b" d="M499.2 473.6h179.2v294.4h-179.2v-294.4z"/>'
        '<path fill="#7af48b" d="M844.8 243.2c38.4 0 89.6 128 89.6 179.2h-179.2c0-51.2 51.2-179.2 89.6-179.2z"/>'
        '<path fill="#7af48b" d="M755.2 473.6h179.2v294.4h-179.2v-294.4z"/>'
        '<path fill="#7af48b" d="M179.2 1024l-179.2-179.2v-665.6l179.2-179.2h1075.2l179.2 179.2v665.6l-179.2 179.2zM230.4 896h972.8l102.4-102.4v-563.2l-102.4-102.4h-972.8l-102.4 102.4v563.2z"/>'
        '</svg>',
    'heavy': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1434 1024">'
        '<path fill="#b286ff" d="M460.8 243.2c38.4 0 89.6 128 89.6 179.2h-179.2c0-51.2 51.2-179.2 89.6-179.2z"/>'
        '<path fill="#b286ff" d="M716.8 243.2c38.4 0 89.6 128 89.6 179.2h-179.2c0-51.2 51.2-179.2 89.6-179.2z"/>'
        '<path fill="#b286ff" d="M972.8 243.2c38.4 0 89.6 128 89.6 179.2h-179.2c0-51.2 51.2-179.2 89.6-179.2z"/>'
        '<path fill="#b286ff" d="M371.2 473.6h179.2v294.4h-179.2v-294.4z"/>'
        '<path fill="#b286ff" d="M627.2 473.6h179.2v294.4h-179.2v-294.4z"/>'
        '<path fill="#b286ff" d="M883.2 473.6h179.2v294.4h-179.2v-294.4z"/>'
        '<path fill="#b286ff" d="M179.2 1024l-179.2-179.2v-665.6l179.2-179.2h1075.2l179.2 179.2v665.6l-179.2 179.2zM230.4 896h972.8l102.4-102.4v-563.2l-102.4-102.4h-972.8l-102.4 102.4v563.2z"/>'
        '</svg>',
  };
}

/// The data is community-authored: only http(s) URLs may become tappable.
bool _isAllowedLink(String url) {
  final uri = Uri.tryParse(url);
  return uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
}

class _LinkText extends StatelessWidget {
  const _LinkText({required this.text, required this.url, required this.fontSize});

  final String text;
  final String url;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse(url)),
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            height: 1.35,
            color: ArmoryPalette.info,
            decoration: TextDecoration.underline,
            decorationColor: ArmoryPalette.info,
          ),
        ),
      ),
    );
  }
}

/// The expandable inline "Community Insight" control for list rows: collapsed
/// it is a single subtle toggle line; expanded it reveals the formatted
/// insight and the Clarity attribution footer. Renders nothing when Clarity
/// has no entry for [hash], leaving uncovered rows exactly as before.
class ClarityInsightExpander extends ConsumerStatefulWidget {
  const ClarityInsightExpander({super.key, required this.hash});

  final int hash;

  @override
  ConsumerState<ClarityInsightExpander> createState() =>
      _ClarityInsightExpanderState();
}

class _ClarityInsightExpanderState
    extends ConsumerState<ClarityInsightExpander> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final insight = ref.watch(clarityInsightProvider(widget.hash));
    if (insight == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _expanded
                        ? Icons.arrow_drop_down
                        : Icons.arrow_right,
                    size: 16,
                    color: ArmoryPalette.accent500,
                  ),
                  Text(
                    'Community Insight',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 2, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClarityInsightText(lines: insight.lines, fontSize: 11),
                const SizedBox(height: 6),
                const ClarityAttribution(),
              ],
            ),
          ),
      ],
    );
  }
}

/// The attribution footer Clarity's terms require: names them as the external
/// source and links their site and Discord (the feedback path).
class ClarityAttribution extends StatelessWidget {
  const ClarityAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 10, color: ArmoryPalette.textMuted);
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Courtesy of '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _LinkText(text: 'Clarity', url: _clarityUrl, fontSize: 10),
          ),
          const TextSpan(text: ' — inaccuracies? '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _LinkText(
                text: 'Clarity Discord',
                url: _clarityDiscordUrl,
                fontSize: 10),
          ),
        ],
      ),
      style: style,
    );
  }
}

