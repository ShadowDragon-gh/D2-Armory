import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/failures.dart';
import '../../providers/auth_provider.dart';
import '../../theme/armory_palette.dart';
import '../../theme/branding_svg.dart';

/// Entry screen. Presents Bungie sign-in and drives the OAuth flow via
/// [authControllerProvider]. When Bungie credentials are missing from the env
/// file, the screen says so rather than offering a button that cannot work.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final credentialsReady = AppConfig.hasCredentials;
    final auth = ref.watch(authControllerProvider);
    final busy = auth.isLoading;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.string(
                  kArmoryIconSvg,
                  width: 96,
                  height: 96,
                ),
                const SizedBox(height: 24),
                // The D2 Armory wordmark: bronze "D2", steel-white "ARMORY"
                // (the lockup in doc/design/, set in the display face).
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontFamily: ArmoryFonts.display,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                    children: [
                      TextSpan(
                        text: 'D2 ',
                        style:
                            TextStyle(color: theme.colorScheme.primary),
                      ),
                      const TextSpan(text: 'ARMORY'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Browse, build, and save loadouts with live game data.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                FilledButton.icon(
                  onPressed: credentialsReady && !busy
                      ? () => ref.read(authControllerProvider.notifier).signIn()
                      : null,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(busy
                        ? 'Waiting for browser…'
                        : 'Sign in with Bungie.net'),
                  ),
                ),
                if (!credentialsReady) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Bungie credentials are not configured.\n'
                    'Copy env/dev.example.json to env/dev.json and fill in '
                    'BUNGIE_API_KEY and BUNGIE_CLIENT_ID.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (auth.hasError) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage(auth.error!),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _errorMessage(Object error) =>
      error is Failure ? error.message : 'Sign-in failed. Please try again.';
}
