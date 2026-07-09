import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';

/// Entry screen. Presents Bungie sign-in.
///
/// OAuth is not wired yet — the sign-in button is a placeholder until the
/// auth layer lands. When Bungie credentials are missing from the env file,
/// the screen says so rather than silently offering a button that cannot work.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final credentialsReady = AppConfig.hasCredentials;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: 24),
                Text(
                  'Destiny 2 Loadout Planner',
                  style: theme.textTheme.headlineSmall,
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
                  onPressed: credentialsReady
                      ? () => _onSignInPressed(context)
                      : null,
                  icon: const Icon(Icons.login),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Sign in with Bungie.net'),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onSignInPressed(BuildContext context) {
    // TODO: wire up flutter_web_auth_2 OAuth flow via the auth repository.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OAuth flow not implemented yet.')),
    );
  }
}
