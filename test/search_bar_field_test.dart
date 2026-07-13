import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:d2_armory/core/search/search_suggestions.dart';
import 'package:d2_armory/presentation/widgets/search_bar_field.dart';

void main() {
  // Pumps the field, focuses it, and returns the last value onChanged emitted.
  Future<TextEditingController> pumpField(
    WidgetTester tester, {
    required void Function(String) onChanged,
    List<String> names = const [],
    bool instanceData = true,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SearchBarField(
          text: '',
          onChanged: onChanged,
          unsupported: const [],
          names: names,
          instanceData: instanceData,
        ),
      ),
    ));
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    return tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
  }

  testWidgets('typing a filter prefix opens the suggestion overlay',
      (tester) async {
    await pumpField(tester, onChanged: (_) {});
    await tester.enterText(find.byType(TextField), 'is:han');
    await tester.pumpAndSettle();
    expect(find.text('is:handcannon'), findsOneWidget);
  });

  testWidgets('Tab completes the highlighted (first) suggestion',
      (tester) async {
    var latest = '';
    final controller =
        await pumpField(tester, onChanged: (v) => latest = v);
    await tester.enterText(find.byType(TextField), 'is:han');
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    // The token was replaced by the completion + trailing space.
    expect(controller.text, 'is:handcannon ');
    expect(latest, 'is:handcannon ');
  });

  testWidgets('completing a filter key that needs a value adds no trailing '
      'space', (tester) async {
    var latest = '';
    final controller =
        await pumpField(tester, onChanged: (v) => latest = v);
    await tester.enterText(find.byType(TextField), 'nam');
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    // `name:` awaits a value — a trailing space would make the tokenizer read
    // it as a finished empty term and break the search, so none is added.
    expect(controller.text, 'name:');
    expect(latest, 'name:');
  });

  testWidgets('ArrowDown then Tab completes the second suggestion',
      (tester) async {
    final controller = await pumpField(tester, onChanged: (_) {});
    // 'is:s' matches several is: keywords (solar, shotgun, stasis, …), sorted
    // shortest-first, so there is more than one row to move through.
    await tester.enterText(find.byType(TextField), 'is:s');
    await tester.pumpAndSettle();

    // Capture the first two suggestion labels from the rendered overlay.
    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((s) => s.startsWith('is:'))
        .toList();
    expect(labels.length, greaterThan(1),
        reason: 'need >1 suggestion to test arrow movement');
    final second = labels[1];

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(controller.text, '$second ');
  });

  testWidgets('ArrowUp from the top wraps to the last suggestion',
      (tester) async {
    final controller = await pumpField(tester, onChanged: (_) {});
    await tester.enterText(find.byType(TextField), 'is:s');
    await tester.pumpAndSettle();

    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((s) => s.startsWith('is:'))
        .toList();
    final last = labels.last;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp); // 0 -> wrap to last
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(controller.text, '$last ');
  });

  testWidgets('Enter also completes the highlighted suggestion',
      (tester) async {
    final controller = await pumpField(tester, onChanged: (_) {});
    await tester.enterText(find.byType(TextField), 'is:han');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.text, 'is:handcannon ');
  });

  testWidgets(
      'a perk catalog that arrives after typing perk: surfaces the dropdown '
      'without another keystroke', (tester) async {
    final perksNotifier = ValueNotifier<List<PerkOption>>(const []);
    addTearDown(perksNotifier.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<List<PerkOption>>(
          valueListenable: perksNotifier,
          builder: (context, perks, _) => SearchBarField(
            text: '',
            onChanged: _noop,
            unsupported: const [],
            perks: perks,
          ),
        ),
      ),
    ));
    await tester.tap(find.byType(TextField));
    await tester.pump();

    // Catalog empty: typing perk: yields no suggestions.
    await tester.enterText(find.byType(TextField), 'perk:');
    await tester.pump();
    expect(find.text('perk:rampage'), findsNothing);

    // The background warm lands, populating the catalog. The field rebuilds
    // with the new perks and recomputes on the next frame — no keystroke.
    perksNotifier.value = const [PerkOption('rampage', '/i/rampage.png')];
    await tester.pump(); // rebuild with new perks
    await tester.pump(); // run the post-frame recompute
    expect(find.text('perk:rampage'), findsOneWidget);
  });

  testWidgets('typing perk: with a populated catalog shows perk suggestions',
      (tester) async {
    final perks = List.generate(
        200, (i) => PerkOption('perk name $i', '/common/icon$i.png'));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SearchBarField(
          text: '',
          onChanged: _noop,
          unsupported: const [],
          perks: perks,
        ),
      ),
    ));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'perk:');
    await tester.pump();

    // The overlay should be up with the alphabetical perk list.
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('perk:perk name 0'), findsOneWidget);
  });

  testWidgets('typing perk: one char at a time (provider-driven text) shows '
      'perks — the real integration path', (tester) async {
    final perks = [
      const PerkOption('rampage', '/i/r.png'),
      const PerkOption('adagio', '/i/a.png'),
    ];
    // Mirror the real screens: onChanged feeds back into `text`, and the parent
    // rebuilds the field with the new text each keystroke (as a provider does).
    var text = '';
    await tester.pumpWidget(StatefulBuilder(
      builder: (context, setState) => MaterialApp(
        home: Scaffold(
          body: SearchBarField(
            text: text,
            onChanged: (v) => setState(() => text = v),
            unsupported: const [],
            perks: perks,
          ),
        ),
      ),
    ));
    await tester.tap(find.byType(TextField));
    await tester.pump();

    for (final s in ['p', 'pe', 'per', 'perk', 'perk:']) {
      await tester.enterText(find.byType(TextField), s);
      await tester.pump();
    }
    expect(find.text('perk:rampage'), findsOneWidget);
    expect(find.text('perk:adagio'), findsOneWidget);
  });

  testWidgets('shows a warming spinner while facets are still loading',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SearchBarField(
          text: '',
          onChanged: _noop,
          unsupported: [],
          warming: true,
        ),
      ),
    ));
    // A spinner is infinite, so pump one frame rather than settle.
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows no spinner once warming is done', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SearchBarField(
          text: '',
          onChanged: _noop,
          unsupported: [],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Escape closes the overlay first, then clears on a second press',
      (tester) async {
    var latest = 'x';
    final controller =
        await pumpField(tester, onChanged: (v) => latest = v);
    await tester.enterText(find.byType(TextField), 'is:han');
    await tester.pumpAndSettle();
    expect(find.text('is:handcannon'), findsOneWidget);

    // First Escape: overlay closes, text stays.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('is:handcannon'), findsNothing);
    expect(controller.text, 'is:han');

    // Second Escape: clears the query.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(controller.text, isEmpty);
    expect(latest, isEmpty);
  });

  testWidgets('the help icon opens the search guide modal', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SearchBarField(text: '', onChanged: _noop, unsupported: []),
      ),
    ));
    // The guide is not shown until the help icon is tapped.
    expect(find.text('Search & Filters'), findsNothing);

    await tester.tap(find.byTooltip('Search & filter help'));
    await tester.pumpAndSettle();

    // The modal is up with its title and a representative documented filter.
    expect(find.text('Search & Filters'), findsOneWidget);
    expect(find.text('perk:rampage'), findsOneWidget);
  });
}

/// A const-constructible onChanged for the warming-spinner tests.
void _noop(String _) {}
