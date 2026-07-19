import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:d2_armory/core/destiny/destiny_buckets.dart';
import 'package:d2_armory/core/destiny/plug_category.dart';
import 'package:d2_armory/core/search/item_filter.dart';
import 'package:d2_armory/core/search/search_suggestions.dart';
import 'package:d2_armory/data/repositories/database_repository.dart';
import 'package:d2_armory/domain/models/clarity_insight.dart';
import 'package:d2_armory/domain/models/destiny_item.dart';
import 'package:d2_armory/domain/models/armor_set.dart';
import 'package:d2_armory/domain/models/item_detail.dart';
import 'package:d2_armory/presentation/providers/clarity_provider.dart';
import 'package:d2_armory/presentation/providers/database_provider.dart';
import 'package:d2_armory/presentation/providers/inventory_provider.dart';
import 'package:d2_armory/presentation/providers/search_provider.dart';
import 'package:d2_armory/presentation/screens/database/database_screen.dart';

/// One weapon whose definition has Range 60 and a +20 Range perk in a "Barrel"
/// column, so the definition view stays distinguishable from the rolled view.
class _Repo implements DatabaseRepository {
  static GearSummary summary(int hash) => GearSummary(
        itemHash: hash,
        name: hash == 1 ? 'Fatebringer' : 'Other',
        iconPath: '',
        tierType: 6,
        itemType: 3,
        itemSubType: 9,
        itemTypeDisplayName: 'Weapon',
        classType: 3,
        damageType: 0,
        ammoType: 1,
        bucketHash: 1498876634,
        index: hash,
      );

  @override
  List<GearSummary> listGear(GearFilter filter) => [summary(1)];

  @override
  GearDetail? resolveGearDetail(int itemHash) => GearDetail(
        item: summary(itemHash).toDestinyItem(),
        stats: const [ItemStat(statHash: 7, name: 'Range', value: 60)],
        perkColumns: const [
          PerkColumn(label: 'Barrel', plugs: [
            ItemPlug(
              name: 'Rampage',
              iconPath: '',
              category: PlugCategory.perk,
              statEffects: [PerkStatEffect(hash: 7, name: 'Range', value: 20)],
            ),
          ]),
        ],
      );

  @override
  SearchFacets? facetsFor(GearKind kind, int itemHash) => null;
  @override
  BreakerType? rowBreaker(int itemHash) => null;
  @override
  ArmorSet? armorSetForItem(int itemHash) => null;
  @override
  ArmorSet? armorSetByHash(int setHash) => null;
  @override
  bool isIndexWarm(GearKind kind) => true;
  @override
  Future<List<GearSummary>> warmIndex(GearKind kind) async =>
      listGear(GearFilter(kind: kind));
  @override
  Future<void> warmFacets(GearKind kind) async {}
  @override
  List<PerkOption> perkOptions() => const [];
  @override
  List<PerkOption> frameOptions() => const [];
  @override
  List<PerkOption> setEffectOptions() => const [];
}

/// A rolled instance: Range 74 (10 from masterwork), one active perk with an
/// alternate option in its column (this copy's own options — not the
/// definition pool), one mod, a masterwork plug, and a part-way catalyst.
ItemDetail _rolledDetail(DestinyItem item) => ItemDetail(
      item: item,
      stats: const [
        ItemStat(statHash: 7, name: 'Range', value: 74, masterworkBonus: 10)
      ],
      plugs: const [
        ItemPlug(
          name: 'Opening Shot',
          iconPath: '',
          category: PlugCategory.perk,
          isEnhanced: true,
          statEffects: [PerkStatEffect(hash: 7, name: 'Range', value: 20)],
        ),
        ItemPlug(
            name: 'Boss Spec',
            iconPath: '',
            category: PlugCategory.mod,
            plugHash: 5000),
        ItemPlug(
            name: 'Masterwork: Range',
            iconPath: '',
            category: PlugCategory.masterwork),
      ],
      perkColumns: const [
        PerkColumn(
          label: 'Trait',
          activeIndex: 0,
          plugs: [
            ItemPlug(
              name: 'Opening Shot',
              iconPath: '',
              category: PlugCategory.perk,
              isEnhanced: true,
              statEffects: [PerkStatEffect(hash: 7, name: 'Range', value: 20)],
            ),
            ItemPlug(
                name: 'Kill Clip', iconPath: '', category: PlugCategory.perk),
          ],
        ),
      ],
      catalyst: const CatalystProgress(
        name: 'Fatebringer Catalyst',
        acquired: true,
        complete: false,
        options: [
          CatalystOption(name: 'Explosive Payload', effects: [
            CatalystEffect(
                name: 'Explosive Payload',
                description: 'Projectiles create an area-of-effect detonation.')
          ]),
        ],
        objectives: [
          CatalystObjective(
              name: 'Kills', progress: 38, completionValue: 150, complete: false),
        ],
      ),
    );

