import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/search/item_filter.dart';

/// The raw search text the user has typed.
final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
    SearchQueryNotifier.new);

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
  void clear() => state = '';
}

/// The compiled query derived from [searchQueryProvider]. Recompiled only when
/// the text changes.
final compiledQueryProvider = Provider<CompiledQuery>((ref) {
  final raw = ref.watch(searchQueryProvider);
  return compileQuery(raw);
});
