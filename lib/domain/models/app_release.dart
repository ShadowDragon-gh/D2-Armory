import 'app_version.dart';

/// A single GitHub release, reduced to the fields the updater needs: its
/// version (from the tag), the downloadable Windows zip asset, and — if the
/// release notes contain one — the SHA-256 checksum used to verify the download.
///
/// Manual (de)serialization matches [OAuthTokens]; the shape is small and the
/// project avoids build_runner.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.tag,
    required this.zipUrl,
    required this.zipSize,
    this.sha256,
  });

  final AppVersion version;
  final String tag;

  /// `browser_download_url` of the release's `.zip` asset.
  final String zipUrl;

  /// Asset size in bytes, used as a cheap integrity pre-check before hashing.
  final int zipSize;

  /// Expected SHA-256 of the zip (lower-case hex), if published in the release
  /// body as a line like `sha256: <hex>`. Null when not published.
  final String? sha256;

  /// Parse GitHub's `releases/latest` response. Returns null if the release has
  /// no parseable version tag or no `.zip` asset — either means "nothing this
  /// updater can act on", which the caller treats as "no update available".
  static AppRelease? tryParse(Map<String, dynamic> json) {
    final tag = json['tag_name'] as String?;
    if (tag == null) return null;
    final version = AppVersion.tryParse(tag);
    if (version == null) return null;

    final assets = (json['assets'] as List?)?.cast<Map<String, dynamic>>();
    if (assets == null) return null;
    final zip = assets.where((a) {
      final name = (a['name'] as String?)?.toLowerCase() ?? '';
      return name.endsWith('.zip');
    }).firstOrNull;
    if (zip == null) return null;

    final zipUrl = zip['browser_download_url'] as String?;
    if (zipUrl == null) return null;

    return AppRelease(
      version: version,
      tag: tag,
      zipUrl: zipUrl,
      zipSize: (zip['size'] as num?)?.toInt() ?? 0,
      sha256: _sha256FromBody(json['body'] as String?),
    );
  }

  /// Extract a `sha256: <64 hex chars>` line from the release body, if present.
  static String? _sha256FromBody(String? body) {
    if (body == null) return null;
    final match =
        RegExp(r'sha256:\s*([a-fA-F0-9]{64})', caseSensitive: false)
            .firstMatch(body);
    return match?.group(1)?.toLowerCase();
  }
}
