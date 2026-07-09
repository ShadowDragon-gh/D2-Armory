// Widget tests for the auth entry flow.
//
// Tests run without --dart-define, so AppConfig.hasCredentials is false. After
// the startup session check resolves (secure storage is unavailable in tests,
// which resolves to signed-out), the login screen must reflect the missing
// credentials: the sign-in button is disabled and guidance is shown.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:destiny2_loadout_planner/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // In-memory secure storage so the startup session check resolves without
    // hitting a platform channel (which hangs under flutter_test).
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('login screen disables sign-in when credentials are missing',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: DestinyLoadoutPlannerApp()));

    // Startup shows a splash until the persisted session check resolves.
    await tester.pumpAndSettle();

    // The login screen's subtitle is unique to it (the app title also appears
    // in the desktop title bar, so match the subtitle rather than the name).
    expect(
      find.text('Browse, build, and save loadouts with live game data.'),
      findsOneWidget,
    );

    final signInButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(signInButton.onPressed, isNull);

    expect(
      find.textContaining('Bungie credentials are not configured'),
      findsOneWidget,
    );
  });
}
