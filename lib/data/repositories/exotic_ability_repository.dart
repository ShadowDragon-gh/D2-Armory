import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:logger/logger.dart';

import '../../domain/models/exotic_ability_interaction.dart';
import 'manifest_repository.dart';

/// Serves the curated exotic-armor → subclass-ability interaction map (which
/// exotics buff/interact with each ability kind), for the subclass modal's
/// "an exotic interacts with this ability" badge.
///
/// The map is a bundled asset (`assets/data/exotic_armor_abilities.json`),
/// keyed by unsigned exotic itemHash. Neither the Bungie manifest nor Clarity
/// expresses this link structurally, so it is hand-curated (bootstrapped from
/// Clarity prose). Exotic icons are not in the asset; they are resolved from the
/// manifest on load. This is pure enrichment: every failure degrades to "no
/// interactions" with a logged warning — the modal must never depend on it.
class ExoticAbilityRepository {
  ExoticAbilityRepository({required this._manifest, Logger? logger})
      : _log = logger ?? Logger();

  final ManifestRepository _manifest;
  final Logger _log;

  /// The interacting exotics indexed by ability kind — a coarse first filter;
  /// the fine name/element/class match runs per query. Empty until
  /// [ensureLoaded] succeeds.
  Map<AbilityKind, List<ExoticAbilityInteraction>> _byAbility = const {};

  bool get isReady => _byAbility.isNotEmpty;

  /// The exotics that *definitively, by name* interact with a subclass socket:
  /// one of ability [kind] whose shown plug is named in [socketPlugNames] (the
  /// caller passes the currently-shown plug, so the badge tracks the equipped
  /// ability rather than every option the socket could hold), on a subclass of
  /// [subclassClassType] and [subclassElement]. These earn an on-ability badge.
  /// General (any-melee/any-Arc-grenade) exotics are excluded here — see
  /// [generalExoticsFor]. Empty when none, or the map is not loaded.
  List<ExoticAbilityInteraction> exoticsFor(
    AbilityKind kind,
    int subclassClassType,
    int subclassElement,
    Iterable<String> socketPlugNames,
  ) {
    final all = _byAbility[kind];
    if (all == null) return const [];
    return [
      for (final e in all)
        if (e.matchesClass(subclassClassType) &&
            e.matchesNamedSocket(kind, socketPlugNames, subclassElement))
          e,
    ];
  }

  /// The exotics with a *general* (not name-scoped) interaction with ability
  /// [kind] for a subclass of [subclassClassType] and [subclassElement] — the
  /// per-kind rows of the modal's general-exotics column. Element-gated exotics
  /// are included only when the subclass element matches. Broad-synergy exotics
  /// (general across 2+ kinds) are *excluded* here — they list once in the
  /// synergy section ([synergyExoticsFor]) instead of repeating per kind. Empty
  /// when none, or the map is not loaded.
  List<ExoticAbilityInteraction> generalExoticsFor(
    AbilityKind kind,
    int subclassClassType,
    int subclassElement,
  ) {
    final all = _byAbility[kind];
    if (all == null) return const [];
    return [
      for (final e in all)
        if (e.matchesClass(subclassClassType) &&
            e.matchesGeneral(kind, subclassElement) &&
            !e.isSynergy(subclassElement))
          e,
    ];
  }

  /// The name-scoped exotics to list in ability [kind]'s column for a socket
  /// holding [socketPlugNames] on a subclass of [subclassClassType] and
  /// [subclassElement] — each paired with the specific abilities it buffs that
  /// the socket can hold (its subtitle). Unlike [exoticsFor] (the equipped-only
  /// badge), this is a discovery listing: an exotic shows whenever the socket
  /// *can* hold one of its named abilities. Name-sorted; empty when none, or the
  /// map is not loaded.
  List<({ExoticAbilityInteraction exotic, List<String> names})>
      namedColumnExoticsFor(
    AbilityKind kind,
    int subclassClassType,
    int subclassElement,
    Iterable<String> socketPlugNames,
  ) {
    final all = _byAbility[kind];
    if (all == null) return const [];
    final result = <({ExoticAbilityInteraction exotic, List<String> names})>[];
    for (final e in all) {
      if (!e.matchesClass(subclassClassType)) continue;
      final names = e.matchedNames(kind, socketPlugNames, subclassElement);
      if (names.isNotEmpty) result.add((exotic: e, names: names));
    }
    result.sort((a, b) => a.exotic.name.compareTo(b.exotic.name));
    return result;
  }

