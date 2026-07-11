import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/search/item_filter.dart';
import '../../domain/models/destiny_item.dart';
import 'inventory_provider.dart';

/// The raw search text the user has typed.
final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
    SearchQueryNotifier.new);

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
  void clear() => state = '';
}

/// How many copies of each item hash the account owns, tallied across every
/// character and the vault. Backs the inventory `count:` filter. Empty until
/// the grid has loaded; recomputed only when the grid changes (not per
/// keystroke).
final _ownedCountProvider = Provider<Map<int, int>>((ref) {
  final grid = ref.watch(inventoryGridProvider).value;
  if (grid == null) return const {};
  final counts = <int, int>{};
  for (final owner in grid.owners) {
    for (final list in owner.itemsByBucket.values) {
      for (final item in list) {
        counts[item.itemHash] = (counts[item.itemHash] ?? 0) + 1;
      }
    }
  }
  return counts;
});

/// The compiled query derived from [searchQueryProvider]. `count:` reads the
/// owned-copy tally; the definition/instance-backed filters
/// (perk/stat/source/breaker/description/keyword/catalyst) read facets resolved
/// lazily per item from the live inventory. Recompiled only when the query text
/// or the owned-count tally changes — the resolvers are stable closures over the
/// repository, so they don't force a recompile per keystroke.
final compiledQueryProvider = Provider<CompiledQuery>((ref) {
  final raw = ref.watch(searchQueryProvider);
  final counts = ref.watch(_ownedCountProvider);
  final repo = ref.watch(inventoryRepositoryProvider);
  return compileQuery(
    raw,
    facetsOf: (DestinyItem item) => repo.inventoryFacetsFor(item),
    countOf: (item) => counts[item.itemHash] ?? 0,
  );
});
