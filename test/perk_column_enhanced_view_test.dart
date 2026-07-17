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

/// A weapon in the shape of the real Acantha-D XK8434: its Barrel and Magazine
/// sockets carry both a base and an enhanced form of each plug, but its two
/// Trait sockets are regular-only (this weapon never got enhanced traits in the
/// manifest). The Enhanced/Regular toggle must not blank the regular-only Trait
/// columns when the (default) Enhanced view is active.
class _Repo implements DatabaseRepository {
  static GearSummary summary(int hash) => GearSummary(
        itemHash: hash,
        name: 'Acantha-D XK8434',
        iconPath: '',
        tierType: 5,
        itemType: 3,
        itemSubType: 11,
        itemTypeDisplayName: 'Grenade Launcher',
        classType: 3,
        damageType: 3,
        ammoType: 3,
        bucketHash: 953998645,
        index: hash,
      );

  @override
  List<GearSummary> listGear(GearFilter filter) => [summary(1)];

  @override
  GearDetail? resolveGearDetail(int itemHash) => GearDetail(
        item: summary(itemHash).toDestinyItem(),
        stats: const [ItemStat(statHash: 7, name: 'Blast Radius', value: 20)],
        perkColumns: const [
          // Barrel: base + enhanced of the same plug (enhanced-first, as the
          // resolver partitions them).
          PerkColumn(label: 'Launcher Barrel', plugs: [
            ItemPlug(
                name: 'Volatile Launch',
                iconPath: '',
                category: PlugCategory.perk,
                isEnhanced: true),
            ItemPlug(
                name: 'Volatile Launch',
                iconPath: '',
                category: PlugCategory.perk),
          ]),
          // Magazine: same both-variant shape.
          PerkColumn(label: 'Magazine', plugs: [
            ItemPlug(
                name: 'Spike Grenades',
                iconPath: '',
                category: PlugCategory.perk,
                isEnhanced: true),
            ItemPlug(
                name: 'Spike Grenades',
                iconPath: '',
                category: PlugCategory.perk),
          ]),
          // Trait columns: regular-only — no enhanced counterpart exists.
          PerkColumn(label: 'Trait', plugs: [
            ItemPlug(
                name: 'Rangefinder', iconPath: '', category: PlugCategory.perk),
            ItemPlug(
                name: 'Field Prep', iconPath: '', category: PlugCategory.perk),
          ]),
          PerkColumn(label: 'Trait', plugs: [
            ItemPlug(
                name: 'Rampage', iconPath: '', category: PlugCategory.perk),
            ItemPlug(
                name: 'Quickdraw', iconPath: '', category: PlugCategory.perk),
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

void main() {
  ProviderContainer makeContainer() {
    final c = ProviderContainer(overrides: [
      databaseRepositoryProvider.overrideWithValue(_Repo()),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Widget app(ProviderContainer c) => UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: DatabaseScreen())),
      );

  void useWideSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> openModal(WidgetTester tester, ProviderContainer c) async {
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acantha-D XK8434').first);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'the default Enhanced view keeps regular-only Trait columns populated',
      (tester) async {
    useWideSurface(tester);
    final c = makeContainer();
    await openModal(tester, c);

    // Both-variant columns render (their enhanced plug is shown).
    expect(find.text('Volatile Launch'), findsOneWidget);
    expect(find.text('Spike Grenades'), findsOneWidget);

    // The regular-only Trait columns must NOT be blanked in the Enhanced view —
    // this is the reported bug. All four trait perks stay visible.
    expect(find.text('Rangefinder'), findsOneWidget);
    expect(find.text('Field Prep'), findsOneWidget);
    expect(find.text('Rampage'), findsOneWidget);
    expect(find.text('Quickdraw'), findsOneWidget);
  });

  testWidgets(
      'the both-variant columns still filter per view (one plug per name)',
      (tester) async {
    useWideSurface(tester);
    final c = makeContainer();
    await openModal(tester, c);

    // Enhanced view: exactly one Volatile Launch chip (the enhanced one), not
    // both variants.
    expect(find.text('Volatile Launch'), findsOneWidget);

    // Switch to Regular: the both-variant columns swap to their base plug and
    // the regular-only Trait columns remain fully visible.
    await tester.tap(find.text('Regular'));
    await tester.pumpAndSettle();
    expect(find.text('Volatile Launch'), findsOneWidget);
    expect(find.text('Spike Grenades'), findsOneWidget);
    expect(find.text('Rangefinder'), findsOneWidget);
    expect(find.text('Rampage'), findsOneWidget);
  });
}
