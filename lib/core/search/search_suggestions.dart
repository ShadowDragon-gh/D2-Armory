import 'item_filter.dart';

/// A single autocomplete suggestion: the full token to insert, plus the text
/// to display (identical for filters; a quoted name: term for item names).
class Suggestion {
  const Suggestion(this.insert, {String? label}) : label = label ?? insert;

  /// The token that replaces the current one when selected.
  final String insert;

  /// What to show in the dropdown.
  final String label;
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

/// Builds ranked suggestions for [token] against the filter catalog and the
/// given item [names]. Excludes `exactname:` and never echoes raw text.
/// [max] caps the result count. [instanceData] is forwarded to
/// [filterSuggestionCatalog] so the Database tab (false) does not suggest
/// filters that need live account data.
List<Suggestion> suggestionsFor(
  String token,
  Iterable<String> names, {
  int max = 8,
  bool instanceData = true,
}) {
  final t = token.trim().toLowerCase();
  if (t.isEmpty) return const [];

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
