import 'package:flutter_test/flutter_test.dart';

import 'package:destiny2_loadout_planner/domain/models/app_release.dart';
import 'package:destiny2_loadout_planner/domain/models/app_version.dart';

/// A minimal GitHub `releases/latest` payload with one zip asset.
Map<String, dynamic> _payload({
  String tag = 'v1.1.0',
  String assetName = 'D2Armory-1.1.0.zip',
  int size = 12345,
  String? body,
}) =>
    {
      'tag_name': tag,
      'body': body,
      'assets': [
        {
          'name': assetName,
          'size': size,
          'browser_download_url': 'https://example.com/$assetName',
        },
      ],
    };

void main() {
  group('AppRelease.tryParse', () {
    test('extracts version, tag, and zip asset', () {
      final release = AppRelease.tryParse(_payload())!;
      expect(release.version, const AppVersion(1, 1, 0));
      expect(release.tag, 'v1.1.0');
      expect(release.zipUrl, 'https://example.com/D2Armory-1.1.0.zip');
      expect(release.zipSize, 12345);
      expect(release.sha256, isNull);
    });

    test('parses a sha256 line out of the release body', () {
      final hash = 'a' * 64;
      final release = AppRelease.tryParse(_payload(body: 'notes\nsha256: $hash'));
      expect(release!.sha256, hash);
    });

    test('lower-cases the parsed checksum', () {
      final release =
          AppRelease.tryParse(_payload(body: 'SHA256: ${'AB' * 32}'));
      expect(release!.sha256, ('ab' * 32));
    });

    test('returns null when there is no zip asset', () {
      final json = _payload(assetName: 'notes.txt');
      expect(AppRelease.tryParse(json), isNull);
    });

    test('returns null when the tag has no numeric version', () {
      final json = _payload(tag: 'nightly');
      expect(AppRelease.tryParse(json), isNull);
    });

    test('picks the zip even when other assets are present', () {
      final json = _payload();
      (json['assets'] as List).insert(0, {
        'name': 'checksums.txt',
        'size': 10,
        'browser_download_url': 'https://example.com/checksums.txt',
      });
      final release = AppRelease.tryParse(json)!;
      expect(release.zipUrl, endsWith('.zip'));
    });
  });
}
