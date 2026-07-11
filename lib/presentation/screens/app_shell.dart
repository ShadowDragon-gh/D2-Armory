import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../providers/auth_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/search_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/armory_palette.dart';
import '../widgets/search_bar_field.dart';
import 'database/database_screen.dart';
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
            SvgPicture.asset(
              'assets/branding/logo-icon-transparent.svg',
              width: 40,
              height: 40,
            ),
            const SizedBox(width: 12),
            SvgPicture.asset(
              'assets/branding/logo-wordmark-transparent.svg',
              height: 48,
            ),
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
      // IndexedStack keeps every tab's subtree alive and shows the selected
      // one, so navigating back to a tab reveals its already-built widgets
      // instead of re-inflating them. The inventory grid is large and not
      // virtualised, so rebuilding it on every visit caused a visible freeze;
      // building it once removes that. Order matches [_Tab.index].
      body: IndexedStack(
        index: _tab.index,
        children: const [
          InventoryScreen(),
          StubPage(
              title: 'Loadouts',
              icon: Icons.dashboard_customize_outlined,
              message: 'Loadout building is coming soon.'),
          DatabaseScreen(),
        ],
      ),
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
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: ArmoryFonts.display,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

/// The Inventory tab's search bar: the shared [SearchBarField] bound to the
/// inventory query, its item-name autocomplete, and its unsupported terms.
class _SearchBar extends ConsumerWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unsupported = ref.watch(compiledQueryProvider).unsupported;
    return SearchBarField(
      text: ref.watch(searchQueryProvider),
      names: ref.watch(itemNamesProvider),
      unsupported: unsupported,
      onChanged: (v) => ref.read(searchQueryProvider.notifier).set(v),
    );
  }
}
