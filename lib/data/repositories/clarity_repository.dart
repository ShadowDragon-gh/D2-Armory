import 'dart:io';
import 'dart:isolate';

import 'package:logger/logger.dart';

import '../../domain/models/clarity_insight.dart';
import '../local/clarity_downloader.dart';
import '../local/clarity_store.dart';

/// Serves Clarity community insights, keyed by a plug's inventory-item hash.
///
/// [ensureLoaded] keeps the local cache current (re-downloading only when
/// Clarity's published version changes) and parses it once per session. The
/// data is pure enrichment: every failure path degrades to "no insights"
/// with a logged warning — the app must never depend on it.
class ClarityRepository {
  ClarityRepository({required this._downloader, Logger? logger})
      : _log = logger ?? Logger();

  final ClarityDownloader _downloader;
  final Logger _log;

  Map<int, ClarityInsight> _insights = const {};

  // Insights keyed by normalized name (see [_normalizeName]), for the
  // enhanced-plug fallback: Clarity documents the base plug ("Synergy") but
  // not its mechanically-identical enhanced copy, which the app looks up by a
  // different hash. When two names normalize the same, the first parsed wins
  // (arbitrary but stable — they carry the same text). Built once on load.
  Map<String, ClarityInsight> _insightsByName = const {};

  bool get isReady => _insights.isNotEmpty;

  /// The insight for [plugHash], or null when Clarity has none (or the
  /// database is unavailable this session).
  ClarityInsight? insightFor(int plugHash) => _insights[plugHash];

  /// The insight matching [name] regardless of hash, used as a fallback when
  /// [insightFor] misses — e.g. an enhanced mod whose own hash Clarity does
  /// not carry but whose base-named copy it does. Matching is case- and
  /// "Enhanced "-prefix-insensitive. Null when no name matches.
  ClarityInsight? insightForName(String name) {
    final key = _normalizeName(name);
    return key.isEmpty ? null : _insightsByName[key];
  }

  /// Normalize a plug/insight name for the fallback match: drop a leading
  /// "Enhanced " (enhanced variants share the base's text) and lowercase.
  static String _normalizeName(String name) {
    var n = name.trim();
    const prefix = 'Enhanced ';
    if (n.startsWith(prefix)) n = n.substring(prefix.length);
    return n.toLowerCase();
  }

  /// Refresh the cache if Clarity published a new version, then parse it.
  /// Idempotent: a second call with insights already loaded returns
  /// immediately. Never throws — offline (or a failed download) falls back to
  /// the existing cache, and no cache means insights are simply unavailable.
  Future<void> ensureLoaded() async {
    if (_insights.isNotEmpty) return;

    final String path;
    try {
      path = await _downloader.localPath();
    } catch (e) {
      // No storage directory (e.g. platform channels unavailable in tests).
      _log.w('Clarity storage unavailable: $e');
      return;
    }

    try {
      final version = (await _downloader.fetchVersion())?.toString();
      final stored = await _downloader.readStoredVersion();
      if (version != null && (!File(path).existsSync() || version != stored)) {
        await _downloader.download();
        await _downloader.writeStoredVersion(version);
      }
    } catch (e) {
      if (File(path).existsSync()) {
        _log.w('Clarity refresh failed; using the cached copy: $e');
      } else {
        _log.w('Clarity unavailable (no cache, fetch failed): $e');
        return;
      }
    }

    if (!File(path).existsSync()) return;
    try {
      _insights = await Isolate.run(() => parseClarityFile(path));
      // The name index for the enhanced-plug fallback: first parsed wins on a
      // normalized-name collision (same text, so the choice is immaterial).
      final byName = <String, ClarityInsight>{};
      for (final insight in _insights.values) {
        final key = _normalizeName(insight.name);
        if (key.isNotEmpty) byName.putIfAbsent(key, () => insight);
      }
      _insightsByName = byName;
      _log.i('Clarity loaded: ${_insights.length} insights.');
    } catch (e) {
      _log.w('Clarity cache could not be parsed: $e');
    }
  }
}
