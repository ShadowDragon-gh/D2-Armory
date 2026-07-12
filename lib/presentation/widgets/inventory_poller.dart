import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/inventory_provider.dart';

/// Keeps the inventory grid near-live while the window is open by refreshing the
/// profile on an interval, the way DIM's auto-refresh does. It renders nothing
/// (returns [child] unchanged) — it exists to own the poll timer and window
/// focus listener for the lifetime of the inventory screen.
///
/// The poll stands down when it would be wasteful or disruptive: while the
/// window is unfocused, while a move is in flight (a refetch could clobber the
/// in-memory patch before the POST settles), while a tile is being dragged, and
/// until the grid has first loaded. Regaining focus triggers an immediate
/// refresh so returning to the app shows current data at once.
class InventoryPoller extends ConsumerStatefulWidget {
  const InventoryPoller({super.key, required this.child});

  final Widget child;

  /// Matches DIM's default `destinyProfileRefreshInterval` (120s).
  static const Duration interval = Duration(seconds: 120);

  @override
  ConsumerState<InventoryPoller> createState() => _InventoryPollerState();
}

class _InventoryPollerState extends ConsumerState<InventoryPoller>
    with WindowListener {
  Timer? _timer;
  bool _focused = true;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _timer = Timer.periodic(InventoryPoller.interval, (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowBlur() => _focused = false;

  @override
  void onWindowFocus() {
    _focused = true;
    // Show current data immediately on return, like DIM's refresh-on-visible.
    _tick();
  }

  void _tick() {
    if (!_focused) return;
    if (ref.read(moveControllerProvider.notifier).inFlight) return;
    if (ref.read(isDraggingProvider)) return;
    final grid = ref.read(inventoryGridProvider);
    if (!grid.hasValue) return; // not loaded yet / first fetch still running
    // refresh() is staleness-guarded and keeps the current grid visible while
    // it runs (no loading state), so a poll never flickers the screen.
    ref.read(inventoryGridProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
