import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'presentation/screens/root_screen.dart';
import 'presentation/widgets/window_title_bar.dart';

Future<void> main() async {
  // Desktop platforms use a custom title bar, so hide the native one.
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        titleBarStyle: TitleBarStyle.hidden,
        minimumSize: Size(900, 600),
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
        await windowManager.maximize();
      },
    );
  }
  runApp(const ProviderScope(child: DestinyLoadoutPlannerApp()));
}

class DestinyLoadoutPlannerApp extends StatelessWidget {
  const DestinyLoadoutPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Destiny 2 Loadout Planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5C6BC0),
          brightness: Brightness.dark,
        ),
      ),
      // A slim custom title bar sits above every screen.
      builder: (context, child) => WindowScaffold(child: child!),
      home: const RootScreen(),
    );
  }
}
