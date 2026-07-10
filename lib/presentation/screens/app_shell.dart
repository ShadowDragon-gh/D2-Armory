import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/search/search_suggestions.dart';
import '../providers/auth_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/search_provider.dart';
import '../providers/settings_provider.dart';
import 'inventory/inventory_screen.dart';
import 'stub_page.dart';

/// Top-level shell with tab navigation and (on the Inventory tab) a search bar.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

enum _Tab { inventory, loadouts, database }

class _AppShellState extends ConsumerState<AppShell> {
  _Tab _tab = _Tab.inventory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            const Text('D2 Loadout Planner'),
            const SizedBox(width: 24),
            _TabButton(
                label: 'Inventory',
                selected: _tab == _Tab.inventory,
                onTap: () => setState(() => _tab = _Tab.inventory)),
            _TabButton(
                label: 'Loadouts',
                selected: _tab == _Tab.loadouts,
                onTap: () => setState(() => _tab = _Tab.loadouts)),
            _TabButton(
                label: 'Database',
                selected: _tab == _Tab.database,
                onTap: () => setState(() => _tab = _Tab.database)),
            if (_tab == _Tab.inventory) ...[
              const SizedBox(width: 24),
              const Expanded(child: _SearchBar()),
            ] else
              const Spacer(),
          ],
        ),
        actions: [
          if (_tab == _Tab.inventory) ...[
            IconButton(
              tooltip: ref.watch(showCosmeticsProvider)
                  ? 'Hide cosmetics'
                  : 'Show cosmetics',
              icon: Icon(ref.watch(showCosmeticsProvider)
                  ? Icons.auto_awesome
                  : Icons.auto_awesome_outlined),
              onPressed: () =>
                  ref.read(showCosmeticsProvider.notifier).toggle(),
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(inventoryGridProvider),
            ),
          ],
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: switch (_tab) {
        _Tab.inventory => const InventoryScreen(),
        _Tab.loadouts => const StubPage(
            title: 'Loadouts',
            icon: Icons.dashboard_customize_outlined,
            message: 'Loadout building is coming soon.'),
        _Tab.database => const StubPage(
            title: 'Database',
            icon: Icons.menu_book_outlined,
            message: 'Item database browsing is coming soon.'),
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor:
              selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends ConsumerStatefulWidget {
  const _SearchBar();

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _overlayController = OverlayPortalController();
  final _link = LayerLink();

  List<Suggestion> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(searchQueryProvider);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Delay so a tap on a suggestion is registered before the overlay hides.
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !_focusNode.hasFocus) _overlayController.hide();
      });
    }
  }

  void _onChanged(String value) {
    ref.read(searchQueryProvider.notifier).set(value);
    _recomputeSuggestions();
  }

  void _recomputeSuggestions() {
    final names = ref.read(itemNamesProvider);
    final tok = currentToken(
        _controller.text, _controller.selection.baseOffset);
    final next = suggestionsFor(tok.token, names);
    setState(() => _suggestions = next);
    if (next.isEmpty) {
      _overlayController.hide();
    } else if (!_overlayController.isShowing) {
      _overlayController.show();
    }
  }

  /// Replace the token under the cursor with [suggestion], preserving the rest
  /// of the query, and append a trailing space so the next term can be typed.
  void _pick(Suggestion suggestion) {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset < 0
        ? text.length
        : _controller.selection.baseOffset;
    final tok = currentToken(text, cursor);
    final before = text.substring(0, tok.start);
    final after = text.substring(tok.end);
    final inserted = '${suggestion.insert} ';
    final newText = '$before$inserted$after';
    final newCursor = before.length + inserted.length;

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    ref.read(searchQueryProvider.notifier).set(newText);
    _overlayController.hide();
    _focusNode.requestFocus();
  }

  void _clear() {
    _controller.clear();
    ref.read(searchQueryProvider.notifier).clear();
    _overlayController.hide();
  }

  @override
  Widget build(BuildContext context) {
    final unsupported = ref.watch(compiledQueryProvider).unsupported;

    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: (context) {
        return CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 4),
          child: Align(
            alignment: Alignment.topLeft,
            child: _SuggestionsOverlay(
              options: _suggestions,
              onPick: _pick,
            ),
          ),
        );
      },
      child: CompositedTransformTarget(
        link: _link,
        child: SizedBox(
          height: 40,
          // Escape clears the filter while the field (a descendant) has focus;
          // key events bubble to this ancestor Focus.
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape &&
                  _controller.text.isNotEmpty) {
                _clear();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: _Field(
              controller: _controller,
              focusNode: _focusNode,
              unsupported: unsupported,
              onChanged: _onChanged,
              onTap: _recomputeSuggestions,
              onClear: _clear,
            ),
          ),
        ),
      ),
    );
  }
}

/// The styled text field, extracted so the field and overlay share it.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.focusNode,
    required this.unsupported,
    required this.onChanged,
    required this.onClear,
    this.onTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> unsupported;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.isNotEmpty;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          onTap: onTap,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            hintText: 'Filter items — e.g. is:solar is:handcannon power:>540',
            hintStyle: const TextStyle(fontSize: 13),
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (unsupported.isNotEmpty)
                  Tooltip(
                    message:
                        'Not supported yet (ignored):\n${unsupported.join('\n')}',
                    child: Icon(Icons.info_outline,
                        size: 18,
                        color: Theme.of(context).colorScheme.tertiary),
                  ),
                if (hasText)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    visualDensity: VisualDensity.compact,
                    onPressed: onClear,
                  ),
              ],
            ),
            border: const OutlineInputBorder(),
          ),
        );
      },
    );
  }
}

/// The dropdown list of suggestions.
class _SuggestionsOverlay extends StatelessWidget {
  const _SuggestionsOverlay({required this.options, required this.onPick});

  final List<Suggestion> options;
  final void Function(Suggestion) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(6),
      color: theme.colorScheme.surfaceContainerHigh,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 320),
        child: ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: options.length,
          itemBuilder: (context, i) {
            final option = options[i];
            return InkWell(
              onTap: () => onPick(option),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(option.label,
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
