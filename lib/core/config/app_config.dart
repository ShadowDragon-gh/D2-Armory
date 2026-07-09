/// Static application configuration.
///
/// Secrets are supplied at build/run time via `--dart-define-from-file`
/// (see `env/dev.json`) and read through [String.fromEnvironment]. The
/// values default to empty strings when no env file is supplied, which lets
/// the app boot for UI work before Bungie credentials are configured.
class AppConfig {
  const AppConfig._();

  // --- Secrets (from dart-define) ---

  static const String bungieApiKey = String.fromEnvironment('BUNGIE_API_KEY');

  static const String bungieClientId =
      String.fromEnvironment('BUNGIE_CLIENT_ID');

  static const String oauthRedirectScheme = String.fromEnvironment(
    'BUNGIE_OAUTH_REDIRECT_SCHEME',
    defaultValue: 'destiny2loadout',
  );

  /// True once real Bungie credentials have been provided via the env file.
  static bool get hasCredentials =>
      bungieApiKey.isNotEmpty && bungieClientId.isNotEmpty;

  // --- Bungie endpoints ---

  static const String bungieBaseUrl = 'https://www.bungie.net';

  static const String apiBaseUrl = '$bungieBaseUrl/Platform';

  static const String oauthAuthorizeUrl = '$bungieBaseUrl/en/oauth/authorize';

  static const String oauthTokenUrl = '$apiBaseUrl/App/OAuth/token/';

  /// Single scope covering all read operations (inventory, vault, loadouts).
  static const String oauthScope = 'ReadDestinyInventoryAndVault';
}
