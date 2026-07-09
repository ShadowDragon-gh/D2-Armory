// Widget tests for the login screen.
//
// Tests run without --dart-define, so AppConfig.hasCredentials is false. The
// login screen must reflect that: the sign-in button is disabled and the
// "credentials not configured" guidance is shown.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:destiny2_loadout_planner/main.dart';

void main() {
  testWidgets('login screen disables sign-in when credentials are missing',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: DestinyLoadoutPlannerApp()));

    expect(find.text('Destiny 2 Loadout Planner'), findsOneWidget);

    final signInButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(signInButton.onPressed, isNull);

    expect(
      find.textContaining('Bungie credentials are not configured'),
      findsOneWidget,
    );
  });
}
