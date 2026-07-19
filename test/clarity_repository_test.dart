import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:d2_armory/core/errors/failures.dart';
import 'package:d2_armory/data/local/clarity_downloader.dart';
import 'package:d2_armory/data/repositories/clarity_repository.dart';

class _MockClarityDownloader extends Mock implements ClarityDownloader {}

/// The deterministic freshness flow: download only when the published version
/// differs from the stored one, fall back to the cache when offline, and
/// degrade to "no insights" (never a crash) when neither is available.
void main() {
  late Directory tempDir;
  late _MockClarityDownloader downloader;
  late ClarityRepository repo;

  String cachePath() => '${tempDir.path}/clarity_descriptions.json';

  void seedCache() {
    File('test/fixtures/clarity_sample.json').copySync(cachePath());
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('clarity_test');
    downloader = _MockClarityDownloader();
    when(() => downloader.localPath()).thenAnswer((_) async => cachePath());
    when(() => downloader.writeStoredVersion(any())).thenAnswer((_) async {});
    repo = ClarityRepository(downloader: downloader);
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  test('downloads and parses when no cache exists', () async {
    when(() => downloader.fetchVersion()).thenAnswer((_) async => 2.0607);
    when(() => downloader.readStoredVersion()).thenAnswer((_) async => null);
    when(() => downloader.download()).thenAnswer((_) async => seedCache());

    await repo.ensureLoaded();

    expect(repo.isReady, isTrue);
    expect(repo.insightFor(75282108)?.name, 'Weighted Edge');
    expect(repo.insightFor(999), isNull);
    verify(() => downloader.download()).called(1);
    verify(() => downloader.writeStoredVersion('2.0607')).called(1);
  });

  test('insightForName matches by name, case- and Enhanced-insensitive', () {
    seedCache();
    when(() => downloader.fetchVersion()).thenAnswer((_) async => 2.0607);
    when(() => downloader.readStoredVersion())
        .thenAnswer((_) async => '2.0607');

    return repo.ensureLoaded().then((_) {
      final byHash = repo.insightFor(75282108); // Weighted Edge
      expect(byHash, isNotNull);

      // Exact, lowercased, and "Enhanced "-prefixed names all resolve to the
      // same insight — the enhanced-plug fallback (a different hash Clarity
      // does not carry maps back to the base by name).
      expect(repo.insightForName('Weighted Edge'), same(byHash));
      expect(repo.insightForName('weighted edge'), same(byHash));
      expect(repo.insightForName('Enhanced Weighted Edge'), same(byHash));
      expect(repo.insightForName('  Weighted Edge  '), same(byHash));

      // Unknown or empty names resolve to nothing.
      expect(repo.insightForName('Nonexistent Mod'), isNull);
      expect(repo.insightForName(''), isNull);
    });
  });

  test('re-downloads when the published version changed', () async {
    seedCache();
    when(() => downloader.fetchVersion()).thenAnswer((_) async => 2.1);
    when(() => downloader.readStoredVersion())
        .thenAnswer((_) async => '2.0607');
    when(() => downloader.download()).thenAnswer((_) async => seedCache());

    await repo.ensureLoaded();

    expect(repo.isReady, isTrue);
    verify(() => downloader.download()).called(1);
    verify(() => downloader.writeStoredVersion('2.1')).called(1);
  });

  test('uses the existing cache without downloading when current', () async {
    seedCache();
    when(() => downloader.fetchVersion()).thenAnswer((_) async => 2.0607);
    when(() => downloader.readStoredVersion())
        .thenAnswer((_) async => '2.0607');

    await repo.ensureLoaded();

    expect(repo.isReady, isTrue);
    expect(repo.insightFor(75282108), isNotNull);
    verifyNever(() => downloader.download());
  });

  test('falls back to the cache when the version check fails', () async {
    seedCache();
    when(() => downloader.fetchVersion())
        .thenThrow(const NetworkFailure('offline'));

    await repo.ensureLoaded();

    expect(repo.isReady, isTrue);
    expect(repo.insightFor(75282108), isNotNull);
    verifyNever(() => downloader.download());
  });

  test('is simply unavailable when offline with no cache', () async {
    when(() => downloader.fetchVersion())
        .thenThrow(const NetworkFailure('offline'));

    await expectLater(repo.ensureLoaded(), completes);

    expect(repo.isReady, isFalse);
    expect(repo.insightFor(75282108), isNull);
  });

  test('a second call is a no-op once loaded', () async {
    seedCache();
    when(() => downloader.fetchVersion()).thenAnswer((_) async => 2.0607);
    when(() => downloader.readStoredVersion())
        .thenAnswer((_) async => '2.0607');

    await repo.ensureLoaded();
    await repo.ensureLoaded();

    verify(() => downloader.fetchVersion()).called(1);
  });
}
