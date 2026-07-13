import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'presentation/screens/root_screen.dart';
import 'presentation/theme/app_theme.dart';
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
  runApp(const ProviderScope(child: D2ArmoryApp()));
}

class D2ArmoryApp extends StatelessWidget {
  const D2ArmoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'D2 Armory',
      debugShowCheckedModeBanner: false,
      theme: buildArmoryTheme(),
      // A slim custom title bar sits above every screen.
      builder: (context, child) => WindowScaffold(child: child!),
      home: const RootScreen(),
    );
  }
}
