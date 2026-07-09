import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/models/oauth_tokens.dart';

/// Persists OAuth tokens in the platform secure store (Windows Credential
/// Locker / keychain / keystore). Tokens are held as a single JSON blob.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokensKey = 'bungie_oauth_tokens';

  Future<void> save(OAuthTokens tokens) =>
      _storage.write(key: _tokensKey, value: jsonEncode(tokens.toJson()));

  Future<OAuthTokens?> read() async {
    final raw = await _storage.read(key: _tokensKey);
    if (raw == null) return null;
    return OAuthTokens.fromStorageJson(
        jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> clear() => _storage.delete(key: _tokensKey);
}
