import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:logger/logger.dart';

/// Serves DIM's d2-additional-info snapshot (MIT-licensed), bundled as assets
/// and never fetched at runtime — Destiny 2 is no longer updated, so the source
/// data is final. Datasets:
///
/// - `sources.json`: `sourceHash -> cleaner acquisition text`, used to override
///   the manifest's own `sourceString` when a nicer string exists.
/// - `weapon-from-quest.json`: `weaponItemHash -> initial quest-step item hash`,
///   for a "From the quest: `<name>`" note (the name is resolved via the manifest).
/// - `source_overrides.json`: OUR own `itemHash -> source text` map, layered
///   above d2ai so hand-added sources survive a d2ai snapshot refresh. Keyed by
///   *item* hash (not sourceHash), so it can fix individual items that share a
///   sourceHash — e.g. the ~384 "Random Perks" items. Edit this file to add
///   sources found in-game; the app reads it as a normal bundled asset.
///
/// A parse failure (should never happen for a committed asset) degrades to
/// empty maps and manifest-only source text — never a crash.
class D2aiRepository {
  D2aiRepository({Logger? logger}) : _log = logger ?? Logger();

  final Logger _log;

  static const _sourcesAsset = 'assets/d2ai/sources.json';
  static const _questAsset = 'assets/d2ai/weapon-from-quest.json';
  static const _overridesAsset = 'assets/d2ai/source_overrides.json';

  // Keys are unsigned hashes as strings (the asset shape); looked up via '$hash'
  // to avoid converting the whole map on load.
  Map<String, dynamic> _sources = const {};
  Map<String, dynamic> _questByWeapon = const {};
  Map<String, dynamic> _sourceOverrides = const {};

  bool _loaded = false;
  bool get isReady => _loaded;

  /// Load the bundled assets once. Idempotent.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _sources = await _loadJsonMap(_sourcesAsset);
    _questByWeapon = await _loadJsonMap(_questAsset);
    _sourceOverrides = await _loadJsonMap(_overridesAsset);
    _loaded = true;
  }

  Future<Map<String, dynamic>> _loadJsonMap(String asset) async {
    try {
      final raw = await rootBundle.loadString(asset);
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      // Non-fatal: the Source row falls back to the manifest sourceString.
      _log.w('Could not load d2ai asset $asset: $e');
      return const {};
    }
  }

  /// Our hand-authored source text for a specific [itemHash], or null when
  /// there is no override. Highest precedence — checked before d2ai/manifest,
  /// so it can fix items that share a sourceHash (e.g. "Random Perks" items).
  String? sourceOverrideFor(int itemHash) =>
      _sourceOverrides['$itemHash'] as String?;

  /// The cleaner acquisition text for [sourceHash], or null when d2ai has no
  /// entry (the caller then keeps the manifest's own sourceString).
  String? sourceFor(int sourceHash) => _sources['$sourceHash'] as String?;

  /// The initial quest-step item hash for weapon [weaponItemHash], or null when
  /// the weapon is not quest-sourced.
  int? questStepFor(int weaponItemHash) =>
      (_questByWeapon['$weaponItemHash'] as num?)?.toInt();
}
