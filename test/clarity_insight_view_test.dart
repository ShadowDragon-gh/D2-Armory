import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:d2_armory/core/config/app_config.dart';
import 'package:d2_armory/core/destiny/destiny_buckets.dart';
import 'package:d2_armory/data/local/clarity_store.dart';
import 'package:d2_armory/data/repositories/manifest_repository.dart';
import 'package:d2_armory/domain/models/clarity_insight.dart';
import 'package:d2_armory/presentation/providers/clarity_provider.dart';
import 'package:d2_armory/presentation/providers/manifest_provider.dart';
import 'package:d2_armory/presentation/widgets/clarity_insight_view.dart';
import 'package:d2_armory/presentation/widgets/class_emblem.dart';

class _MockManifestRepository extends Mock implements ManifestRepository {}

/// The expandable "Community Insight" row: shown only for covered hashes,
/// revealing the formatted Clarity text and the required attribution when
/// expanded — and rendering nothing at all for uncovered hashes. Icon-only
/// markers render game icons (manifest art / local vectors), falling back to
/// their colored word when the manifest is not open.
void main() {
  const coveredHash = 75282108; // Weighted Edge (Winterbite)
  late Map<int, ClarityInsight> insights;
  late _MockManifestRepository manifest;

  setUpAll(() {
    insights = parseClarityFile('test/fixtures/clarity_sample.json');
  });

  setUp(() {
    // Default: manifest not open → element/champion markers use the word
    // fallback (ammo and class markers always render local vectors).
    manifest = _MockManifestRepository();
    when(() => manifest.databasePath).thenReturn(null);
  });

  Widget harness(Widget child) => ProviderScope(
        overrides: [
          clarityInsightProvider.overrideWith((ref, h) => insights[h]),
          manifestRepositoryProvider.overrideWithValue(manifest),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      );

  testWidgets('covered hash shows the toggle; tap reveals text + attribution',
      (tester) async {
    await tester.pumpWidget(harness(
        const ClarityInsightExpander(hash: coveredHash)));

    expect(find.text('Community Insight'), findsOneWidget);
    // Collapsed: the insight body is not built yet.
    expect(find.textContaining('Glaive Melee Attacks', findRichText: true),
        findsNothing);

    await tester.tap(find.text('Community Insight'));
    await tester.pump();

    expect(find.textContaining('Glaive Melee Attacks', findRichText: true),
        findsOneWidget);
    // Attribution (required by Clarity's terms): source + feedback links.
    expect(find.text('Clarity'), findsOneWidget);
    expect(find.text('Clarity Discord'), findsOneWidget);

    // Toggling again collapses it.
    await tester.tap(find.text('Community Insight'));
    await tester.pump();
    expect(find.textContaining('Glaive Melee Attacks', findRichText: true),
        findsNothing);
  });

  testWidgets('uncovered hash renders nothing', (tester) async {
    await tester.pumpWidget(harness(const ClarityInsightExpander(hash: 12345)));

    expect(find.text('Community Insight'), findsNothing);
    expect(
      find.descendant(
          of: find.byType(ClarityInsightExpander),
          matching: find.byType(SizedBox)),
      findsOneWidget,
    );
  });

  testWidgets(
      'without the manifest, ammo markers render local vectors and element '
      'markers fall back to deduped, spaced words', (tester) async {
    // Mirrors two real data shapes: "<primary marker>Primary weapons" (the
    // word already follows the marker — the local ammo icon renders and the
    // word is not doubled) and "<stasis marker>40 Slow" (no icon without the
    // manifest → the word is inserted with a separating space).
    const lines = [
      ClarityLine(content: [
        ClaritySpan(text: '10% on '),
        ClaritySpan(classNames: ['primary']),
        ClaritySpan(text: 'Primary weapons'),
      ]),
      ClarityLine(content: [
        ClaritySpan(text: 'apply '),
        ClaritySpan(classNames: ['stasis']),
        ClaritySpan(text: '40 Slow'),
      ]),
    ];
    await tester.pumpWidget(harness(const ClarityInsightText(lines: lines)));

    expect(find.byType(SvgPicture), findsOneWidget); // the primary ammo pips
    expect(find.textContaining('PrimaryPrimary', findRichText: true),
        findsNothing);
    expect(find.textContaining('Primary weapons', findRichText: true),
        findsOneWidget);
    expect(find.textContaining('apply Stasis 40 Slow', findRichText: true),
        findsOneWidget);
  });

  testWidgets('markers render manifest icons when the manifest is open',
      (tester) async {
    when(() => manifest.databasePath).thenReturn('/x');
    when(() => manifest.allDamageTypes()).thenReturn([
      {'enumValue': 6, 'transparentIconPath': '/img/stasis_trans.png'},
    ]);
    when(() => manifest.allBreakerTypes()).thenReturn([
      {
        'enumValue': 1,
        'displayProperties': {'icon': '/img/barrier.png'},
      },
    ]);
    const lines = [
      ClarityLine(content: [
        ClaritySpan(text: 'apply '),
        ClaritySpan(classNames: ['stasis']),
        ClaritySpan(text: '40 Slow, stuns '),
        ClaritySpan(classNames: ['barrier']),
        ClaritySpan(text: 'Champions, for '),
        ClaritySpan(classNames: ['hunter']),
        ClaritySpan(text: 'Hunters'),
      ]),
    ];
    await tester.pumpWidget(harness(const ClarityInsightText(lines: lines)));

    final images = tester
        .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
        .toList();
    expect(images.map((w) => w.imageUrl), [
      '${AppConfig.bungieBaseUrl}/img/stasis_trans.png',
      '${AppConfig.bungieBaseUrl}/img/barrier.png',
    ]);
    // Element glyphs are tinted with their damage color; champions untinted.
    expect(images[0].color, DamageType.color(6));
    expect(images[1].color, isNull);
    expect(find.byType(ClassEmblem), findsOneWidget);
    // The icons replace the fallback words.
    expect(
        find.textContaining('Stasis', findRichText: true), findsNothing);
  });

}
