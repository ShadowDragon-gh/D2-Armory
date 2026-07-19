import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../data/local/clarity_downloader.dart';
import '../../data/repositories/clarity_repository.dart';
import '../../domain/models/clarity_insight.dart';
import 'manifest_provider.dart';

/// Clarity is a public GitHub Pages file — a plain Dio, deliberately not
/// `DioClient` (whose instances carry the Bungie API key and base URL).
final clarityRepositoryProvider = Provider<ClarityRepository>((ref) {
  return ClarityRepository(downloader: ClarityDownloader(Dio()));
});

/// Runs the one-time Clarity bootstrap (version check, download if stale,
/// parse). Kicked off by the app warmup in parallel with the manifest and
/// never awaited by any screen: the manifest is required to render, Clarity
/// is enrichment — covered rows appear once this resolves.
final clarityBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.watch(clarityRepositoryProvider).ensureLoaded();
});

/// The Clarity insight for a plug's inventory-item hash, or null when Clarity
/// has none. Watches the bootstrap so rows resolved before the database
/// finished loading rebuild once it lands.
final clarityInsightProvider =
    Provider.autoDispose.family<ClarityInsight?, int>((ref, hash) {
  ref.watch(clarityBootstrapProvider);
  return ref.watch(clarityRepositoryProvider).insightFor(hash);
});

/// A plug's hash and display name — the key for [clarityInsightForPlugProvider],
/// which resolves an insight by hash first and falls back to the name.
typedef ClarityPlugRef = ({int hash, String name});

/// The Clarity insight for a plug, by its hash first and its name second.
/// The name fallback covers enhanced plug variants whose own hash Clarity
/// does not carry but whose base-named copy it does (e.g. an "Enhanced"
/// weapon stat mod → the base mod's insight). Watches the bootstrap so it
/// resolves once Clarity lands.
final clarityInsightForPlugProvider =
    Provider.autoDispose.family<ClarityInsight?, ClarityPlugRef>((ref, plug) {
  ref.watch(clarityBootstrapProvider);
  final repo = ref.watch(clarityRepositoryProvider);
  return repo.insightFor(plug.hash) ?? repo.insightForName(plug.name);
});

/// Clarity marker className → the game damage-type enum, shared by the
/// manifest icon lookup and the renderer's tint/word fallback.
const kClarityDamageTypeByClassName = {
  'kinetic': 1,
  'arc': 2,
  'solar': 3,
  'void': 4,
  'stasis': 6,
  'strand': 7,
};

/// Clarity champion className → the breaker-type enum (Shield Piercing
/// stops Barrier, Disruption stops Overload, Stagger stops Unstoppable).
const kClarityChampionByClassName = {
  'barrier': 1,
  'overload': 2,
  'unstoppable': 3,
};

/// Icon URLs for the Clarity marker classNames whose art lives in the
/// manifest: damage types (the white transparent glyphs, tinted by the
/// renderer) and champion/breaker icons. Empty while the manifest is not
/// open — safe because every insight surface renders behind the manifest
/// bootstrap; a pre-manifest render (widget tests) falls back to the
/// marker's colored word. Ammo and class markers use local vectors instead.
final clarityMarkerIconsProvider = Provider<Map<String, String>>((ref) {
  final manifest = ref.watch(manifestRepositoryProvider);
  if (manifest.databasePath == null) return const {};

  Map<int, Map<String, dynamic>> byEnum(List<Map<String, dynamic>> defs) => {
        for (final d in defs)
          if ((d['enumValue'] as num?)?.toInt() case final int v) v: d,
      };
  final damage = byEnum(manifest.allDamageTypes());
  final breakers = byEnum(manifest.allBreakerTypes());

  final icons = <String, String>{};
  kClarityDamageTypeByClassName.forEach((name, enumValue) {
    final path = damage[enumValue]?['transparentIconPath'] as String?;
    if (path != null && path.isNotEmpty) {
      icons[name] = '${AppConfig.bungieBaseUrl}$path';
    }
  });
  kClarityChampionByClassName.forEach((name, enumValue) {
    final path =
        breakers[enumValue]?['displayProperties']?['icon'] as String?;
    if (path != null && path.isNotEmpty) {
      icons[name] = '${AppConfig.bungieBaseUrl}$path';
    }
  });
  return icons;
});
