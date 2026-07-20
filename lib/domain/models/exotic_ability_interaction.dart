import '../../core/config/app_config.dart';

/// The kind of subclass ability an exotic armor piece interacts with. Maps 1:1
/// to the ability plug-category taxonomy suffixes (`.grenades`, `.melee`,
/// `.supers`, `.class_abilities`/`movement`, `.aspects`/`.totems`), so a
/// subclass socket's category identifier resolves to exactly one token — the
/// join key between a socket and the curated interaction map.
enum AbilityKind {
  grenade('grenade'),
  melee('melee'),
  superAbility('super'),
  classAbility('class_ability'),
  movement('movement'),
  aspect('aspect');

  const AbilityKind(this.token);

  /// The token stored in the curated JSON and derived from a plug category.
  final String token;

  /// The [AbilityKind] for a curated-map [token], or null when unrecognised.
  static AbilityKind? fromToken(String token) {
    for (final kind in values) {
      if (kind.token == token) return kind;
    }
    return null;
  }

  /// The [AbilityKind] for a subclass plug's `plugCategoryIdentifier`, matched
  /// by its suffix. Class-ability and movement sockets both map to
  /// [classAbility] (the game groups them as the class-ability slot; the
  /// curated map treats a movement interaction as a class-ability one).
  /// Aspects use `.aspects`/`.totems` (Stasis's pre-3.0 name); fragments and
  /// supers likewise. Null for a socket that is not an ability (e.g. an
  /// artifice cosmetic) or an unrecognised category.
  static AbilityKind? fromPlugCategory(String? plugCategoryIdentifier) {
    final id = (plugCategoryIdentifier ?? '').toLowerCase();
    if (id.isEmpty) return null;
    if (id.endsWith('.grenades')) return grenade;
    if (id.endsWith('.melee')) return melee;
    if (id.endsWith('.supers')) return superAbility;
    if (id.endsWith('.class_abilities') || id.endsWith('.movement')) {
      return classAbility;
    }
    if (id.endsWith('.aspects') || id.endsWith('.totems')) return aspect;
    return null;
  }
}

/// One interaction an exotic declares with an ability [kind], with optional
/// scoping so a badge is specific rather than "any ability of this kind":
///  - [names]: only the named abilities (e.g. Ballidorse's `Winter's Wrath`),
///    matched case-insensitively against a socket's plug names. Empty means the
///    interaction is not name-scoped.
///  - [element]: only a subclass of this damage-type element (e.g. Crown of
///    Tempests' Arc-only grenade/melee synergy). Null means any element.
/// An interaction with neither is type-level (any ability of [kind]).
class AbilityInteraction {
  const AbilityInteraction({
    required this.kind,
    this.names = const [],
    this.element,
  });

  final AbilityKind kind;
  final List<String> names;
  final int? element;

  /// Whether this interaction names specific abilities — the "definitive,
  /// by-name" kind that earns an on-ability badge (e.g. Skull of Dire Ahamkara →
  /// Nova Bomb). A non-name-scoped interaction ("any melee", "any Arc grenade")
  /// is general and belongs in the modal's general-exotics column instead.
  bool get isNameScoped => names.isNotEmpty;

  /// Whether this name-scoped interaction applies to a socket of [socketKind]
  /// holding one of [socketPlugNames] on a subclass of [socketElement]: the kind
  /// and (if set) element must match, and at least one socket plug name must
  /// match one of [names] (case-insensitive). Always false for a general
  /// interaction (no names) — those are not badged on an ability.
  bool matchesNamedSocket(
    AbilityKind socketKind,
    Iterable<String> socketPlugNames,
    int socketElement,
  ) {
    if (!isNameScoped) return false;
    if (kind != socketKind) return false;
    if (element != null && element != socketElement) return false;
    final wanted = {for (final n in names) n.toLowerCase()};
    for (final plugName in socketPlugNames) {
      if (wanted.contains(plugName.toLowerCase())) return true;
    }
    return false;
  }

  /// The subset of this interaction's [names] present in [socketPlugNames] for a
  /// socket of [socketKind] on a subclass of [socketElement] — the specific
  /// abilities this exotic buffs that the socket can hold. Empty for a general
  /// interaction, a kind/element mismatch, or no name overlap.
  List<String> matchedNames(
    AbilityKind socketKind,
    Iterable<String> socketPlugNames,
    int socketElement,
  ) {
    if (!isNameScoped) return const [];
    if (kind != socketKind) return const [];
    if (element != null && element != socketElement) return const [];
    final available = {for (final p in socketPlugNames) p.toLowerCase()};
    return [
      for (final n in names)
        if (available.contains(n.toLowerCase())) n,
    ];
  }

