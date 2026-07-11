import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/failures.dart';
import '../../core/network/interceptors/auth_interceptor.dart';
import '../../domain/models/oauth_tokens.dart';
import '../local/token_storage.dart';

/// Drives the Bungie OAuth flow (loopback redirect for desktop) and owns the
/// lifecycle of the stored tokens. Implements [TokenProvider] so the network
/// layer can pull valid access tokens without depending on this class.
class AuthRepository implements TokenProvider {
  AuthRepository({
    required Dio unauthenticatedDio,
    required this._storage,
    Logger? logger,
  })  : _dio = unauthenticatedDio,
        _log = logger ?? Logger();

  final Dio _dio;
  final TokenStorage _storage;
  final Logger _log;

  OAuthTokens? _cached;
  Future<String?>? _inFlightRefresh;

  /// True when a stored token set is still usable: either the access token is
  /// live, or it can be refreshed.
  Future<bool> hasValidSession() async {
    final tokens = await _load();
    if (tokens == null) return false;
    final now = DateTime.now();
    return !tokens.accessTokenExpired(now) ||
        (tokens.canRefresh && !tokens.refreshTokenExpired(now));
  }

  /// Full interactive sign-in: open the browser, capture the loopback
  /// redirect, and exchange the code for tokens. Throws [AuthFailure] on
  /// cancellation or protocol errors.
  Future<OAuthTokens> signIn() async {
    if (!AppConfig.hasCredentials) {
      throw const AuthFailure('Bungie API key / client id are not configured.');
    }

    final state = _randomState();
    final server = await _bindLoopback();
    try {
      final authUrl = _buildAuthorizeUrl(state);
      _log.i('Opening browser for Bungie sign-in.');
      final launched = await launchUrl(authUrl,
          mode: LaunchMode.externalApplication);
      if (!launched) {
        throw const AuthFailure('Could not open the system browser.');
      }

      final code = await _awaitAuthCode(server, expectedState: state);
      final tokens = await _exchangeCode(code);
      await _persist(tokens);
      _log.i('Sign-in complete for membership ${tokens.membershipId}.');
      return tokens;
    } finally {
      await server.close(force: true);
    }
  }

  Future<void> signOut() async {
    _cached = null;
    await _storage.clear();
  }

  // --- TokenProvider ---

  @override
  Future<String?> validAccessToken() async {
    final tokens = await _load();
    if (tokens == null) return null;

    final now = DateTime.now();
    if (!tokens.accessTokenExpired(now)) {
      return tokens.accessToken;
    }
    // Access token expired: refresh if we can, otherwise the session is over.
    if (tokens.canRefresh && !tokens.refreshTokenExpired(now)) {
      return forceRefresh();
    }
    await signOut();
    return null;
  }

  @override
  Future<String?> forceRefresh() {
    // Collapse concurrent refreshes into a single in-flight request.
    return _inFlightRefresh ??= _refresh().whenComplete(() {
      _inFlightRefresh = null;
    });
  }

  // --- internals ---

  Future<String?> _refresh() async {
    final tokens = await _load();
    if (tokens == null) return null;
    if (!tokens.canRefresh || tokens.refreshTokenExpired(DateTime.now())) {
      await signOut();
      return null;
    }
    try {
      final refreshed = await _postToken({
        'grant_type': 'refresh_token',
        'refresh_token': tokens.refreshToken!,
      });
      await _persist(refreshed);
      return refreshed.accessToken;
    } on Failure catch (e) {
      _log.w('Token refresh failed: ${e.message}');
      return null;
    }
  }

  Future<OAuthTokens> _exchangeCode(String code) => _postToken({
        'grant_type': 'authorization_code',
        'code': code,
      });

