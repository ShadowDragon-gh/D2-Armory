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
import 'package:d2_armory/presentation/screens/database/armor_set_detail_modal.dart';
import 'package:d2_armory/presentation/screens/database/database_screen.dart';

/// A set whose members are Titan Helm (11) and Warlock Cowl (13); Hunter Hood
/// (12) is setless. Used by the collapse-into-sets test.
const _aegisSet = ArmorSet(
  hash: 777,
  name: 'Aegis Set',
  memberHashes: [11, 13],
  perks: [
    SetPerk(requiredSetCount: 2, name: 'Guarded'),
    SetPerk(requiredSetCount: 4, name: 'Bulwark'),
  ],
);

/// A hand-built DatabaseRepository with a fixed in-memory gear set, so the
/// widget test exercises the real screen + modal + providers without a manifest.
class _FakeRepo implements DatabaseRepository {
  final _weapons = <GearSummary>[
    _summary(1, 'Fatebringer', tier: 6, sub: 9),
    _summary(2, 'The Messenger', tier: 5, sub: 13),
    _summary(3, 'Palindrome', tier: 5, sub: 9),
  ];

  // Armor pieces spanning the three classes, for the class-filter test.
  // Titan Helm (11) and Warlock Cowl (13) belong to one set ("Aegis Set");
  // Hunter Hood (12) is setless. Loreley (14) is a setless Exotic — so the
  // Sets+Exotics union yields one set row plus the Exotic piece.
  final _armor = <GearSummary>[
    _armorSummary(11, 'Titan Helm', cls: 0),
    _armorSummary(12, 'Hunter Hood', cls: 1),
    _armorSummary(13, 'Warlock Cowl', cls: 2),
    _armorSummary(14, 'Loreley Splendor', cls: 0, tier: 6),
  ];

