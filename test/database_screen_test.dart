import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:d2_armory/core/destiny/destiny_buckets.dart';
import 'package:d2_armory/core/destiny/plug_category.dart';
import 'package:d2_armory/core/search/item_filter.dart';
import 'package:d2_armory/core/search/search_suggestions.dart';
import 'package:d2_armory/data/repositories/database_repository.dart';
import 'package:d2_armory/domain/models/armor_set.dart';
import 'package:d2_armory/domain/models/item_detail.dart';
import 'package:d2_armory/presentation/providers/database_provider.dart';
import 'package:d2_armory/presentation/screens/database/database_screen.dart';

/// A hand-built DatabaseRepository with a fixed in-memory gear set, so the
/// widget test exercises the real screen + modal + providers without a manifest.
class _FakeRepo implements DatabaseRepository {
  final _weapons = <GearSummary>[
    _summary(1, 'Fatebringer', tier: 6, sub: 9),
    _summary(2, 'The Messenger', tier: 5, sub: 13),
    _summary(3, 'Palindrome', tier: 5, sub: 9),
  ];

  // Armor pieces spanning the three classes, for the class-filter test.
  final _armor = <GearSummary>[
    _armorSummary(11, 'Titan Helm', cls: 0),
    _armorSummary(12, 'Hunter Hood', cls: 1),
    _armorSummary(13, 'Warlock Cowl', cls: 2),
  ];

  static GearSummary _summary(int hash, String name,
          {int tier = 5, int sub = 9}) =>
      GearSummary(
        itemHash: hash,
        name: name,
        iconPath: '',
        tierType: tier,
        itemType: 3,
        itemSubType: sub,
        itemTypeDisplayName: 'Weapon',
        classType: 3,
        damageType: 0,
        ammoType: 1,
        bucketHash: 1498876634,
        index: hash,
      );

  static GearSummary _armorSummary(int hash, String name, {required int cls}) =>
      GearSummary(
        itemHash: hash,
        name: name,
        iconPath: '',
        tierType: 5,
        itemType: 2,
        itemSubType: 26,
        itemTypeDisplayName: 'Helmet',
        classType: cls,
        damageType: 0,
        ammoType: 0,
        bucketHash: 3448274439,
        index: hash,
      );

