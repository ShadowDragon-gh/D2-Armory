import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:destiny2_loadout_planner/presentation/widgets/search_bar_field.dart';

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
}