  // Ability plugs: a Warlock super, a class-shared fragment, and a Warlock
  // aspect. Class 3 = shared. Used by the Abilities-tab tests.
  final _abilities = <GearSummary>[
    _abilitySummary(21, 'Daybreak', cls: 2, element: 3, type: 'Solar Super'),
    _abilitySummary(22, 'Ember of Torches',
        cls: 3, element: 3, type: 'Solar Fragment'),
    _abilitySummary(23, 'Heat Rises', cls: 2, element: 3, type: 'Solar Aspect'),
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

  static GearSummary _armorSummary(int hash, String name,
          {required int cls, int tier = 5}) =>
      GearSummary(
        itemHash: hash,
        name: name,
        iconPath: '',
        tierType: tier,
        itemType: 2,
        itemSubType: 26,
        itemTypeDisplayName: 'Helmet',
        classType: cls,
        damageType: 0,
        ammoType: 0,
        bucketHash: 3448274439,
        index: hash,
      );

  static GearSummary _abilitySummary(int hash, String name,
          {required int cls, required int element, required String type}) =>
      GearSummary(
        itemHash: hash,
        name: name,
        iconPath: '',
        tierType: 0,
        itemType: 19,
        itemSubType: 0,
        itemTypeDisplayName: type,
        classType: cls,
        damageType: element,
        ammoType: 0,
        bucketHash: 0,
        index: hash,
      );

  @override
  List<GearSummary> listGear(GearFilter filter) {
    final source = switch (filter.kind) {
      GearKind.armor => _armor,
      GearKind.ability => _abilities,
      GearKind.weapon => _weapons,
    };
    return source.where((g) {
      if (filter.tierType != null && g.tierType != filter.tierType) {
        return false;
      }
      if (filter.minTierType != null && g.tierType < filter.minTierType!) {
        return false;
      }
      // Class filter keeps that class plus class-shared (classType 3) items.
      if (filter.classType != null &&
          g.classType != filter.classType &&
          g.classType != 3) {
        return false;
      }
      if (filter.itemSubType != null && g.itemSubType != filter.itemSubType) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  ({GearSummary summary, ItemPlug plug})? resolveAbilityDetail(int itemHash) {
    final match = _abilities.where((g) => g.itemHash == itemHash);
    if (match.isEmpty) return null;
    final g = match.first;
    // Daybreak has a description; Ember of Torches carries a stat effect;
    // Heat Rises (aspect) is uncovered by Clarity in the test override.
    return (
      summary: g,
      plug: ItemPlug(
        name: g.name,
        iconPath: '',
        category: PlugCategory.perk,
        description: g.name == 'Heat Rises'
            ? 'Hold to consume your grenade and begin gliding.'
            : 'A subclass ability.',
        plugHash: itemHash,
        statEffects: g.name == 'Ember of Torches'
            ? const [
                PerkStatEffect(
                    hash: 1, name: 'Discipline', value: -10, beneficial: false)
              ]
            : const [],
      ),
    );
  }

  @override
  GearDetail? resolveGearDetail(int itemHash) {
    // Search both kinds so armor set members (and weapons) resolve.
    final all = [..._weapons, ..._armor];
    final match = all.where((g) => g.itemHash == itemHash);
    if (match.isEmpty) return null;
    final g = match.first;
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
  ArmorSet? armorSetForItem(int itemHash) =>
      _aegisSet.memberHashes.contains(itemHash) ? _aegisSet : null;
  @override
  ArmorSet? armorSetByHash(int setHash) =>
      setHash == _aegisSet.hash ? _aegisSet : null;

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

    // Switch to Armor: the class control appears. Sets and Exotics are both on
    // by default; turn both off to get the flat all-pieces view for testing
    // class filtering.
    await tester.tap(find.text('Armor'));
    await tester.pumpAndSettle();
    expect(find.text('Titan'), findsOneWidget); // class control now shown
    await tester.tap(find.text('Sets')); // collapse off
    await tester.tap(find.text('Exotics')); // exotics off → flat all pieces
    await tester.pumpAndSettle();
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

  testWidgets(
      'Sets and Exotics toggles are independent and additive',
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

    await tester.tap(find.text('Armor'));
    await tester.pumpAndSettle();

    // Both on by default (the additive union): the Aegis Set collapses to one
    // set row AND the setless Exotic (Loreley) shows as its own piece row. The
    // setless Legendary (Hunter Hood) is not a set and not Exotic, so it is
    // hidden.
    expect(find.text('Aegis Set'), findsOneWidget);
    expect(find.text('2pc: Guarded'), findsOneWidget);
    expect(find.text('4pc: Bulwark'), findsOneWidget);
    expect(find.text('Loreley Splendor'), findsOneWidget); // Exotic piece
    expect(find.text('Titan Helm'), findsNothing); // collapsed into the set
    expect(find.text('Warlock Cowl'), findsNothing);
    expect(find.text('Hunter Hood'), findsNothing); // setless Legendary

    // Sets off, Exotics on → Exotics only: just Loreley, no set row.
    await tester.tap(find.text('Sets'));
    await tester.pumpAndSettle();
    expect(find.text('Aegis Set'), findsNothing);
    expect(find.text('Loreley Splendor'), findsOneWidget);
    expect(find.text('Titan Helm'), findsNothing);
    expect(find.text('Hunter Hood'), findsNothing);

    // Both off → show all: every piece as a flat row.
    await tester.tap(find.text('Exotics'));
    await tester.pumpAndSettle();
    expect(find.text('Aegis Set'), findsNothing);
    expect(find.text('Titan Helm'), findsOneWidget);
    expect(find.text('Warlock Cowl'), findsOneWidget);
    expect(find.text('Hunter Hood'), findsOneWidget);
    expect(find.text('Loreley Splendor'), findsOneWidget);

    // Sets on, Exotics off → sets only: the set row, no loose pieces.
    await tester.tap(find.text('Sets'));
    await tester.pumpAndSettle();
    expect(find.text('Aegis Set'), findsOneWidget);
    expect(find.text('Loreley Splendor'), findsNothing);
    expect(find.text('Titan Helm'), findsNothing);
    expect(find.text('Hunter Hood'), findsNothing);

    // Tapping the set row selects the set and opens the set-detail modal: it
    // shows the set bonus and each member's screenshot.
    await tester.tap(find.text('Aegis Set'));
    await tester.pumpAndSettle();
    expect(container.read(selectedArmorSetProvider), 777);
    expect(find.byType(ArmorSetDetailModal), findsOneWidget);
    expect(find.text('SET BONUS'), findsOneWidget);
    expect(find.text('2 Piece: Guarded'), findsOneWidget);
    expect(find.text('4 Piece: Bulwark'), findsOneWidget);
    // The member pieces are shown in the gallery.
    expect(find.text('Titan Helm'), findsOneWidget);
    expect(find.text('Warlock Cowl'), findsOneWidget);
  });

  testWidgets("a single armor piece's detail modal shows its set bonus",
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

    // Open the detail modal for an Aegis Set member (Titan Helm, hash 11).
    container.read(selectedDatabaseItemProvider.notifier).select(11);
    await tester.pumpAndSettle();

    // The single-piece modal shows the set's bonus.
    expect(find.text('SET BONUS'), findsOneWidget);
    expect(find.text('2 Piece: Guarded'), findsOneWidget);
    expect(find.text('4 Piece: Bulwark'), findsOneWidget);
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

  group('Sets and Exotics are independent', () {
    late ProviderContainer c;
    setUp(() => c = ProviderContainer());
    tearDown(() => c.dispose());

    DatabaseFilter read() => c.read(databaseFilterProvider);
    DatabaseFilterNotifier notifier() =>
        c.read(databaseFilterProvider.notifier);

    test('both are on by default', () {
      expect(read().collapseSets, isTrue);
      expect(read().showExotics, isTrue);
    });

    test('toggling Sets leaves Exotics untouched', () {
      notifier().setCollapseSets(false);
      expect(read().collapseSets, isFalse);
      expect(read().showExotics, isTrue); // unchanged
    });

    test('toggling Exotics leaves Sets untouched', () {
      notifier().setShowExotics(false);
      expect(read().showExotics, isFalse);
      expect(read().collapseSets, isTrue); // unchanged
    });

    test('the rarity floor is independent of Exotics', () {
      // Exotics no longer pins the tier; the Legendary floor is governed only
      // by hideBelowLegendary.
      notifier().setShowExotics(true);
      expect(read().toGearFilter().tierType, isNull);
      expect(read().toGearFilter().minTierType, 5); // Legendary floor

      notifier().setHideBelowLegendary(false);
      expect(read().toGearFilter().minTierType, isNull); // floor lifted
    });
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
  ({GearSummary summary, ItemPlug plug})? resolveAbilityDetail(int itemHash) =>
      null;

  @override
  SearchFacets? facetsFor(GearKind kind, int itemHash) => null;

  @override
  BreakerType? rowBreaker(int itemHash) => null;
  @override
  ArmorSet? armorSetForItem(int itemHash) =>
      _aegisSet.memberHashes.contains(itemHash) ? _aegisSet : null;
  @override
  ArmorSet? armorSetByHash(int setHash) =>
      setHash == _aegisSet.hash ? _aegisSet : null;

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