  @override
  List<GearSummary> listGear(GearFilter filter) {
    final source = filter.kind == GearKind.armor ? _armor : _weapons;
    return source.where((g) {
      if (filter.tierType != null && g.tierType != filter.tierType) {
        return false;
      }
      if (filter.classType != null && g.classType != filter.classType) {
        return false;
      }
      if (filter.itemSubType != null && g.itemSubType != filter.itemSubType) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  GearDetail? resolveGearDetail(int itemHash) {
    final g = _weapons.firstWhere((w) => w.itemHash == itemHash);
    return GearDetail(
      item: g.toDestinyItem(),
      stats: const [ItemStat(statHash: 7, name: 'Range', value: 60)],
      flavorText: 'Crease the universe.',
      perkColumns: const [
        PerkColumn(label: 'Barrel', plugs: [
          ItemPlug(
            name: 'Rampage',
            iconPath: '',
            category: PlugCategory.perk,
            description: 'Kills grant a stacking damage bonus.',
            statEffects: [PerkStatEffect(hash: 7, name: 'Range', value: 20)],
          ),
          ItemPlug(
            name: 'Outlaw',
            iconPath: '',
            category: PlugCategory.perk,
            statEffects: [PerkStatEffect(hash: 7, name: 'Range', value: -10)],
          ),
        ]),
        // A description-only origin trait (no stat numbers) — the "Gun and Run"
        // case: its effect must still show in the Selected Perks list.
        PerkColumn(label: 'Origin Trait', plugs: [
          ItemPlug(
            name: 'Gun and Run',
            iconPath: '',
            category: PlugCategory.perk,
            description: 'Defeating targets grants stacks of Gun and Run.',
          ),
        ]),
      ],
    );
  }

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
}

Widget _app() => ProviderScope(
      overrides: [
        databaseRepositoryProvider.overrideWithValue(_FakeRepo()),
      ],
      child: const MaterialApp(home: Scaffold(body: DatabaseScreen())),
    );

/// The detail modal is a wide three-column layout (screenshot | perks |
/// selected effects); give the test surface enough width to lay it out without
/// overflow, matching the desktop window the app runs in.
void _useWideSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1900, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('lists gear, and tapping a row opens the detail modal',
      (tester) async {
    _useWideSurface(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // All three weapons are listed.
    expect(find.text('Fatebringer'), findsOneWidget);
    expect(find.text('The Messenger'), findsOneWidget);
    expect(find.text('Palindrome'), findsOneWidget);
    // No modal yet.
    expect(find.byType(Dialog), findsNothing);

    // Tapping a row opens the modal showing its flavor, stats, and perk grid.
    await tester.tap(find.text('Fatebringer'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Crease the universe.'), findsOneWidget); // flavor
    expect(find.text('Range'), findsOneWidget); // stat row
    expect(find.text('Barrel'), findsOneWidget); // perk column label
    expect(find.text('Rampage'), findsWidgets); // the candidate perk

    // Closing the modal (close button) dismisses it and clears selection.
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Fatebringer'), findsOneWidget); // back to list
  });

  testWidgets('re-opening the modal for another item throws no build error',
      (tester) async {
    // Regression: the modal-scoped detail providers must dispose when the modal
    // closes. If they linger, re-selecting an item leaves them dirty with a
    // live subscriber, so the re-opened modal's first watch flushes them
    // mid-build and Riverpod calls setState during the build phase.
    _useWideSurface(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Open, then close, so the detail providers mount and (must) tear down.
    await tester.tap(find.text('Fatebringer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    // Re-open a different item — the offending frame is the modal's first
    // build, so pump one frame before settling.
    await tester.tap(find.text('The Messenger'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Dialog), findsOneWidget);
  });

  testWidgets('selecting a perk updates the stat total and effects list',
      (tester) async {
    _useWideSurface(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fatebringer'));
    await tester.pumpAndSettle();

    // Tap a perk *chip* (inside the tappable GestureDetector), never the
    // effects-list copy of the same name.
    Finder chip(String name) => find.descendant(
        of: find.byType(GestureDetector), matching: find.text(name));

    // Base Range is 60; no perk selected → effects list is empty-state.
    expect(find.text('60'), findsOneWidget);
    expect(find.textContaining('No perks selected'), findsOneWidget);

    // Select Rampage (+20 Range).
    await tester.tap(chip('Rampage'));
    await tester.pumpAndSettle();
    expect(find.text('80'), findsOneWidget); // 60 + 20
    expect(find.text('+20 Range'), findsOneWidget); // stat effect line
    // The non-stat gameplay effect (description) is shown too.
    expect(find.text('Kills grant a stacking damage bonus.'), findsOneWidget);
    expect(find.textContaining('No perks selected'), findsNothing);

    // Switch to Outlaw (-10 Range) in the same column: replaces Rampage.
    await tester.tap(chip('Outlaw'));
    await tester.pumpAndSettle();
    expect(find.text('50'), findsOneWidget); // 60 - 10
    expect(find.text('-10 Range'), findsOneWidget);
    expect(find.text('+20 Range'), findsNothing); // Rampage deselected

    // Clicking Outlaw again toggles it off → back to base.
    await tester.tap(chip('Outlaw'));
    await tester.pumpAndSettle();
    expect(find.text('60'), findsOneWidget);
    expect(find.textContaining('No perks selected'), findsOneWidget);
  });

  testWidgets('a description-only perk shows its non-stat effect when selected',
      (tester) async {
    _useWideSurface(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fatebringer'));
    await tester.pumpAndSettle();

    Finder chip(String name) => find.descendant(
        of: find.byType(GestureDetector), matching: find.text(name));

    // Gun and Run has no stat effects — selecting it must still surface its
    // gameplay effect text in the Selected Perks list (not "No listed effect").
    await tester.tap(chip('Gun and Run'));
    await tester.pumpAndSettle();
    expect(find.text('Defeating targets grants stacks of Gun and Run.'),
        findsOneWidget);
    expect(find.text('No listed effect'), findsNothing);
    // No stat total changed (still 60).
    expect(find.text('60'), findsOneWidget);
  });

  testWidgets('opening a different item resets the perk selection',
      (tester) async {
    final container = ProviderContainer(overrides: [
      databaseRepositoryProvider.overrideWithValue(_FakeRepo()),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: DatabaseScreen())),
    ));
    await tester.pumpAndSettle();

    container.read(selectedDatabaseItemProvider.notifier).select(1);
    container.read(databasePerkSelectionProvider.notifier).toggle(0, 0);
    expect(container.read(databasePerkSelectionProvider), {0: 0});

    // Opening another item clears the selection.
    container.read(selectedDatabaseItemProvider.notifier).select(2);
    expect(container.read(databasePerkSelectionProvider), isEmpty);
  });

  testWidgets('rarity is filtered through the search bar (is:exotic)',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'is:exotic');
    await tester.pumpAndSettle();

    expect(find.text('Fatebringer'), findsOneWidget); // exotic kept
    expect(find.text('Palindrome'), findsNothing); // legendary removed
  });

  testWidgets('clicking a header chip sets the search bar and closes the modal',
      (tester) async {
    _useWideSurface(tester);
    final container = ProviderContainer(overrides: [
      databaseRepositoryProvider.overrideWithValue(_FakeRepo()),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: DatabaseScreen())),
    ));
    await tester.pumpAndSettle();

    // Open Fatebringer (hand cannon, subType 9); The Messenger is a pulse
    // (subType 13).
    await tester.tap(find.text('Fatebringer'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);

    // The weapon-type chip (labelled from itemTypeDisplayName) now writes an
    // `is:handcannon` search term and closes the modal.
    await tester.tap(find.widgetWithText(InkWell, 'Weapon').first);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing); // modal closed
    expect(container.read(databaseSearchProvider), 'is:handcannon');
    expect(find.text('Fatebringer'), findsOneWidget); // hand cannon kept
    expect(find.text('Palindrome'), findsOneWidget); // hand cannon kept
    expect(find.text('The Messenger'), findsNothing); // pulse filtered out
  });

  testWidgets(
      'the class filter is armor-only and narrows the list by class',
      (tester) async {
    // The filter bar carries the kind toggle, the class control, and the search
    // field — give it the desktop width the app runs at so they lay out without
    // overflow.
    _useWideSurface(tester);
    final container = ProviderContainer(overrides: [
      databaseRepositoryProvider.overrideWithValue(_FakeRepo()),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: DatabaseScreen())),
    ));
    await tester.pumpAndSettle();

    // Weapons are the default kind: no class control, weapons listed.
    expect(find.text('Titan'), findsNothing);
    expect(find.text('Fatebringer'), findsOneWidget);

    // Switch to Armor: the class control appears and all three armor pieces
    // (one per class) list.
    await tester.tap(find.text('Armor'));
    await tester.pumpAndSettle();
    expect(find.text('Titan'), findsOneWidget); // class control now shown
    expect(find.text('Titan Helm'), findsOneWidget);
    expect(find.text('Hunter Hood'), findsOneWidget);
    expect(find.text('Warlock Cowl'), findsOneWidget);

    // Pick Hunter: only the Hunter piece remains.
    await tester.tap(find.text('Hunter'));
    await tester.pumpAndSettle();
    expect(container.read(databaseFilterProvider).classType, 1);
    expect(find.text('Hunter Hood'), findsOneWidget);
    expect(find.text('Titan Helm'), findsNothing);
    expect(find.text('Warlock Cowl'), findsNothing);

    // Switching back to Weapons hides the control and drops the class
    // constraint (so returning to Armor would show all classes again).
    await tester.tap(find.text('Weapons'));
    await tester.pumpAndSettle();
    expect(find.text('Hunter'), findsNothing); // control hidden
    expect(container.read(databaseFilterProvider).classType, isNull);
    expect(find.text('Fatebringer'), findsOneWidget);
  });

  testWidgets('the enhanced/regular toggle filters the perk grid',
      (tester) async {
    _useWideSurface(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseRepositoryProvider.overrideWithValue(_ToggleFakeRepo()),
      ],
      child: const MaterialApp(home: Scaffold(body: DatabaseScreen())),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fatebringer'));
    await tester.pumpAndSettle();

    Finder chip(String name) => find.descendant(
        of: find.byType(GestureDetector), matching: find.text(name));

    // Default view is Enhanced. Base and enhanced share the name "Rampage", so
    // at most one chip exists at a time (the view filters to one state).
    expect(find.text('Enhanced'), findsOneWidget); // toggle present
    expect(chip('Rampage'), findsOneWidget);

    // Select the enhanced perk (+25 Range).
    await tester.tap(chip('Rampage'));
    await tester.pumpAndSettle();
    expect(find.text('85'), findsOneWidget); // 60 + 25 (enhanced)

    // Switch to Regular: the selection is KEPT and swapped to the base perk,
    // so the total drops to the base perk's value — not cleared.
    await tester.tap(find.text('Regular'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No perks selected'), findsNothing);
    expect(find.text('80'), findsOneWidget); // 60 + 20 (base counterpart)
    expect(chip('Rampage'), findsOneWidget); // still selected, base shown

    // Switch back to Enhanced: swaps back to the enhanced perk (+25).
    await tester.tap(find.text('Enhanced'));
    await tester.pumpAndSettle();
    expect(find.text('85'), findsOneWidget);
  });
}

/// A fake with one perk column holding both a base and an enhanced perk, so the
/// enhanced/regular toggle has something to switch between.
class _ToggleFakeRepo implements DatabaseRepository {
  @override
  List<GearSummary> listGear(GearFilter filter) => const [
        GearSummary(
          itemHash: 1,
          name: 'Fatebringer',
          iconPath: '',
          tierType: 6,
          itemType: 3,
          itemSubType: 9,
          itemTypeDisplayName: 'Weapon',
          classType: 3,
          damageType: 0,
          ammoType: 1,
          bucketHash: 1498876634,
          index: 1,
        ),
      ];

  @override
  GearDetail? resolveGearDetail(int itemHash) => GearDetail(
        item: listGear(const GearFilter(kind: GearKind.weapon))
            .first
            .toDestinyItem(),
        stats: const [ItemStat(statHash: 7, name: 'Range', value: 60)],
        perkColumns: const [
          // Base and enhanced share a name (as real data does), distinguished
          // only by isEnhanced — so the view toggle can swap between them.
          PerkColumn(label: 'Barrel', plugs: [
            ItemPlug(
              name: 'Rampage',
              iconPath: '',
              category: PlugCategory.perk,
              isEnhanced: true,
              statEffects: [PerkStatEffect(hash: 7, name: 'Range', value: 25)],
            ),
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
}
