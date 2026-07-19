import 'package:flutter_test/flutter_test.dart';

import 'package:d2_armory/data/local/clarity_store.dart';
import 'package:d2_armory/domain/models/clarity_insight.dart';

/// Parsing tests against a verbatim sample of Clarity's live `dim.json`
/// (test/fixtures/clarity_sample.json): Winterbite's Weighted Edge (stasis
/// markers, spacer, link), Box Breathing (enhancedArrow + ammo markers), and
/// One Thousand Voices' catalyst (champion marker, line-level bold).
void main() {
  late Map<int, ClarityInsight> insights;

  setUpAll(() {
    insights = parseClarityFile('test/fixtures/clarity_sample.json');
  });

  test('parses every fixture entry keyed by its inventory-item hash', () {
    expect(insights.length, 3);
    expect(insights.keys,
        containsAll([75282108, 23371658, 82994288]));
  });

  test('Weighted Edge parses into the expected span structure', () {
    final insight = insights[75282108]!;
    expect(insight.name, 'Weighted Edge');
    expect(insight.lines, hasLength(3));

    // Line 0: text spans interleaved with icon-only stasis markers.
    final first = insight.lines[0];
    expect(first.isSpacer, isFalse);
    expect(first.content.first.text, startsWith('When the magazine'));
    final stasisMarkers = first.content
        .where((s) => s.classNames.contains('stasis'))
        .toList();
    expect(stasisMarkers, hasLength(2));
    expect(stasisMarkers.first.text, isEmpty);

    // Line 1: a spacer divider with no content.
    expect(insight.lines[1].isSpacer, isTrue);
    expect(insight.lines[1].content, isEmpty);

    // Line 2: a link span followed by plain text.
    final linkSpan = insight.lines[2].content.first;
    expect(linkSpan.text, 'Bosses');
    expect(linkSpan.link, 'https://url.d2clarity.com/combatants');
  });

  test('Box Breathing carries enhancedArrow and ammo markers', () {
    final insight = insights[23371658]!;
    final allSpans = [for (final l in insight.lines) ...l.content];
    expect(allSpans.any((s) => s.classNames.contains('enhancedArrow')), isTrue);
    expect(allSpans.any((s) => s.classNames.contains('primary')), isTrue);
    expect(allSpans.any((s) => s.classNames.contains('heavy')), isTrue);
  });

  test('catalyst entry parses with line-level bold', () {
    final insight = insights[82994288]!;
    expect(insight.name, 'One Thousand Voices Catalyst');
    expect(insight.lines.any((l) => l.classNames.contains('bold')), isTrue);
  });

  test('entries without a usable description parse to null', () {
    expect(ClarityInsight.fromJson({'hash': 1}), isNull);
    expect(ClarityInsight.fromJson({'hash': 1, 'descriptions': {}}), isNull);
    expect(
        ClarityInsight.fromJson({
          'hash': 1,
          'descriptions': {'en': []},
        }),
        isNull);
    expect(ClarityInsight.fromJson({'descriptions': {'en': []}}), isNull);
  });

  test('falls back to the first available language when en is absent', () {
    final insight = ClarityInsight.fromJson({
      'hash': 42,
      'name': 'Nur auf Deutsch',
      'descriptions': {
        'de': [
          {
            'linesContent': [
              {'text': 'Hallo'},
            ],
          },
        ],
      },
    });
    expect(insight, isNotNull);
    expect(insight!.lines.single.content.single.text, 'Hallo');
  });
}