  /// The broad-synergy exotics for a subclass of [subclassClassType] and
  /// [subclassElement]: those whose general interactions span two or more
  /// ability kinds (e.g. Crown of Tempests → Arc grenade/melee/super). These
  /// populate the modal's dedicated synergy section, listed once each rather
  /// than repeated under every affected kind. Name-sorted; empty when none, or
  /// the map is not loaded.
  List<ExoticAbilityInteraction> synergyExoticsFor(
    int subclassClassType,
    int subclassElement,
  ) {
    // De-dup across the per-kind index (a synergy exotic is indexed under each
    // of its kinds), keyed by itemHash.
    final seen = <int>{};
    final result = <ExoticAbilityInteraction>[];
    for (final list in _byAbility.values) {
      for (final e in list) {
        if (!e.matchesClass(subclassClassType)) continue;
        if (!e.isSynergy(subclassElement)) continue;
        if (seen.add(e.itemHash)) result.add(e);
      }
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  /// Load and parse the bundled map, resolving each exotic's icon from the
  /// manifest, then build the per-ability inverse index. Idempotent; never
  /// throws — a missing/unparseable asset leaves the map empty.
  Future<void> ensureLoaded() async {
    if (_byAbility.isNotEmpty) return;

    final Map<String, dynamic> raw;
    try {
      final text = await rootBundle
          .loadString('assets/data/exotic_armor_abilities.json');
      raw = jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      _log.w('Could not load the exotic-ability map: $e');
      return;
    }

    final byAbility = <AbilityKind, List<ExoticAbilityInteraction>>{};
    for (final entry in raw.entries) {
      final interaction = _parse(entry.key, entry.value);
      // Each parse costs a handful of synchronous manifest decodes on the UI
      // isolate; yield between entries so frames interleave with the load.
      await Future<void>.delayed(Duration.zero);
      if (interaction == null) continue;
      // Index under each distinct kind it interacts with (the coarse filter).
      for (final kind in interaction.interactions.map((i) => i.kind).toSet()) {
        (byAbility[kind] ??= []).add(interaction);
      }
    }
    // Stable, name-sorted per ability so tooltips read consistently.
    for (final list in byAbility.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    _byAbility = byAbility;
    _log.i('Exotic-ability map loaded: ${raw.length} exotics.');
  }

  /// Parse one `{name, classType, abilities:[{kind, names?, element?}]}` entry
  /// keyed by its unsigned itemHash string, resolving its icon from the
  /// manifest. Null when the hash is unparseable or it declares no recognised
  /// interaction.
  ExoticAbilityInteraction? _parse(String hashKey, Object? value) {
    final itemHash = int.tryParse(hashKey);
    if (itemHash == null || value is! Map) return null;
    final interactions = <AbilityInteraction>[
      for (final a in (value['abilities'] as List? ?? const []))
        if (a is Map)
          if (AbilityKind.fromToken('${a['kind']}') case final AbilityKind k)
            AbilityInteraction(
              kind: k,
              names: [
                for (final n in (a['names'] as List? ?? const [])) '$n',
              ],
              element: (a['element'] as num?)?.toInt(),
            ),
    ];
    if (interactions.isEmpty) return null;
    // Resolve the icon + intrinsic perk from the manifest; degrade gracefully if
    // it is not open (the name still shows). ensureLoaded gates on the manifest,
    // so the catch is a belt-and-braces guard rather than the expected path.
    String? iconPath;
    int? perkHash;
    var description = '';
    try {
      final def = _manifest.getInventoryItem(itemHash);
      iconPath = def?['displayProperties']?['icon'] as String?;
      final perk = _intrinsicPerkDef(def);
      if (perk != null) {
        perkHash = (perk['hash'] as num?)?.toInt();
        description =
            (perk['displayProperties']?['description'] as String?) ?? '';
      }
    } catch (_) {
      // leave icon/perk/description at their defaults
    }
    return ExoticAbilityInteraction(
      itemHash: itemHash,
      name: (value['name'] as String?) ?? '',
      classType: (value['classType'] as num?)?.toInt() ?? 3,
      interactions: interactions,
      iconPath: iconPath,
      perkHash: perkHash,
      description: description,
    );
  }

  /// The exotic armor's intrinsic-perk plug definition — the named `intrinsics`-
  /// classed plug (the exotic's effect, e.g. "Chaotic Exchanger"). The intrinsic
  /// socket is identified by its *initial* plug being `intrinsics`-classed; only
  /// that socket's candidates (initial + inline reusables + plug set) are
  /// scanned, because the other sockets' plug sets are enormous (every armor
  /// mod, shader, ornament — ~1,700 manifest decodes per exotic) and can never
  /// hold the intrinsic. The initial plug is often an empty-named placeholder,
  /// so the first candidate with a non-empty name wins. Null when none.
  Map<String, dynamic>? _intrinsicPerkDef(Map<String, dynamic>? def) {
    final entries = def?['sockets']?['socketEntries'];
    if (entries is! List) return null;
    for (final entry in entries) {
      if (entry is! Map) continue;
      final init = (entry['singleInitialItemHash'] as num?)?.toInt();
      if (init == null || init == 0) continue;
      final initPlug = _manifest.getInventoryItem(init);
      if (initPlug?['plug']?['plugCategoryIdentifier'] != 'intrinsics') {
        continue;
      }
      final initName = initPlug?['displayProperties']?['name'] as String?;
      if (initName != null && initName.isNotEmpty) return initPlug;
      for (final plugHash in _candidatePlugHashes(entry)) {
        final plug = _manifest.getInventoryItem(plugHash);
        final pci = plug?['plug']?['plugCategoryIdentifier'] as String?;
        final name = plug?['displayProperties']?['name'] as String?;
        if (pci == 'intrinsics' && name != null && name.isNotEmpty) {
          return plug;
        }
      }
    }
    return null;
  }

  /// Every plug hash a socket [entry] can hold: its initial plug, inline
  /// reusable plugs, and its reusable plug set's items.
  Iterable<int> _candidatePlugHashes(Map entry) sync* {
    final init = (entry['singleInitialItemHash'] as num?)?.toInt();
    if (init != null && init != 0) yield init;
    final inline = entry['reusablePlugItems'];
    if (inline is List) {
      for (final r in inline) {
        final h = ((r as Map)['plugItemHash'] as num?)?.toInt();
        if (h != null && h != 0) yield h;
      }
    }
    final setHash = (entry['reusablePlugSetHash'] as num?)?.toInt();
    final setItems =
        setHash == null ? null : _manifest.getPlugSet(setHash)?['reusablePlugItems'];
    if (setItems is List) {
      for (final r in setItems) {
        final h = ((r as Map)['plugItemHash'] as num?)?.toInt();
        if (h != null && h != 0) yield h;
      }
    }
  }
}
