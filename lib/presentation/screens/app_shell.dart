import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/destiny/destiny_buckets.dart';
import '../providers/auth_provider.dart';
import '../providers/database_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/search_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/armory_palette.dart';
import '../theme/branding_svg.dart';
import '../widgets/about_dialog.dart';
import '../widgets/search_bar_field.dart';
import '../widgets/update_banner.dart';
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
            SvgPicture.string(
              kArmoryIconSvg,
              width: 40,
              height: 40,
            ),
            const SizedBox(width: 12),
            SvgPicture.string(
              kArmoryWordmarkSvg,
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
              tooltip: ref.watch(showTierProvider)
                  ? 'Hide gear tier'
                  : 'Show gear tier',
              icon: Icon(ref.watch(showTierProvider)
                  ? Icons.diamond
                  : Icons.diamond_outlined),
              onPressed: () => ref.read(showTierProvider.notifier).toggle(),
            ),
            const _RefreshButton(),
          ],
          const UpdateAction(),
          IconButton(
            tooltip: 'About',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showAppAboutDialog(context),
          ),
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

/// The inventory refresh button. Its icon spins continuously while the profile
/// refetch is in flight (the grid provider is loading), then stops. The spin
/// tracks only the inventory refresh — the filter/facet warm is a separate
/// provider and does not drive it.
class _RefreshButton extends ConsumerStatefulWidget {
  const _RefreshButton();

  @override
  ConsumerState<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends ConsumerState<_RefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(inventoryGridProvider).isLoading;
    // Repeat while refreshing; when it ends, let the current turn finish so the
    // icon settles upright rather than stopping mid-rotation. Guard the stop on
    // still-idle so a refresh that restarts before the turn completes keeps
    // spinning.
    if (loading) {
      if (!_spin.isAnimating) _spin.repeat();
    } else if (_spin.isAnimating) {
      _spin.forward(from: _spin.value).whenComplete(() {
        if (!ref.read(inventoryGridProvider).isLoading) _spin.stop();
      });
    }
    return IconButton(
      tooltip: 'Refresh',
      icon: RotationTransition(
        turns: _spin,
        child: const Icon(Icons.refresh),
      ),
      // Ignore taps while a refresh is already running.
      onPressed:
          loading ? null : () => ref.invalidate(inventoryGridProvider),
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
      perks: ref.watch(perkCatalogProvider),
      frames: ref.watch(frameCatalogProvider),
      setEffects: ref.watch(setEffectCatalogProvider),
      // The owned-item facet warm gates perk:/stat:/source:/catalyst: search;
      // the perk autocomplete waits on the Database weapon warm. Show the
      // spinner while either is still running.
      warming: ref.watch(inventoryFacetsWarmProvider).isLoading ||
          ref.watch(databaseFacetsWarmProvider(GearKind.weapon)).isLoading,
      unsupported: unsupported,
      onChanged: (v) => ref.read(searchQueryProvider.notifier).set(v),
    );
  }
}
