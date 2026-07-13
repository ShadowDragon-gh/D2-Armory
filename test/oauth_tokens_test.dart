import 'package:flutter_test/flutter_test.dart';

import 'package:d2_armory/domain/models/oauth_tokens.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1, 12);

  group('OAuthTokens.fromTokenResponse', () {
    test('parses a public-client response with no refresh token', () {
      // The response shape that previously crashed with a null cast.
      final tokens = OAuthTokens.fromTokenResponse({
        'access_token': 'abc',
        'expires_in': 3600,
        'membership_id': '12345',
      }, now: now);

      expect(tokens.accessToken, 'abc');
      expect(tokens.membershipId, '12345');
      expect(tokens.refreshToken, isNull);
      expect(tokens.refreshTokenExpiresAt, isNull);
      expect(tokens.canRefresh, isFalse);
      expect(tokens.accessTokenExpiresAt, now.add(const Duration(hours: 1)));
    });

    test('parses a confidential-client response with refresh token', () {
      final tokens = OAuthTokens.fromTokenResponse({
        'access_token': 'abc',
        'expires_in': 3600,
        'refresh_token': 'refresh',
        'refresh_expires_in': 7776000,
        'membership_id': 12345,
      }, now: now);

      expect(tokens.refreshToken, 'refresh');
      expect(tokens.canRefresh, isTrue);
      expect(tokens.refreshTokenExpiresAt,
          now.add(const Duration(seconds: 7776000)));
    });
  });

  group('expiry + storage round-trip', () {
    test('refreshTokenExpired is true when no refresh token exists', () {
      final tokens = OAuthTokens.fromTokenResponse({
        'access_token': 'abc',
        'expires_in': 3600,
        'membership_id': '1',
      }, now: now);

      expect(tokens.refreshTokenExpired(now), isTrue);
    });

    test('storage JSON round-trips both client shapes', () {
      for (final source in [
        OAuthTokens.fromTokenResponse({
          'access_token': 'a',
          'expires_in': 3600,
          'membership_id': '1',
        }, now: now),
        OAuthTokens.fromTokenResponse({
          'access_token': 'a',
          'expires_in': 3600,
          'refresh_token': 'r',
          'refresh_expires_in': 100,
          'membership_id': '1',
        }, now: now),
      ]) {
        final restored = OAuthTokens.fromStorageJson(source.toJson());
        expect(restored.accessToken, source.accessToken);
        expect(restored.refreshToken, source.refreshToken);
        expect(restored.refreshTokenExpiresAt, source.refreshTokenExpiresAt);
        expect(restored.canRefresh, source.canRefresh);
      }
    });
  });
}
