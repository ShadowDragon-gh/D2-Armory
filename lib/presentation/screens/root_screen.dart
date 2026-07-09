import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/auth_state.dart';
import '../providers/auth_provider.dart';
import 'auth/login_screen.dart';
import 'home/home_screen.dart';

/// Chooses the top-level screen from the current [AuthState].
///
/// Routing keys off the last known state value, not the async status: an
/// in-progress sign-in keeps the login screen visible (which renders its own
/// busy/error UI) instead of flashing the startup splash.
class RootScreen extends ConsumerWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final state = auth.value;

    return switch (state) {
      SignedIn(:final membershipId) =>
        HomeScreen(membershipId: membershipId),
      SignedOut() => const LoginScreen(),
      // First frame before the persisted session has been checked.
      AuthUnknown() || null => const _Splash(),
    };
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