void main() {
  // [insight] serves as every plug's Clarity entry when given (both the
  // by-hash lookup the Insights panel uses and the hash-then-name lookup the
  // mod tooltip uses), so tests get covered plugs without a Clarity pipeline.
  ProviderContainer makeContainer({ClarityInsight? insight}) {
    final c = ProviderContainer(overrides: [
      databaseRepositoryProvider.overrideWithValue(_Repo()),
      // The rolled detail derived from the backing instance, without an
      // inventory repository.
      gearModalInstanceDetailProvider.overrideWith((ref) {
        final item = ref.watch(gearModalInstanceProvider);
        if (item == null) return null;
        return _rolledDetail(item);
      }),
      if (insight != null) ...[
        clarityInsightProvider.overrideWith((ref, hash) => insight),
        clarityInsightForPlugProvider.overrideWith((ref, plug) => insight),
      ],
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Widget app(ProviderContainer c) => UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: DatabaseScreen())),
      );

  // The modal is a wide three-column layout; match the desktop window.
  void useWideSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('database-opened modal shows the definition with no toggle',
      (tester) async {
    useWideSurface(tester);
    final c = makeContainer();
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fatebringer'));
    await tester.pumpAndSettle();

    expect(find.text('60'), findsOneWidget); // definition stat
    expect(find.text('Barrel'), findsOneWidget); // perk grid
    expect(find.text('This Roll'), findsNothing); // no instance → no toggle
    expect(find.text('MODS'), findsNothing);
    expect(find.text('CATALYST'), findsNothing); // no instance → no catalyst
  });

  testWidgets(
      'inventory-opened modal defaults to the roll — stats, perks, mods, '
      'masterwork, catalyst — and toggles to the definition', (tester) async {
    useWideSurface(tester);
    final c = makeContainer();
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();

    // The Inventory tab's tap: record the owned instance, then select the
    // definition (which opens the modal).
    c
        .read(gearModalInstanceProvider.notifier)
        .select(_Repo.summary(1).toDestinyItem());
    c.read(selectedDatabaseItemProvider.notifier).select(1);
    await tester.pumpAndSettle();

    // Rolled view: instance stats, and the perk grid shows THIS COPY's own
    // options (its instance columns) — the active 'Opening Shot' plus its
    // alternate 'Kill Clip' — never the definition pool ('Rampage'/'Barrel').
    expect(find.text('This Roll'), findsOneWidget);
    expect(find.text('74'), findsOneWidget);
    expect(find.text('60'), findsNothing);
    expect(find.text('Trait'), findsOneWidget); // instance column label
    expect(find.text('Kill Clip'), findsOneWidget); // roll's alternate option
    expect(find.text('Opening Shot'), findsWidgets); // chip + effects column
    expect(find.text('Barrel'), findsNothing); // definition pool hidden
    expect(find.text('Rampage'), findsNothing);
    expect(find.text('MODS'), findsOneWidget);
    expect(find.text('Boss Spec'), findsOneWidget);
    expect(find.text('MASTERWORK'), findsOneWidget);
    expect(find.text('Masterwork: Range'), findsOneWidget);
    expect(find.text('38 / 150'), findsOneWidget); // catalyst objective
    expect(find.text('Fatebringer Catalyst'), findsOneWidget);
    expect(find.text('PERK EFFECTS'), findsOneWidget);
    expect(find.text('+20 Range'), findsOneWidget); // rolled perk effect

    // Toggle to Definition: the interactive grid returns, the roll's own
    // sections go away, and the catalyst stays visible.
    await tester.tap(find.text('Definition'));
    await tester.pumpAndSettle();
    expect(find.text('60'), findsOneWidget);
    expect(find.text('Barrel'), findsOneWidget);
    expect(find.text('Opening Shot'), findsNothing); // roll's perks gone
    expect(find.text('Kill Clip'), findsNothing);
    expect(find.text('MODS'), findsNothing);
    expect(find.text('Fatebringer Catalyst'), findsOneWidget);
    expect(find.textContaining('No perks selected'), findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byType(GestureDetector), matching: find.text('Rampage')));
    await tester.pumpAndSettle();
    expect(find.text('80'), findsOneWidget); // 60 + 20 preview still works

    // Back to the roll.
    await tester.tap(find.text('This Roll'));
    await tester.pumpAndSettle();
    expect(find.text('74'), findsOneWidget);
    expect(find.text('MODS'), findsOneWidget);
  });

  testWidgets('no toggle when the open definition is not the owned item',
      (tester) async {
    useWideSurface(tester);
    final c = makeContainer();
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();

    // An owned instance of a different item must not offer its roll here.
    c
        .read(gearModalInstanceProvider.notifier)
        .select(_Repo.summary(99).toDestinyItem());
    await tester.tap(find.text('Fatebringer'));
    await tester.pumpAndSettle();

    expect(find.text('This Roll'), findsNothing);
    expect(find.text('60'), findsOneWidget);
    expect(find.text('MODS'), findsNothing);
  });

  testWidgets(
      'a header chip on an inventory-opened modal fills the inventory search, '
      'not the Database search', (tester) async {
    useWideSurface(tester);
    final c = makeContainer();
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();

    c
        .read(gearModalInstanceProvider.notifier)
        .select(_Repo.summary(1).toDestinyItem());
    c.read(selectedDatabaseItemProvider.notifier).select(1);
    await tester.pumpAndSettle();

    // The Exotic rarity chip (tierType 6) injects `is:exotic`.
    await tester.tap(find.text('Exotic'));
    await tester.pumpAndSettle();

    expect(c.read(searchQueryProvider), 'is:exotic');
    expect(c.read(databaseSearchProvider), ''); // Database query untouched
  });

  testWidgets(
      'a header chip on a database-opened modal fills the Database search, '
      'not the inventory search', (tester) async {
    useWideSurface(tester);
    final c = makeContainer();
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fatebringer'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exotic'));
    await tester.pumpAndSettle();

    expect(c.read(databaseSearchProvider), 'is:exotic');
    expect(c.read(searchQueryProvider), ''); // inventory query untouched
  });

  testWidgets(
      'the side panel swaps between perk effects and community insights via '
      'the right-edge rail', (tester) async {
    useWideSurface(tester);
    const insight = ClarityInsight(hash: 0, name: 'Opening Shot', lines: [
      ClarityLine(content: [
        ClaritySpan(text: 'Shockwaves inherit weapon damage buffs.'),
      ]),
    ]);
    final c = makeContainer(insight: insight);
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();

    c
        .read(gearModalInstanceProvider.notifier)
        .select(_Repo.summary(1).toDestinyItem());
    c.read(selectedDatabaseItemProvider.notifier).select(1);
    await tester.pumpAndSettle();

    // The side panel's animated width is the size of its width-factor
    // builder; the swap rail is fixed-width and has none.
    final panel = find.byType(TweenAnimationBuilder<double>);

    // Default: perk effects expanded (rail titled EFFECTS), with the
    // insights swap rail on the right edge.
    expect(find.text('PERK EFFECTS'), findsOneWidget);
    expect(find.text('EFFECTS'), findsOneWidget);
    expect(find.text('INSIGHTS'), findsOneWidget);
    final expandedWidth = tester.getSize(panel).width;

    // The swap rail offers insights (lightbulb); the panel rail offers to
    // collapse the effects (chevron_right).
    expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);
    expect(find.byIcon(Icons.bar_chart), findsNothing);

    // Swap to insights via its rail: same panel and width, the insights
    // content and credit, and the swap rail now offers the effects back.
    await tester.tap(find.byIcon(Icons.lightbulb_outline));
    await tester.pumpAndSettle();
    expect(tester.getSize(panel).width, expandedWidth);
    expect(find.text('COMMUNITY INSIGHTS'), findsOneWidget);
    expect(find.text('PERK EFFECTS'), findsNothing);
    expect(find.textContaining('Shockwaves inherit', findRichText: true),
        findsOneWidget);
    expect(find.text('Clarity Discord'), findsOneWidget); // attribution
    expect(find.byIcon(Icons.bar_chart), findsOneWidget);

    // Collapse the insights panel via its chevron rail; the swap rail then
    // reopens the panel straight onto the effects content.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(tester.getSize(panel).width, lessThan(expandedWidth));
    await tester.tap(find.byIcon(Icons.bar_chart));
    await tester.pumpAndSettle();
    expect(tester.getSize(panel).width, expandedWidth);
    expect(find.text('PERK EFFECTS'), findsOneWidget);
    expect(find.text('COMMUNITY INSIGHTS'), findsNothing);
  });

  testWidgets(
      'hovering an equipped mod shows its Clarity insight in the tooltip, '
      'while a perk tooltip does not', (tester) async {
    useWideSurface(tester);
    const insight = ClarityInsight(hash: 0, name: 'Boss Spec', lines: [
      ClarityLine(content: [
        ClaritySpan(text: 'Deals extra damage to bosses and minibosses.'),
      ]),
    ]);
    final c = makeContainer(insight: insight);
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();

    c
        .read(gearModalInstanceProvider.notifier)
        .select(_Repo.summary(1).toDestinyItem());
    c.read(selectedDatabaseItemProvider.notifier).select(1);
    await tester.pumpAndSettle();

    final gesture =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    // Hover the equipped mod chip: its tooltip carries the Clarity block.
    await gesture.moveTo(tester.getCenter(find.text('Boss Spec')));
    await tester.pump(const Duration(seconds: 1)); // tooltip wait
    await tester.pumpAndSettle();
    expect(find.text('COMMUNITY INSIGHT · CLARITY'), findsOneWidget);
    expect(
        find.textContaining('extra damage to bosses', findRichText: true),
        findsOneWidget);

    // Move off, then hover a perk chip: no Clarity block (perk insights live
    // in the Insights rail, not the tooltip), even though the fixture would
    // resolve one for every hash.
    await gesture.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    await gesture.moveTo(tester.getCenter(find.text('Kill Clip')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('COMMUNITY INSIGHT · CLARITY'), findsNothing);
  });

  testWidgets(
      'an enhanced mod whose hash Clarity misses still shows the base '
      'insight via the name fallback', (tester) async {
    useWideSurface(tester);
    const insight = ClarityInsight(hash: 0, name: 'Boss Spec', lines: [
      ClarityLine(content: [
        ClaritySpan(text: 'Deals extra damage to bosses and minibosses.'),
      ]),
    ]);
    // The tooltip passes the plug's (hash, name) to
    // clarityInsightForPlugProvider. Mimic Clarity carrying the base by name
    // but not this enhanced copy's hash: resolve only when the name matches,
    // never by the hash (5000, the rolled Boss Spec mod's plugHash).
    final c = ProviderContainer(overrides: [
      databaseRepositoryProvider.overrideWithValue(_Repo()),
      gearModalInstanceDetailProvider.overrideWith((ref) {
        final item = ref.watch(gearModalInstanceProvider);
        return item == null ? null : _rolledDetail(item);
      }),
      clarityInsightForPlugProvider.overrideWith(
          (ref, plug) => plug.name == 'Boss Spec' ? insight : null),
    ]);
    addTearDown(c.dispose);

    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();
    c
        .read(gearModalInstanceProvider.notifier)
        .select(_Repo.summary(1).toDestinyItem());
    c.read(selectedDatabaseItemProvider.notifier).select(1);
    await tester.pumpAndSettle();

    final gesture =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    await gesture.moveTo(tester.getCenter(find.text('Boss Spec')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('COMMUNITY INSIGHT · CLARITY'), findsOneWidget);
    expect(
        find.textContaining('extra damage to bosses', findRichText: true),
        findsOneWidget);
  });

  testWidgets(
      'the Selected Perks panel starts expanded, then collapses to a narrower '
      'rail and reopens via its chevron', (tester) async {
    useWideSurface(tester);
    final c = makeContainer();
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fatebringer'));
    await tester.pumpAndSettle();

    // The panel's animated width is the size of its width-factor builder
    // (scoped to the effects panel — the insights panel has its own builder).
    final panel = find
        .ancestor(
            of: find.text('SELECTED PERKS'),
            matching: find.byType(TweenAnimationBuilder<double>))
        .first;

    // Expanded by default: the Selected Perks section shows, and the panel
    // rail's chevron (pointing right) offers to collapse it.
    expect(find.text('SELECTED PERKS'), findsOneWidget);
    expect(find.textContaining('No perks selected'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    final expandedWidth = tester.getSize(panel).width;

    // Collapse via the chevron rail: the panel shrinks to a narrower rail
    // whose chevron now points left to reopen it.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    final collapsedWidth = tester.getSize(panel).width;
    expect(collapsedWidth, lessThan(expandedWidth));
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);

    // Reopen: back to full width with the collapse chevron.
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(tester.getSize(panel).width, expandedWidth);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });
}
