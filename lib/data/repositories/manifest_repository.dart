import 'dart:io';

import 'package:logger/logger.dart';

import '../../core/errors/failures.dart';
import '../local/manifest_database.dart';
import '../local/manifest_downloader.dart';
import '../remote/bungie_api.dart';

/// Progress of the manifest bootstrap, for surfacing on the loading screen.
enum ManifestPhase { checking, downloading, opening, ready }

class ManifestProgress {
  const ManifestProgress(this.phase, {this.received = 0, this.total = 0});

  final ManifestPhase phase;
  final int received;
  final int total;

  double? get fraction => total > 0 ? received / total : null;
}

/// Ensures a current manifest is downloaded and opened, and serves definition
/// lookups from it.
class ManifestRepository {
  ManifestRepository({
    required this._api,
    required this._downloader,
    Logger? logger,
  }) : _log = logger ?? Logger();

  final BungieApi _api;
  final ManifestDownloader _downloader;
  final Logger _log;

  ManifestDatabase? _db;

  ManifestDatabase get database {
    final db = _db;
    if (db == null) {
      throw StateError('Manifest not initialized; call ensureLoaded() first.');
    }
    return db;
  }

  /// Download (if needed) and open the current manifest. Idempotent: a second
  /// call with an already-open, current DB returns immediately.
  Future<void> ensureLoaded({
    String language = 'en',
    void Function(ManifestProgress)? onProgress,
  }) async {
    onProgress?.call(const ManifestProgress(ManifestPhase.checking));

    final manifest = await _api.getManifest();
    final version = manifest['version'] as String?;
    final paths =
        manifest['mobileWorldContentPaths'] as Map<String, dynamic>?;
    final relativePath = paths?[language] as String?;
    if (version == null || relativePath == null) {
      throw const ApiFailure('Manifest metadata was incomplete.');
    }

    if (_db != null) return; // already open this session

    final localPath = await _downloader.localPathFor(version);
    if (!File(localPath).existsSync()) {
      onProgress?.call(const ManifestProgress(ManifestPhase.downloading));
      await _downloader.download(
        version: version,
        relativePath: relativePath,
        onProgress: (received, total) => onProgress?.call(ManifestProgress(
            ManifestPhase.downloading,
            received: received,
            total: total)),
      );
      await _cleanupOldVersions(keep: localPath);
    } else {
      _log.i('Manifest $version already present.');
    }

    onProgress?.call(const ManifestProgress(ManifestPhase.opening));
    _db = ManifestDatabase.open(localPath);
    onProgress?.call(const ManifestProgress(ManifestPhase.ready));
  }

  Map<String, dynamic>? getInventoryItem(int hash) =>
      database.getInventoryItem(hash);

  Map<String, dynamic>? getDamageType(int hash) =>
      database.getDamageType(hash);

  Map<String, dynamic>? getStat(int hash) => database.getStat(hash);

  Map<String, dynamic>? getBreakerType(int hash) =>
      database.getBreakerType(hash);

  Map<String, dynamic>? getSandboxPerk(int hash) =>
      database.getSandboxPerk(hash);

  /// Remove manifest files from previous versions so they do not accumulate.
  /// Failure here is non-fatal but logged, not swallowed silently.
  Future<void> _cleanupOldVersions({required String keep}) async {
    try {
      final dir = File(keep).parent;
      for (final entity in dir.listSync()) {
        if (entity is File &&
            entity.path != keep &&
            entity.uri.pathSegments.last.startsWith('manifest_') &&
            entity.path.endsWith('.sqlite')) {
          entity.deleteSync();
          _log.i('Removed old manifest ${entity.path}');
        }
      }
    } catch (e) {
      _log.w('Could not clean up old manifest files: $e');
    }
  }

  void dispose() {
    _db?.close();
    _db = null;
  }
}