  /// Whether this general (non-name-scoped) interaction applies to ability
  /// [socketKind] on a subclass of [socketElement] — for the general-exotics
  /// column. Always false for a name-scoped interaction (those are badged).
  bool matchesGeneral(AbilityKind socketKind, int socketElement) {
    if (isNameScoped) return false;
    if (kind != socketKind) return false;
    if (element != null && element != socketElement) return false;
    return true;
  }
}

/// One exotic armor piece and the subclass abilities it interacts with, from
/// the curated `exotic_armor_abilities.json` map. Carries what the badge tooltip
/// needs — the exotic's name and icon — plus its [classType] so an ability is
/// only flagged with exotics its own class can wear.
class ExoticAbilityInteraction {
  const ExoticAbilityInteraction({
    required this.itemHash,
    required this.name,
    required this.classType,
    required this.interactions,
    this.iconPath,
    this.perkHash,
    this.description = '',
  });

  final int itemHash;
  final String name;

  /// The exotic's `classType` (0 Titan, 1 Hunter, 2 Warlock, 3 any).
  final int classType;

  /// The scoped interactions this exotic declares.
  final List<AbilityInteraction> interactions;

  /// The exotic's manifest icon path, resolved by the repository at load time
  /// (the curated JSON carries none). Null when unavailable.
  final String? iconPath;

  /// The exotic's intrinsic-perk plug hash — the key into Clarity's insight
  /// database — resolved from the manifest at load time. Null when the manifest
  /// is unavailable or the perk can't be found.
  final int? perkHash;

  /// The exotic intrinsic perk's manifest description (its effect text). Empty
  /// when the manifest carries none (some exotics' effect lives only in Clarity).
  final String description;

  String? get iconUrl =>
      (iconPath == null || iconPath!.isEmpty)
          ? null
          : '${AppConfig.bungieBaseUrl}$iconPath';

  /// Whether an exotic of this [classType] can be worn by a subclass of
  /// [subclassClassType]. A class-agnostic exotic (`classType == 3`) matches
  /// any subclass.
  bool matchesClass(int subclassClassType) =>
      classType == 3 || classType == subclassClassType;

  /// Whether any of this exotic's *name-scoped* interactions applies to a socket
  /// of [socketKind] holding [socketPlugNames] on a subclass of [socketElement]
  /// — i.e. whether it earns an on-ability badge there.
  bool matchesNamedSocket(
    AbilityKind socketKind,
    Iterable<String> socketPlugNames,
    int socketElement,
  ) =>
      interactions.any(
        (i) => i.matchesNamedSocket(socketKind, socketPlugNames, socketElement),
      );

  /// The specific abilities this exotic buffs that a socket of [socketKind] on
  /// a subclass of [socketElement] can hold (from [socketPlugNames]) — the
  /// subtitle for a name-scoped entry in the ability column, in first-seen
  /// order, de-duplicated. Empty when it has no name-scoped match here.
  List<String> matchedNames(
    AbilityKind socketKind,
    Iterable<String> socketPlugNames,
    int socketElement,
  ) {
    final seen = <String>{};
    final out = <String>[];
    for (final i in interactions) {
      for (final n in i.matchedNames(socketKind, socketPlugNames, socketElement)) {
        if (seen.add(n.toLowerCase())) out.add(n);
      }
    }
    return out;
  }

  /// Whether any of this exotic's *general* (non-name-scoped) interactions
  /// applies to ability [socketKind] on a subclass of [socketElement] — i.e.
  /// whether it belongs in the general-exotics column for that ability.
  bool matchesGeneral(AbilityKind socketKind, int socketElement) =>
      interactions.any((i) => i.matchesGeneral(socketKind, socketElement));

  /// The distinct ability kinds this exotic *generally* (non-name-scoped)
  /// affects on a subclass of [socketElement], in the enum's declared order.
  /// Element-gated interactions count only when the element matches.
  List<AbilityKind> generalKinds(int socketElement) => [
        for (final k in AbilityKind.values)
          if (matchesGeneral(k, socketElement)) k,
      ];

  /// Whether this exotic is a *broad synergy* piece for a subclass of
  /// [socketElement]: its general interactions span two or more ability kinds
  /// (e.g. Crown of Tempests → Arc grenade + melee + super). Such exotics list
  /// once in the modal's synergy section rather than repeating under each kind.
  bool isSynergy(int socketElement) => generalKinds(socketElement).length >= 2;
}
