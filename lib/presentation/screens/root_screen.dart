import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/auth_state.dart';
import '../providers/app_warmup_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/manifest_provider.dart';
import 'app_shell.dart';
import 'auth/login_screen.dart';
import 'manifest_loading_screen.dart';

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
      SignedIn() => const _SignedInGate(),
      SignedOut() => const LoginScreen(),
      // First frame before the persisted session has been checked.
      AuthUnknown() || null => const _Splash(),
    };
  }
}

/// Gates manifest-dependent screens behind the manifest bootstrap, which
/// requires an authenticated session to fetch metadata.
class _SignedInGate extends ConsumerWidget {
  const _SignedInGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manifestReady = ref.watch(manifestBootstrapProvider).hasValue;
    if (!manifestReady) return const ManifestLoadingScreen();
    // Manifest is open: show the shell immediately and start warming every
    // tab's data in the background. The shell does not wait — each tab shows
    // its own spinner until its data lands, without blocking the others.
    ref.watch(appWarmupProvider);
    return const AppShell();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
