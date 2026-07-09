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

  /// Only set for Confidential OAuth clients. Presence enables silent token
  /// refresh (Bungie issues a refresh token) and HTTP Basic auth on the token
  /// endpoint.
  static const String bungieClientSecret =
      String.fromEnvironment('BUNGIE_CLIENT_SECRET');

  /// True once real Bungie credentials have been provided via the env file.
  static bool get hasCredentials =>
      bungieApiKey.isNotEmpty && bungieClientId.isNotEmpty;

  /// A Confidential client authenticates the token endpoint with a secret.
  static bool get isConfidentialClient => bungieClientSecret.isNotEmpty;

  // --- Bungie endpoints ---

  static const String bungieBaseUrl = 'https://www.bungie.net';

  static const String apiBaseUrl = '$bungieBaseUrl/Platform';

  static const String oauthAuthorizeUrl = '$bungieBaseUrl/en/oauth/authorize';

  static const String oauthTokenUrl = '$apiBaseUrl/App/OAuth/token/';

  /// Single scope covering all read operations (inventory, vault, loadouts).
  static const String oauthScope = 'ReadDestinyInventoryAndVault';

  // --- OAuth loopback redirect (Windows desktop) ---
  //
  // Bungie desktop OAuth uses a loopback redirect: the app opens the system
  // browser to [oauthAuthorizeUrl] and listens on [oauthRedirectHost]:
  // [oauthRedirectPort] for Bungie's redirect carrying the authorization code.
  // The value registered as the app's Redirect URL on bungie.net must equal
  // [oauthRedirectUrl]. Bungie requires https here (it rejects http).

  static const String oauthRedirectHost = '127.0.0.1';

  static const int oauthRedirectPort = 7355;

  static const String oauthRedirectPath = '/callback';

  static String get oauthRedirectUrl =>
      'https://$oauthRedirectHost:$oauthRedirectPort$oauthRedirectPath';
}
