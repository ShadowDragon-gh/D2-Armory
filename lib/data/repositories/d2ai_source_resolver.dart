import 'manifest_repository.dart';
import 'd2ai_repository.dart';

/// Collectible sourceHashes whose "source" text is not a real activity, quest,
/// vendor, or location — so no Source row is shown for items carrying them.
/// A per-item override can still un-hide an individual item.
const _nonSourceHashes = <int>{
  // "Random Perks: This item cannot be reacquired from Collections." (~384
  // items) — a Collections note, not an acquisition source.
  2387628034,
  // "Source: Earned while leveling." (~291 items) — too vague to be a source.
  2892963218,
};

/// The acquisition source shown in a detail view, in precedence order:
/// 1. our per-item override (`source_overrides.json`, keyed by [itemHash]) —
///    highest, so it can fix even shared-sourceHash "Random Perks" items;
/// 2. d2ai's cleaner text for the collectible's `sourceHash`;
/// 3. the manifest's own `sourceString`.
/// Null (no Source row) when none exists, or when the only "source" is one of
/// the [_nonSourceHashes] non-source notes (unless an override replaces it).
String? resolveItemSource(ManifestRepository manifest, D2aiRepository? d2ai,
    Map<String, dynamic> def, int itemHash) {
  final override = d2ai?.sourceOverrideFor(itemHash);
  if (override != null && override.isNotEmpty) return override;

  final collectibleHash = (def['collectibleHash'] as num?)?.toInt();
  if (collectibleHash == null || collectibleHash == 0) return null;

  final collectible = manifest.getCollectible(collectibleHash);
  final sourceHash = (collectible?['sourceHash'] as num?)?.toInt();
  if (sourceHash != null && _nonSourceHashes.contains(sourceHash)) return null;

  final d2aiText = sourceHash == null ? null : d2ai?.sourceFor(sourceHash);
  if (d2aiText != null && d2aiText.isNotEmpty) return d2aiText;

  final source = collectible?['sourceString'] as String?;
  return (source == null || source.isEmpty) ? null : source;
}

/// The quest this weapon comes from ("From the quest: `<name>`"), resolved from
/// d2ai's weapon→quest-step map and the step's manifest display name. Null when
/// d2ai is not wired, the weapon is not quest-sourced, or the step has no name.
String? resolveQuestOrigin(
    ManifestRepository manifest, D2aiRepository? d2ai, int itemHash) {
  final stepHash = d2ai?.questStepFor(itemHash);
  if (stepHash == null) return null;
  final name = manifest.getInventoryItem(stepHash)?['displayProperties']?['name']
      as String?;
  return (name == null || name.isEmpty) ? null : name;
}
