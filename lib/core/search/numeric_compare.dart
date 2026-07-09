/// Parses a DIM-style numeric comparison such as `>540`, `<=500`, `=10`, or a
/// bare `540` (treated as equality), into a predicate over an int value.
///
/// Returns null when [expr] is not a valid comparison.
bool Function(int)? parseNumericCompare(String expr) {
  final match = RegExp(r'^(<=|>=|<|>|=)?(\d+)$').firstMatch(expr.trim());
  if (match == null) return null;
  final op = match.group(1) ?? '=';
  final n = int.parse(match.group(2)!);
  return switch (op) {
    '<' => (v) => v < n,
    '>' => (v) => v > n,
    '<=' => (v) => v <= n,
    '>=' => (v) => v >= n,
    _ => (v) => v == n,
  };
}
