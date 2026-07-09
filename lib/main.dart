import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/screens/root_screen.dart';

void main() {
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
      home: const RootScreen(),
    );
  }
}