  Future<OAuthTokens> _postToken(Map<String, String> fields) async {
    // Confidential clients authenticate with HTTP Basic (client_id:secret) and
    // omit client_id from the body; Public clients send client_id in the body.
    final headers = <String, String>{};
    final body = <String, String>{...fields};
    if (AppConfig.isConfidentialClient) {
      final creds = base64.encode(utf8.encode(
          '${AppConfig.bungieClientId}:${AppConfig.bungieClientSecret}'));
      headers['Authorization'] = 'Basic $creds';
    } else {
      body['client_id'] = AppConfig.bungieClientId;
    }

    try {
      _log.d('Token request (${fields['grant_type']}).');
      final response = await _dio.post<Map<String, dynamic>>(
        AppConfig.oauthTokenUrl,
        data: body,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: headers,
        ),
      );
      final data = response.data;
      if (data == null) {
        throw const ApiFailure('Empty token response from Bungie.');
      }
      return OAuthTokens.fromTokenResponse(data, now: DateTime.now());
    } on DioException catch (e) {
      throw _mapDioError(e, context: 'token endpoint');
    }
  }

  Future<void> _persist(OAuthTokens tokens) async {
    _cached = tokens;
    await _storage.save(tokens);
  }

  Future<OAuthTokens?> _load() async {
    return _cached ??= await _storage.read();
  }

  Uri _buildAuthorizeUrl(String state) =>
      Uri.parse(AppConfig.oauthAuthorizeUrl).replace(queryParameters: {
        'client_id': AppConfig.bungieClientId,
        'response_type': 'code',
        'state': state,
      });

  // Bungie requires an https redirect (it rejects http), so the loopback
  // server serves TLS using a bundled self-signed certificate for 127.0.0.1.
  // The browser will warn that the certificate is not trusted; proceeding past
  // that warning once delivers the authorization code to this server.
  Future<HttpServer> _bindLoopback() async {
    final context = SecurityContext(withTrustedRoots: false)
      ..useCertificateChainBytes(
          (await rootBundle.load(_certAsset)).buffer.asUint8List())
      ..usePrivateKeyBytes(
          (await rootBundle.load(_keyAsset)).buffer.asUint8List());
    try {
      return await HttpServer.bindSecure(
          InternetAddress.loopbackIPv4, AppConfig.oauthRedirectPort, context);
    } on SocketException catch (e) {
      throw AuthFailure(
        'Could not listen on port ${AppConfig.oauthRedirectPort} for the '
        'OAuth redirect (is it already in use?).',
        cause: e,
      );
    }
  }

  static const _certAsset = 'assets/certs/loopback_cert.pem';
  static const _keyAsset = 'assets/certs/loopback_key.pem';

  Future<String> _awaitAuthCode(
    HttpServer server, {
    required String expectedState,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final completer = Completer<String>();

    final subscription = server.listen((HttpRequest request) async {
      if (request.uri.path != AppConfig.oauthRedirectPath) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      final params = request.uri.queryParameters;
      await _respondToBrowser(request, params);

      if (completer.isCompleted) return;
      final error = params['error'];
      if (error != null) {
        completer.completeError(AuthFailure('Bungie denied access: $error'));
      } else if (params['state'] != expectedState) {
        completer.completeError(
            const AuthFailure('OAuth state mismatch — possible CSRF.'));
      } else if (params['code'] == null) {
        completer.completeError(
            const AuthFailure('Redirect did not include an authorization code.'));
      } else {
        completer.complete(params['code']);
      }
    });

    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () =>
            throw const AuthFailure('Timed out waiting for Bungie sign-in.'),
      );
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> _respondToBrowser(
      HttpRequest request, Map<String, String> params) async {
    final ok = params['error'] == null && params['code'] != null;
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write(_callbackPage(ok));
    await request.response.close();
  }

  /// The one-shot page shown in the browser after Bungie redirects back.
  /// Colors are the D2 Armory brand tokens (armory_palette.dart) as CSS hex —
  /// vault-bronze accent on the surface-1 background.
  String _callbackPage(bool ok) {
    final accent = ok ? '#C98A3C' : '#D1453B';
    final glyph = ok ? '&#10003;' : '&#33;';
    final title = ok ? 'Signed in' : 'Sign-in failed';
    final message = ok
        ? 'You can close this tab and return to D2 Armory.'
        : 'Return to the app and try again.';
    return '''
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title &middot; D2 Armory</title>
<style>
  html, body { height: 100%; margin: 0; }
  body {
    display: flex; align-items: center; justify-content: center;
    background: #12161B; color: #ECEFF2;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  }
  .card { text-align: center; padding: 2rem; max-width: 24rem; }
  .badge {
    width: 4.5rem; height: 4.5rem; margin: 0 auto 1.75rem;
    border-radius: 50%; display: flex; align-items: center; justify-content: center;
    background: ${accent}22; border: 2px solid $accent;
    color: $accent; font-size: 2.25rem; line-height: 1;
  }
  h1 {
    margin: 0 0 0.5rem; font-size: 1.5rem; font-weight: 700;
    letter-spacing: 0.06em; text-transform: uppercase;
  }
  p { margin: 0; color: #8A95A1; font-size: 0.95rem; line-height: 1.5; }
</style>
</head>
<body>
  <div class="card">
    <div class="badge">$glyph</div>
    <h1>$title</h1>
    <p>$message</p>
  </div>
</body>
</html>''';
  }

  Failure _mapDioError(DioException e, {required String context}) {
    final status = e.response?.statusCode;
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return NetworkFailure('Network error reaching $context.', cause: e);
    }
    final data = e.response?.data;
    final errorCode = data is Map ? (data['ErrorCode'] as num?)?.toInt() : null;
    return ApiFailure(
      'Bungie $context returned an error.',
      statusCode: status,
      errorCode: errorCode,
      cause: e,
    );
  }

  String _randomState() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes);
  }
}
