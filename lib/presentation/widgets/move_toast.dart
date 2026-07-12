import 'package:flutter/material.dart';

import '../providers/inventory_provider.dart';
import '../theme/armory_palette.dart';

/// Shows a slide-in toast in the top-right corner reporting a move [outcome],
/// styled to read success vs failure at a glance. Self-dismissing: it animates
/// in, holds, animates out, and removes itself from the overlay.
///
/// Uses an [OverlayEntry] rather than a SnackBar so it can sit at a fixed
/// top-right screen position, above the grid and detail panel.
void showMoveToast(BuildContext context, MoveOutcome outcome) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) =>
        _MoveToast(outcome: outcome, onDismissed: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _MoveToast extends StatefulWidget {
  const _MoveToast({required this.outcome, required this.onDismissed});

  final MoveOutcome outcome;
  final VoidCallback onDismissed;

  @override
  State<_MoveToast> createState() => _MoveToastState();
}

class _MoveToastState extends State<_MoveToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0.35, 0),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  /// How long the toast stays fully visible before sliding out.
  static const _hold = Duration(milliseconds: 3200);

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await _controller.forward();
    await Future<void>.delayed(_hold);
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = widget.outcome.ok;
    final accent = ok ? ArmoryPalette.success : ArmoryPalette.danger;
    final bg = ok ? ArmoryPalette.successBg : ArmoryPalette.dangerBg;
    final icon = ok ? Icons.check_circle_rounded : Icons.error_rounded;
    final label = ok ? 'Move complete' : 'Move failed';

    return Positioned(
      top: 16,
      right: 16,
      child: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Material(
              type: MaterialType.transparency,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: ArmoryRadius.md,
                    border: Border.all(color: accent.withValues(alpha: 0.6)),
                    boxShadow: ArmoryShadows.lg,
                  ),
                  // IntrinsicHeight gives the stretched accent bar a concrete
                  // height from the text column (the toast floats in the
                  // overlay with loose, unbounded height otherwise).
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // A solid accent bar down the leading edge so success
                        // vs failure reads even at a glance / peripherally.
                        Container(
                          width: 4,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: const BorderRadius.horizontal(
                              left: ArmoryRadius.mdRadius,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(icon, color: accent, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        style: const TextStyle(
                                          fontFamily: ArmoryFonts.display,
                                          color: ArmoryPalette.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.outcome.message,
                                        style: const TextStyle(
                                          color: ArmoryPalette.textSecondary,
                                          fontSize: 12.5,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
