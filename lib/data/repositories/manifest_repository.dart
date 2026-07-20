import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:logger/logger.dart';

import '../../core/destiny/destiny_buckets.dart';
import '../../core/errors/failures.dart';
import '../local/manifest_database.dart';
import '../local/manifest_downloader.dart';
import '../remote/bungie_api.dart';
import 'facet_builder.dart' show FacetSource;

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
class ManifestRepository implements FacetSource {
  ManifestRepository({
    required this._api,
    required this._downloader,
    Logger? logger,
  }) : _log = logger ?? Logger();

  final BungieApi _api;
  final ManifestDownloader _downloader;
  final Logger _log;

  ManifestDatabase? _db;

  // The opened manifest's on-disk path, retained so a background isolate can
  // open its own read-only connection to the same file (the sqlite3 handle
  // itself is not sendable across isolates, but the read-only file is).
  String? _dbPath;

  /// The opened manifest file path, or null before [ensureLoaded]. Used to warm
  /// heavy definition work in a background isolate without blocking the UI.
  String? get databasePath => _dbPath;

  // DIM's bundled exotic itemHash -> catalyst recordHash map (keys are the
  // unsigned item hashes as strings).
  Map<String, dynamic> _catalystRecordMap = const {};

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
    _dbPath = localPath;
    await _loadCatalystRecordMap();
    onProgress?.call(const ManifestProgress(ManifestPhase.ready));
  }

  Future<void> _loadCatalystRecordMap() async {
    if (_catalystRecordMap.isNotEmpty) return;
    try {
      final raw = await rootBundle
          .loadString('assets/data/exotic_to_catalyst_record.json');
      _catalystRecordMap = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      // Non-fatal: catalyst progress just falls back to name matching.
      _log.w('Could not load catalyst-record map: $e');
    }
  }

  /// The catalyst record hash for an exotic weapon [itemHash], from DIM's
  /// bundled map. Null when the weapon has no known catalyst record.
  int? catalystRecordHashFor(int itemHash) =>
      (_catalystRecordMap['$itemHash'] as num?)?.toInt();

  @override
  Map<String, dynamic>? getInventoryItem(int hash) =>
      database.getInventoryItem(hash);

  Map<String, dynamic>? getIcon(int hash) => database.getIcon(hash);

  Map<String, dynamic>? getDamageType(int hash) =>
      database.getDamageType(hash);

  List<Map<String, dynamic>> allDamageTypes() => database.allDamageTypes();

  List<Map<String, dynamic>> allBreakerTypes() => database.allBreakerTypes();

  @override
  Map<String, dynamic>? getStat(int hash) => database.getStat(hash);

  Map<String, dynamic>? getStatGroup(int hash) =>
      database.getStatGroup(hash);

  @override
  Map<String, dynamic>? getBreakerType(int hash) =>
      database.getBreakerType(hash);

  @override
  Map<String, dynamic>? getSandboxPerk(int hash) =>
      database.getSandboxPerk(hash);

  Map<String, dynamic>? findCatalystRecord(String weaponName) =>
      database.findCatalystRecord(weaponName);

  Map<String, dynamic>? getRecord(int hash) =>
      database.getDefinition('DestinyRecordDefinition', hash);

  Map<String, dynamic>? getObjective(int hash) => database.getObjective(hash);

  @override
  Map<String, dynamic>? getCollectible(int hash) =>
      database.getCollectible(hash);

  Map<String, dynamic>? getSocketCategory(int hash) =>
      database.getSocketCategory(hash);

  @override
  Map<String, dynamic>? getPlugSet(int hash) => database.getPlugSet(hash);

  Map<String, dynamic>? getEquipableItemSet(int hash) =>
      database.getEquipableItemSet(hash);

  @override
  List<Map<String, dynamic>> allEquipableItemSets() =>
      database.allEquipableItemSets();

  List<Map<String, Object?>> queryGearSummaries(GearKind kind) =>
      database.queryGearSummaries(kind);

  List<Map<String, Object?>> querySubclasses() => database.querySubclasses();

  @override
  Map<String, dynamic>? getSocketType(int hash) =>
      database.getDefinition('DestinySocketTypeDefinition', hash);

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
