import 'item_filter.dart';

/// A single autocomplete suggestion: the full token to insert, plus the text
/// to display (identical for filters; a quoted name: term for item names).
class Suggestion {
  const Suggestion(this.insert, {String? label, this.iconPath})
      : label = label ?? insert;

  /// The token that replaces the current one when selected.
  final String insert;

  /// What to show in the dropdown.
  final String label;

  /// The Bungie icon path for the suggestion (perk suggestions carry one), or
  /// null for filter/name suggestions, which show the default search glyph.
  final String? iconPath;
}

/// A perk offered as a `perk:` value suggestion: its display name and the
/// Bungie icon path shown beside it. Built from the manifest's perk pool.
class PerkOption {
  const PerkOption(this.name, this.iconPath);

  /// The perk's display name, lowercased (matches how `perk:` compares).
  final String name;

  /// The Bungie icon path, or empty when the perk has none.
  final String iconPath;
}

/// The whitespace-delimited token currently being edited (the one containing
/// the cursor). Returns the token text and its [start]/[end] offsets in [text].
({String token, int start, int end}) currentToken(String text, int cursor) {
  final c = cursor.clamp(0, text.length);
  var start = c;
  while (start > 0 && text[start - 1] != ' ') {
    start--;
  }
  var end = c;
  while (end < text.length && text[end] != ' ') {
    end++;
  }
  return (token: text.substring(start, end), start: start, end: end);
}

/// The perk-filter keys that take a perk name as their value, so a value
/// typed after them is completed against the perk catalog.
const _perkKeys = {'perk', 'perk1', 'perk2'};

/// The set-filter keys that take a set-effect (or set) name as their value, so
/// a value typed after them is completed against the set-effect catalog.
const _setKeys = {'set', 'set2', 'set4'};

/// Builds ranked suggestions for [token] against the filter catalog and the
/// given item [names]. Excludes `exactname:` and never echoes raw text.
/// [max] caps the result count. [instanceData] is forwarded to
/// [filterSuggestionCatalog] so the Database tab (false) does not suggest
/// filters that need live account data. [perks], [frames] and [setEffects] are
/// the catalogs (name + icon) used to complete `perk:`/`perk1:`/`perk2:`,
/// `frame:` and `set:`/`set2:`/`set4:` values; each is empty until it is warmed.
List<Suggestion> suggestionsFor(
  String token,
  Iterable<String> names, {
  int max = 8,
  int perkMax = 200,
  bool instanceData = true,
  List<PerkOption> perks = const [],
  List<PerkOption> frames = const [],
  List<PerkOption> setEffects = const [],
}) {
  final t = token.trim().toLowerCase();
  if (t.isEmpty) return const [];

  // A key with a value part (`perk:`, `perk:ram`, `frame:adapt`) completes
  // against the matching catalog: match the value on each entry's name, and
  // offer the full `<key>:"<name>"` token with the entry's icon. A bare
  // `perk:`/`frame:` lists them all (the overlay scrolls). Catalogs are
  // pre-sorted alphabetically, so the order is preserved (destiny.report-style).
  final colon = t.indexOf(':');
  if (colon > 0) {
    final key = t.substring(0, colon);
    final catalog = _perkKeys.contains(key)
        ? perks
        : key == 'frame'
            ? frames
            : _setKeys.contains(key)
                ? setEffects
                : null;
    if (catalog != null) {
      final value = t.substring(colon + 1);
      final matches = <Suggestion>[];
      for (final entry in catalog) {
        if (value.isEmpty || entry.name.contains(value)) {
          matches.add(Suggestion('$key:"${entry.name}"',
              label: '$key:${entry.name}', iconPath: entry.iconPath));
        }
      }
      return matches.take(perkMax).toList();
    }
  }

  final filters = <Suggestion>[];
  for (final entry in filterSuggestionCatalog(instanceData: instanceData)) {
    if (entry.toLowerCase().startsWith(t)) {
      filters.add(Suggestion(entry));
    }
  }
  filters.sort((a, b) => a.insert.length.compareTo(b.insert.length));

  // Item-name matches, offered as name:"..." (never exactname:). Match on the
  // free-text portion: if the user typed name:foo, match on 'foo'; otherwise on
  // the whole bare token.
  final namePartial = t.startsWith('name:') ? t.substring(5) : t;
  final nameMatches = <Suggestion>[];
  if (namePartial.isNotEmpty && !t.startsWith('is:')) {
    final seen = <String>{};
    for (final name in names) {
      if (name.toLowerCase().contains(namePartial) && seen.add(name)) {
        nameMatches.add(Suggestion('name:"$name"', label: 'name:"$name"'));
      }
    }
    nameMatches.sort((a, b) => a.label.length.compareTo(b.label.length));
  }

  return [...filters, ...nameMatches].take(max).toList();
}
