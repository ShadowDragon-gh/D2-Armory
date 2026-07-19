import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/d2ai_repository.dart';

/// DIM's d2-additional-info source data (bundled MIT asset). A plain singleton;
/// [d2aiBootstrapProvider] loads it.
final d2aiRepositoryProvider = Provider<D2aiRepository>((ref) {
  return D2aiRepository();
});

/// Loads the bundled d2ai snapshot once. Watched by [appWarmupProvider] so it
/// warms at startup, and by the detail providers so the Source row re-resolves
/// (picking up d2ai's cleaner text) once the small asset finishes parsing.
final d2aiBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.watch(d2aiRepositoryProvider).ensureLoaded();
});
