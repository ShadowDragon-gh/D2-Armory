/// A single parsed search term, e.g. `is:solar`, `power:>540`, `name:"foo"`,
/// or a bare keyword. Terms are combined with AND.
class SearchTerm {
  const SearchTerm({
    required this.raw,
    required this.key,
    required this.value,
    this.negated = false,
  });

  /// The original text of this term (for error reporting).
  final String raw;

  /// Filter key, lower-cased (e.g. 'is', 'power', 'name'), or empty for a bare
  /// keyword.
  final String key;

  /// Everything after the first colon (e.g. 'solar', '>540', 'foo'), or the
  /// keyword itself when [key] is empty.
  final String value;

  final bool negated;
}

/// Splits a raw query string into [SearchTerm]s. Handles:
///   is:solar   power:>540   name:"two words"   -is:exotic   not:masterwork
/// Whitespace separates terms; double quotes group a value with spaces.
List<SearchTerm> tokenizeQuery(String input) {
  final terms = <SearchTerm>[];
  final tokens = _splitRespectingQuotes(input.trim());

  for (final token in tokens) {
    if (token.isEmpty) continue;

    var raw = token;
    var negated = false;
    if (raw.startsWith('-')) {
      negated = true;
      raw = raw.substring(1);
    }

    final colon = raw.indexOf(':');
    if (colon <= 0) {
      // Bare keyword (no key). Strip surrounding quotes if present.
      terms.add(SearchTerm(
        raw: token,
        key: '',
        value: _unquote(raw),
        negated: negated,
      ));
      continue;
    }

    var key = raw.substring(0, colon).toLowerCase();
    final value = _unquote(raw.substring(colon + 1));

    // `not:foo` is an alternative negation spelling.
    if (key == 'not') {
      terms.add(SearchTerm(raw: token, key: '', value: value, negated: true));
      continue;
    }

    terms.add(SearchTerm(
      raw: token,
      key: key,
      value: value,
      negated: negated,
    ));
  }
  return terms;
}

List<String> _splitRespectingQuotes(String input) {
  final result = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < input.length; i++) {
    final c = input[i];
    if (c == '"') {
      inQuotes = !inQuotes;
      buffer.write(c);
    } else if (c == ' ' && !inQuotes) {
      if (buffer.isNotEmpty) {
        result.add(buffer.toString());
        buffer.clear();
      }
    } else {
      buffer.write(c);
    }
  }
  if (buffer.isNotEmpty) result.add(buffer.toString());
  return result;
}

String _unquote(String s) {
  if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
    return s.substring(1, s.length - 1);
  }
  return s;
}
