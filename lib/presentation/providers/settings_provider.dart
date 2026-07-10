import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether item tiles show applied cosmetics (ornament icons) instead of the
/// items' default icons.
final showCosmeticsProvider =
    NotifierProvider<ShowCosmeticsNotifier, bool>(ShowCosmeticsNotifier.new);

class ShowCosmeticsNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}
