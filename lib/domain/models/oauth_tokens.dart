/// OAuth tokens returned by Bungie's token endpoint, plus the computed
/// absolute expiry used to decide when a proactive refresh is needed.
///
/// A refresh token is only issued to Confidential clients; Public clients
/// receive an access token alone. The refresh fields are therefore optional.
///
/// Manual (de)serialization is used here rather than codegen — the shape is
/// small and stable, and it keeps this layer free of build_runner.
class OAuthTokens {
  const OAuthTokens({
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.membershipId,
    this.refreshToken,
    this.refreshTokenExpiresAt,
  });

  final String accessToken;
  final DateTime accessTokenExpiresAt;

  /// Bungie.net membership id of the signed-in user (`membership_id` field).
  final String membershipId;

  /// Present only for Confidential clients.
  final String? refreshToken;
  final DateTime? refreshTokenExpiresAt;

  /// Build from Bungie's token response, stamping absolute expiries from the
  /// `expires_in` / `refresh_expires_in` durations (seconds) as of [now].
  factory OAuthTokens.fromTokenResponse(
    Map<String, dynamic> json, {
    required DateTime now,
  }) {
    final expiresIn = (json['expires_in'] as num).toInt();
    final refreshExpiresIn = (json['refresh_expires_in'] as num?)?.toInt();
    return OAuthTokens(
      accessToken: json['access_token'] as String,
      accessTokenExpiresAt: now.add(Duration(seconds: expiresIn)),
      membershipId: json['membership_id'].toString(),
      refreshToken: json['refresh_token'] as String?,
      refreshTokenExpiresAt: refreshExpiresIn == null
          ? null
          : now.add(Duration(seconds: refreshExpiresIn)),
    );
  }

  /// Round-trip form for [flutter_secure_storage] (stores absolute expiries).
  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'access_token_expires_at': accessTokenExpiresAt.toIso8601String(),
        'membership_id': membershipId,
        'refresh_token': refreshToken,
        'refresh_token_expires_at': refreshTokenExpiresAt?.toIso8601String(),
      };

  factory OAuthTokens.fromStorageJson(Map<String, dynamic> json) {
    final refreshExpiry = json['refresh_token_expires_at'] as String?;
    return OAuthTokens(
      accessToken: json['access_token'] as String,
      accessTokenExpiresAt:
          DateTime.parse(json['access_token_expires_at'] as String),
      membershipId: json['membership_id'] as String,
      refreshToken: json['refresh_token'] as String?,
      refreshTokenExpiresAt:
          refreshExpiry == null ? null : DateTime.parse(refreshExpiry),
    );
  }

  /// True when a refresh token exists that has not yet expired.
  bool get canRefresh =>
      refreshToken != null && refreshTokenExpiresAt != null;

  /// Access token is considered expired [skew] before its real expiry so a
  /// refresh happens proactively rather than mid-request.
  bool accessTokenExpired(DateTime now,
          {Duration skew = const Duration(minutes: 2)}) =>
      now.isAfter(accessTokenExpiresAt.subtract(skew));

  /// Refresh token expired (or was never issued) — the user must sign in again.
  bool refreshTokenExpired(DateTime now) =>
      refreshTokenExpiresAt == null || now.isAfter(refreshTokenExpiresAt!);
}
