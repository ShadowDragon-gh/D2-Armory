import 'dart:convert';
import 'dart:io';

import '../../domain/models/clarity_insight.dart';

/// Parse the cached Clarity descriptions file into the in-memory insight map,
/// keyed by the perk's inventory-item hash.
///
/// Top-level (not a method) so it can run via `Isolate.run` without capturing
/// an enclosing `this` — the ~1.6 MB decode would otherwise jank the UI
/// isolate during startup. Entries that fail to parse are skipped.
Map<int, ClarityInsight> parseClarityFile(String path) {
  final raw = File(path).readAsStringSync();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final insights = <int, ClarityInsight>{};
  for (final entry in json.values) {
    if (entry is! Map<String, dynamic>) continue;
    final insight = ClarityInsight.fromJson(entry);
    if (insight != null) insights[insight.hash] = insight;
  }
  return insights;
}
