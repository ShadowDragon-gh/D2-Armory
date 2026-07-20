import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:d2_armory/core/destiny/plug_category.dart';
import 'package:d2_armory/data/repositories/exotic_ability_repository.dart';
import 'package:d2_armory/data/repositories/manifest_repository.dart';
import 'package:d2_armory/domain/models/clarity_insight.dart';
import 'package:d2_armory/domain/models/destiny_item.dart';
import 'package:d2_armory/domain/models/exotic_ability_interaction.dart';
import 'package:d2_armory/domain/models/item_detail.dart';
import 'package:d2_armory/domain/models/subclass_detail.dart';
import 'package:d2_armory/presentation/providers/clarity_provider.dart';
import 'package:d2_armory/presentation/providers/exotic_ability_provider.dart';
import 'package:d2_armory/presentation/providers/inventory_provider.dart';
import 'package:d2_armory/presentation/screens/inventory/subclass_detail_modal.dart';

class _MockManifest extends Mock implements ManifestRepository {}

/// A ready exotic-ability repository over a fixed list, running the REAL
/// class/kind/name/element match so the badge and general-column tests exercise
/// the actual filters, not a stub.
class _FakeExoticRepo extends ExoticAbilityRepository {
  _FakeExoticRepo(this._all) : super(manifest: _MockManifest());

  final List<ExoticAbilityInteraction> _all;

  @override
  List<ExoticAbilityInteraction> exoticsFor(
    AbilityKind kind,
    int subclassClassType,
    int subclassElement,
    Iterable<String> socketPlugNames,
  ) =>
      [
        for (final e in _all)
          if (e.matchesClass(subclassClassType) &&
              e.matchesNamedSocket(kind, socketPlugNames, subclassElement))
            e,
      ];

  @override
  List<ExoticAbilityInteraction> generalExoticsFor(
    AbilityKind kind,
    int subclassClassType,
    int subclassElement,
  ) =>
      [
        for (final e in _all)
          if (e.matchesClass(subclassClassType) &&
              e.matchesGeneral(kind, subclassElement) &&
              !e.isSynergy(subclassElement))
            e,
      ];

  @override
  List<ExoticAbilityInteraction> synergyExoticsFor(
    int subclassClassType,
    int subclassElement,
  ) =>
      [
        for (final e in _all)
          if (e.matchesClass(subclassClassType) && e.isSynergy(subclassElement))
            e,
      ];

  @override
  List<({ExoticAbilityInteraction exotic, List<String> names})>
      namedColumnExoticsFor(
    AbilityKind kind,
    int subclassClassType,
    int subclassElement,
    Iterable<String> socketPlugNames,
  ) =>
          [
            for (final e in _all)
              if (e.matchesClass(subclassClassType))
                if (e.matchedNames(kind, socketPlugNames, subclassElement)
                    case final List<String> names when names.isNotEmpty)
                  (exotic: e, names: names),
          ];
}

/// Records the last insertPlug / equipSubclass call so a modal action can be
/// verified without a live grid / transfer path.
class _SpyMoveController extends MoveController {
  ({int socketIndex, int plugHash, String plugName})? lastInsert;
  DestinyItem? lastEquippedSubclass;

  @override
  Future<void> insertPlug(
    DestinyItem item, {
    required int socketIndex,
    required int plugHash,
    required String plugName,
  }) async {
    lastInsert =
        (socketIndex: socketIndex, plugHash: plugHash, plugName: plugName);
  }

  @override
  Future<void> equipSubclass(DestinyItem subclass) async {
    lastEquippedSubclass = subclass;
  }
}

/// A subclass with two groups: ABILITIES (one socket, two options) and SUPER
/// (one socket, one option).
SubclassDetail _detail() {
  const item = DestinyItem(
    itemHash: 1,
    bucketHash: 3284755031,
    name: 'Dawnblade',
    iconPath: '',
    itemType: 16,
    itemInstanceId: '444',
  );
  return const SubclassDetail(
    item: item,
    element: 3, // Solar
    screenshotPath: '',
    groups: [
      SubclassSocketGroup(label: 'ABILITIES', sockets: [
        SubclassSocket(
          socketIndex: 0,
          // Phoenix Dive (equipped) and Healing Rift are unlocked; Icarus Dash
          // is a valid option the character has NOT unlocked (view-only);
          // Empowering Rift is owned but equipped in another slot.
          equippableHashes: {6010, 6011},
          equippedElsewhereHashes: {6013},
          equipped: ItemPlug(
              name: 'Phoenix Dive',
              iconPath: '',
              category: PlugCategory.perk,
              plugHash: 6010,
              socketIndex: 0),
          options: [
            ItemPlug(
                name: 'Phoenix Dive',
                iconPath: '',
                category: PlugCategory.perk,
                plugHash: 6010,
                socketIndex: 0),
            ItemPlug(
                name: 'Healing Rift',
                iconPath: '',
                category: PlugCategory.perk,
                plugHash: 6011,
                socketIndex: 0),
            ItemPlug(
                name: 'Icarus Dash',
                iconPath: '',
                category: PlugCategory.perk,
                plugHash: 6012,
                socketIndex: 0),
            ItemPlug(
                name: 'Empowering Rift',
                iconPath: '',
                category: PlugCategory.perk,
                plugHash: 6013,
                socketIndex: 0),
          ],
        ),
      ]),
      SubclassSocketGroup(label: 'SUPER', sockets: [
        SubclassSocket(
          socketIndex: 2,
          equipped: ItemPlug(
              name: 'Daybreak',
              iconPath: '',
              category: PlugCategory.perk,
              plugHash: 6020,
              socketIndex: 2),
          options: [
            ItemPlug(
                name: 'Daybreak',
                iconPath: '',
                category: PlugCategory.perk,
                plugHash: 6020,
                socketIndex: 2),
          ],
        ),
      ]),
      // A locked (over-capacity) empty fragment socket: it HAS options, so a
      // picker would open if it weren't disabled.
      SubclassSocketGroup(label: 'FRAGMENTS', sockets: [
        SubclassSocket(
          socketIndex: 7,
          available: false,
          equipped: ItemPlug(
              name: 'Empty Fragment Socket',
              iconPath: '',
              category: PlugCategory.perk,
              plugHash: 6030,
              socketIndex: 7),
          options: [
            ItemPlug(
                name: 'Empty Fragment Socket',
                iconPath: '',
                category: PlugCategory.perk,
                plugHash: 6030,
                socketIndex: 7),
            ItemPlug(
                name: 'Echo of Persistence',
                iconPath: '',
                category: PlugCategory.perk,
                plugHash: 6031,
                socketIndex: 7),
          ],
        ),
      ]),
    ],
  );
}

/// A not-owned (definition-only) subclass: no instance, nothing equipped, no
/// equippable hashes — one SUPER socket with two options, both view-only.
SubclassDetail _notOwnedDetail() {
  const item = DestinyItem(
    itemHash: 2,
    bucketHash: 3284755031,
    name: 'Broodweaver',
    iconPath: '',
    itemType: 16,
    // No itemInstanceId — the character does not own it.
  );
  return const SubclassDetail(
    item: item,
    element: 7, // Strand
    screenshotPath: '',
    owned: false,
    groups: [
      SubclassSocketGroup(label: 'SUPER', sockets: [
        SubclassSocket(
          socketIndex: 2,
          equipped: null, // nothing equipped
          options: [
            ItemPlug(
                name: 'Needlestorm',
                iconPath: '',
                category: PlugCategory.perk,
                plugHash: 7001,
                socketIndex: 2),
            ItemPlug(
                name: 'Weaver\'s Call',
                iconPath: '',
                category: PlugCategory.perk,
                plugHash: 7002,
                socketIndex: 2),
          ],
          // equippableHashes / equippedElsewhereHashes empty → all locked.
        ),
      ]),
    ],
  );
}

void main() {
  Widget host(_SpyMoveController spy) => ProviderScope(
        overrides: [
          subclassDetailProvider.overrideWith((ref) => _detail()),
          moveControllerProvider.overrideWith(() => spy),
          // No Clarity coverage: the icon tooltips carry no insight block.
          clarityInsightProvider.overrideWith((ref, hash) => null),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SubclassDetailModal()),
        ),
      );

  testWidgets('renders every socket group with its equipped plug names',
      (tester) async {
    await tester.pumpWidget(host(_SpyMoveController()));
    await tester.pumpAndSettle();

    expect(find.text('ABILITIES'), findsOneWidget);
    expect(find.text('SUPER'), findsOneWidget);
    // Equipped plug labels shown beneath each socket chip.
    expect(find.text('Phoenix Dive'), findsWidgets);
    expect(find.text('Daybreak'), findsOneWidget);
    expect(find.text('Dawnblade'), findsOneWidget); // header
  });

  testWidgets('an owned, not-equipped subclass shows an Equip button that '
      'equips it', (tester) async {
    // _detail() is owned (instance 444) and not equipped → the button shows.
    final spy = _SpyMoveController();
    await tester.pumpWidget(host(spy));
    await tester.pumpAndSettle();

    final equip = find.widgetWithText(FilledButton, 'Equip');
    expect(equip, findsOneWidget);
    await tester.tap(equip);
    await tester.pumpAndSettle();
    expect(spy.lastEquippedSubclass?.name, 'Dawnblade');
  });

  testWidgets('an already-equipped subclass shows no Equip button',
      (tester) async {
    // Same as _detail() but the subclass is the equipped one.
    const item = DestinyItem(
      itemHash: 1,
      bucketHash: 3284755031,
      name: 'Dawnblade',
      iconPath: '',
      itemType: 16,
      itemInstanceId: '444',
      isEquipped: true,
    );
    final detail = SubclassDetail(
      item: item,
      element: 3,
      screenshotPath: '',
      groups: _detail().groups,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        subclassDetailProvider.overrideWith((ref) => detail),
        moveControllerProvider.overrideWith(() => _SpyMoveController()),
        clarityInsightProvider.overrideWith((ref, hash) => null),
      ],
      child: const MaterialApp(home: Scaffold(body: SubclassDetailModal())),
    ));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Equip'), findsNothing);
  });

  testWidgets('a not-owned subclass shows no Equip button', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        subclassDetailProvider.overrideWith((ref) => _notOwnedDetail()),
        moveControllerProvider.overrideWith(() => _SpyMoveController()),
        clarityInsightProvider.overrideWith((ref, hash) => null),
      ],
      child: const MaterialApp(home: Scaffold(body: SubclassDetailModal())),
    ));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Equip'), findsNothing);
  });

  testWidgets('the fragment stat summary renders its net stat totals',
      (tester) async {
    const item = DestinyItem(
      itemHash: 3,
      bucketHash: 3284755031,
      name: 'Voidwalker',
      iconPath: '',
      itemType: 16,
      itemInstanceId: '999',
    );
    const detail = SubclassDetail(
      item: item,
      element: 4,
      screenshotPath: '',
      groups: [
        SubclassSocketGroup(label: 'FRAGMENTS', isFragments: true, sockets: [
          SubclassSocket(
            socketIndex: 7,
            equipped: ItemPlug(
                name: 'Echo of Instability',
                iconPath: '',
                category: PlugCategory.perk,
                plugHash: 8001,
                socketIndex: 7),
            options: [],
          ),
        ]),
      ],
      fragmentStatSummary: [
        SubclassStatEffect(
            hash: 1, name: 'Discipline', iconPath: '', value: -20,
            beneficial: false),
        SubclassStatEffect(
            hash: 2, name: 'Strength', iconPath: '', value: 10,
            beneficial: true),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        subclassDetailProvider.overrideWith((ref) => detail),
        moveControllerProvider.overrideWith(() => _SpyMoveController()),
        clarityInsightProvider.overrideWith((ref, hash) => null),
      ],
      child: const MaterialApp(home: Scaffold(body: SubclassDetailModal())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('FRAGMENT STATS'), findsOneWidget);
    expect(find.text('-20'), findsOneWidget); // Discipline net
    expect(find.text('+10'), findsOneWidget); // Strength net (signed +)
  });

  testWidgets('tapping an option fires insertPlug with the socket/plug',
      (tester) async {
    final spy = _SpyMoveController();
    await tester.pumpWidget(host(spy));
    await tester.pumpAndSettle();

    // Open the ABILITIES socket picker (socket index 0) by tapping its icon.
    await tester.tap(find.byKey(const ValueKey('subclass-socket-0')));
    await tester.pumpAndSettle();

    // The menu now lists options as icon-only cells (no label), keyed by plug
    // hash. Tap the Healing Rift option (hash 6011).
    await tester.tap(find.byKey(const ValueKey('subclass-option-6011')));
    await tester.pumpAndSettle();

    expect(spy.lastInsert, isNotNull);
    expect(spy.lastInsert!.socketIndex, 0);
    expect(spy.lastInsert!.plugHash, 6011);
    expect(spy.lastInsert!.plugName, 'Healing Rift');
  });

  testWidgets('an unowned option is view-only: tapping it fires no insert',
      (tester) async {
    final spy = _SpyMoveController();
    await tester.pumpWidget(host(spy));
    await tester.pumpAndSettle();

    // Open the ABILITIES picker; Icarus Dash (6012) is a valid option the
    // character has NOT unlocked, so it is shown but not equippable.
    await tester.tap(find.byKey(const ValueKey('subclass-socket-0')));
    await tester.pumpAndSettle();

    // It IS present (viewable)…
    expect(find.byKey(const ValueKey('subclass-option-6012')), findsOneWidget);
    // …but tapping it does nothing (no insert). warnIfMissed: false — the icon
    // has no tap handler when view-only, which is the behavior under test.
    await tester.tap(find.byKey(const ValueKey('subclass-option-6012')),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(spy.lastInsert, isNull);
  });

  testWidgets('an unowned option tooltip shows a "Not unlocked" notice',
      (tester) async {
    await tester.pumpWidget(host(_SpyMoveController()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('subclass-socket-0')));
    await tester.pumpAndSettle();

    // Hover the unowned option to raise its tooltip.
    final gesture =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(
        find.byKey(const ValueKey('subclass-option-6012'))));
    await tester.pumpAndSettle();

    expect(find.text('Not unlocked'), findsOneWidget);
  });

  testWidgets(
      'an option equipped in another slot is shown, not selectable, and its '
      'tooltip says so', (tester) async {
    final spy = _SpyMoveController();
    await tester.pumpWidget(host(spy));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('subclass-socket-0')));
    await tester.pumpAndSettle();

    // Empowering Rift (6013) is owned but equipped in another slot: present,
    // but tapping it fires no insert.
    expect(find.byKey(const ValueKey('subclass-option-6013')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('subclass-option-6013')),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(spy.lastInsert, isNull);

    // Its tooltip distinguishes it from a locked one.
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(
        find.byKey(const ValueKey('subclass-option-6013'))));
    await tester.pumpAndSettle();
    expect(find.text('Equipped in another slot'), findsOneWidget);
    expect(find.text('Not unlocked'), findsNothing);
  });

  testWidgets('a single-option socket does not open a picker', (tester) async {
    final spy = _SpyMoveController();
    await tester.pumpWidget(host(spy));
    await tester.pumpAndSettle();

    // Tapping the SUPER chip (only Daybreak) does nothing — no insert fires.
    await tester.tap(find.text('Daybreak'));
    await tester.pumpAndSettle();
    expect(spy.lastInsert, isNull);
  });

  testWidgets('a locked (over-capacity) fragment socket opens no picker',
      (tester) async {
    final spy = _SpyMoveController();
    await tester.pumpWidget(host(spy));
    await tester.pumpAndSettle();

    // Socket 7 is available:false. Tapping its icon must not open the option
    // grid, so the alternate option never appears and no insert fires.
    await tester.tap(find.byKey(const ValueKey('subclass-socket-7')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('subclass-option-6031')), findsNothing);
    expect(spy.lastInsert, isNull);
  });

  testWidgets('Clarity-covered plugs do not overflow the socket chips',
      (tester) async {
    // Regression: the insight used to render as a per-chip expander wider than
    // the ~52px icon chip, tripping RenderFlex overflow. It now lives in the
    // hover tooltip, so a covered plug must lay out cleanly with no exception.
    const covered = ClarityInsight(
      hash: 0,
      name: 'x',
      lines: [
        ClarityLine(content: [
          ClaritySpan(text: 'A fairly long community insight sentence.')
        ])
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        subclassDetailProvider.overrideWith((ref) => _detail()),
        moveControllerProvider.overrideWith(() => _SpyMoveController()),
        // Every plug is covered — the worst case for chip width.
        clarityInsightProvider.overrideWith((ref, hash) => covered),
      ],
      child: const MaterialApp(home: Scaffold(body: SubclassDetailModal())),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SubclassDetailModal), findsOneWidget);
  });

  // Name-scoped exotics badge their specific ability (icon marker + tooltip);
  // general (type-level / element-gated) exotics list in the right column.
  group('exotic-interaction badge + general column', () {
    // A Warlock subclass with one grenade socket (Solar/Firebolt options).
    SubclassDetail grenadeDetail() => const SubclassDetail(
          item: DestinyItem(
            itemHash: 1,
            bucketHash: 3284755031,
            name: 'Dawnblade',
            iconPath: '',
            itemType: 16,
            itemInstanceId: '444',
            classType: 2, // Warlock
          ),
          element: 3,
          screenshotPath: '',
          groups: [
            SubclassSocketGroup(label: 'ABILITIES', sockets: [
              SubclassSocket(
                socketIndex: 0,
                abilityKind: AbilityKind.grenade,
                equipped: ItemPlug(
                    name: 'Solar Grenade',
                    iconPath: '',
                    category: PlugCategory.perk,
                    plugHash: 5000,
                    socketIndex: 0),
                options: [
                  ItemPlug(
                      name: 'Solar Grenade',
                      iconPath: '',
                      category: PlugCategory.perk,
                      plugHash: 5000,
                      socketIndex: 0),
                  ItemPlug(
                      name: 'Firebolt Grenade',
                      iconPath: '',
                      category: PlugCategory.perk,
                      plugHash: 5001,
                      socketIndex: 0),
                ],
              ),
            ]),
          ],
        );

    // Name-scoped to the Solar Grenade the socket offers → badges the ability.
    const namedGrenadeExotic = ExoticAbilityInteraction(
      itemHash: 111,
      name: 'Starfire Protocol',
      classType: 2,
      interactions: [
        AbilityInteraction(kind: AbilityKind.grenade, names: ['Solar Grenade']),
      ],
    );
    // Multi-kind general (grenade + melee) → a synergy piece, listed once in the
    // ABILITY SYNERGY section, not repeated per kind.
    const synergyExotic = ExoticAbilityInteraction(
      itemHash: 333,
      name: 'Fallen Sunstar',
      classType: 2,
      interactions: [
        AbilityInteraction(kind: AbilityKind.grenade),
        AbilityInteraction(kind: AbilityKind.melee),
      ],
    );
    // Type-level → belongs in the general column, never badged. Carries an
    // effect description + a perk hash (for the Clarity lookup).
    const generalGrenadeExotic = ExoticAbilityInteraction(
      itemHash: 222,
      name: 'Contraverse Hold',
      classType: 2,
      interactions: [AbilityInteraction(kind: AbilityKind.grenade)],
      perkHash: 8507332,
      description: 'Damage resistance while charging a Void grenade.',
    );

    testWidgets('a name-scoped exotic badges the ability and shows in tooltip',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          subclassDetailProvider.overrideWith((ref) => grenadeDetail()),
          moveControllerProvider.overrideWith(() => _SpyMoveController()),
          clarityInsightProvider.overrideWith((ref, hash) => null),
          loadedExoticAbilityRepositoryProvider
              .overrideWithValue(_FakeExoticRepo([namedGrenadeExotic])),
        ],
        child: const MaterialApp(home: Scaffold(body: SubclassDetailModal())),
      ));
      await tester.pumpAndSettle();

      // Badged on the ability (Solar Grenade is equipped)…
      expect(find.byIcon(Icons.star), findsOneWidget);
      // …and also listed in the GRENADE column with its specific-ability
      // subtitle (a name-scoped exotic shows in the column too, as a discovery
      // aid), so its name appears in both places.
      expect(find.text('Starfire Protocol'), findsWidgets);
      expect(find.text('Solar Grenade'), findsWidgets);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(
          tester.getCenter(find.byKey(const ValueKey('subclass-socket-0'))));
      await tester.pumpAndSettle();
      // The socket tooltip lists it too.
      expect(find.text('Starfire Protocol'), findsWidgets);
    });

    testWidgets('a general exotic is NOT badged; it lists in the right column',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          subclassDetailProvider.overrideWith((ref) => grenadeDetail()),
          moveControllerProvider.overrideWith(() => _SpyMoveController()),
          clarityInsightProvider.overrideWith((ref, hash) => null),
          loadedExoticAbilityRepositoryProvider
              .overrideWithValue(_FakeExoticRepo([generalGrenadeExotic])),
        ],
        child: const MaterialApp(home: Scaffold(body: SubclassDetailModal())),
      ));
      await tester.pumpAndSettle();

      // No ability badge…
      expect(find.byIcon(Icons.star), findsNothing);
      // …but the general column lists it under its GRENADE header.
      expect(find.text('EXOTIC ARMOR'), findsOneWidget);
      expect(find.text('GRENADE'), findsOneWidget);
      expect(find.text('Contraverse Hold'), findsOneWidget);
    });

    testWidgets('a multi-kind exotic lists once under ABILITY SYNERGY',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          subclassDetailProvider.overrideWith((ref) => grenadeDetail()),
          moveControllerProvider.overrideWith(() => _SpyMoveController()),
          clarityInsightProvider.overrideWith((ref, hash) => null),
          loadedExoticAbilityRepositoryProvider
              .overrideWithValue(_FakeExoticRepo([synergyExotic])),
        ],
        child: const MaterialApp(home: Scaffold(body: SubclassDetailModal())),
      ));
      await tester.pumpAndSettle();

      // Listed once, under the synergy header, with its affected-kinds subtitle.
      expect(find.text('ABILITY SYNERGY'), findsOneWidget);
      expect(find.text('Fallen Sunstar'), findsOneWidget);
      expect(find.text('Grenade, Melee'), findsOneWidget);
      // It must NOT also appear under a per-kind GRENADE header (no duplication).
      expect(find.text('GRENADE'), findsNothing);
    });

    testWidgets('a general-column row shows effect + Clarity in its tooltip',
        (tester) async {
      const insight = ClarityInsight(
        hash: 8507332,
        name: 'Chaotic Exchanger',
        lines: [
          ClarityLine(content: [ClaritySpan(text: 'Grants 20% Damage Resistance.')])
        ],
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          subclassDetailProvider.overrideWith((ref) => grenadeDetail()),
          moveControllerProvider.overrideWith(() => _SpyMoveController()),
          // Clarity covers exactly this exotic's perk hash.
          clarityInsightProvider.overrideWith(
              (ref, hash) => hash == 8507332 ? insight : null),
          loadedExoticAbilityRepositoryProvider
              .overrideWithValue(_FakeExoticRepo([generalGrenadeExotic])),
        ],
        child: const MaterialApp(home: Scaffold(body: SubclassDetailModal())),
      ));
      await tester.pumpAndSettle();

      // Hover the general-column row (its name is unique to that column).
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture
          .moveTo(tester.getCenter(find.text('Contraverse Hold')));
      await tester.pumpAndSettle();

      // The tooltip shows both the manifest effect and the Clarity insight.
      expect(find.text('Damage resistance while charging a Void grenade.'),
          findsOneWidget);
      expect(find.text('COMMUNITY INSIGHT · CLARITY'), findsOneWidget);
      expect(find.text('Grants 20% Damage Resistance.'), findsOneWidget);
    });

    testWidgets('shows no badge and no column when nothing interacts',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          subclassDetailProvider.overrideWith((ref) => grenadeDetail()),
          moveControllerProvider.overrideWith(() => _SpyMoveController()),
          clarityInsightProvider.overrideWith((ref, hash) => null),
          loadedExoticAbilityRepositoryProvider
              .overrideWithValue(_FakeExoticRepo(const [])),
        ],
        child: const MaterialApp(home: Scaffold(body: SubclassDetailModal())),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star), findsNothing);
      expect(find.text('EXOTIC ARMOR'), findsNothing);
    });

    testWidgets('does not badge a socket the named ability is absent from',
        (tester) async {
      // Ballidorse buffs only Winter's Wrath (a super); the lone socket is a
      // grenade socket, so it must neither badge nor appear in the grenade
      // column (name-scoped exotics never populate the general column).
      const ballidorse = ExoticAbilityInteraction(
        itemHash: 3831935023,
        name: 'Ballidorse Wrathweavers',
        classType: 2,
        interactions: [
          AbilityInteraction(
              kind: AbilityKind.superAbility, names: ["Winter's Wrath"]),
        ],
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          subclassDetailProvider.overrideWith((ref) => grenadeDetail()),
          moveControllerProvider.overrideWith(() => _SpyMoveController()),
          clarityInsightProvider.overrideWith((ref, hash) => null),
          loadedExoticAbilityRepositoryProvider
              .overrideWithValue(_FakeExoticRepo([ballidorse])),
        ],
        child: const MaterialApp(home: Scaffold(body: SubclassDetailModal())),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star), findsNothing);
      expect(find.text('Ballidorse Wrathweavers'), findsNothing);
    });

    testWidgets(
        'a name-scoped super exotic badges only the EQUIPPED super, not another '
        'the socket could hold', (tester) async {
      // Regression: the one super socket lists every super as an option, so
      // matching options badged Stormdancer's Brace (→ Stormtrance) on a
      // Chaos-Reach-equipped socket. The badge must track the equipped super.
      const stormdancers = ExoticAbilityInteraction(
        itemHash: 1747063685,
        name: "Stormdancer's Brace",
        classType: 2,
        interactions: [
          AbilityInteraction(
              kind: AbilityKind.superAbility, names: ['Stormtrance']),
        ],
      );
      // A super socket with Chaos Reach equipped; Stormtrance is a selectable
      // option (as in-game, the socket can hold either).
      const detail = SubclassDetail(
        item: DestinyItem(
          itemHash: 9,
          bucketHash: 3284755031,
          name: 'Stormcaller',
          iconPath: '',
          itemType: 16,
          itemInstanceId: '555',
          classType: 2,
        ),
        element: 2, // Arc
        screenshotPath: '',
        groups: [
          SubclassSocketGroup(label: 'SUPER', isSuper: true, sockets: [
            SubclassSocket(
              socketIndex: 2,
              abilityKind: AbilityKind.superAbility,
              equipped: ItemPlug(
                  name: 'Chaos Reach',
                  iconPath: '',
                  category: PlugCategory.perk,
                  plugHash: 9001,
                  socketIndex: 2),
              options: [
                ItemPlug(
                    name: 'Chaos Reach',
                    iconPath: '',
                    category: PlugCategory.perk,
                    plugHash: 9001,
                    socketIndex: 2),
                ItemPlug(
                    name: 'Stormtrance',
                    iconPath: '',
                    category: PlugCategory.perk,
                    plugHash: 9002,
                    socketIndex: 2),
              ],
            ),
          ]),
        ],
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          subclassDetailProvider.overrideWith((ref) => detail),
          moveControllerProvider.overrideWith(() => _SpyMoveController()),
          clarityInsightProvider.overrideWith((ref, hash) => null),
          loadedExoticAbilityRepositoryProvider
              .overrideWithValue(_FakeExoticRepo([stormdancers])),
        ],
        child: const MaterialApp(home: Scaffold(body: SubclassDetailModal())),
      ));
      await tester.pumpAndSettle();

      // Chaos Reach is equipped → NO badge (the badge tracks the equipped
      // super, and Stormdancer buffs Stormtrance, not Chaos Reach).
      expect(find.byIcon(Icons.star), findsNothing);
      // But it IS listed in the SUPER column (the socket can hold Stormtrance),
      // with a "Stormtrance" subtitle — a discovery aid, not tied to equipped.
      expect(find.text("Stormdancer's Brace"), findsOneWidget);
      expect(find.text('Stormtrance'), findsWidgets);
      // A SUPER header is present (the left group label and the column header
      // both read "SUPER", so at least one exists).
      expect(find.text('SUPER'), findsWidgets);
    });

    testWidgets('a name-scoped super exotic badges when its super IS equipped',
        (tester) async {
      // The positive counterpart: Stormtrance equipped → Stormdancer's Brace
      // badges the socket and shows in its tooltip.
      const stormdancers = ExoticAbilityInteraction(
        itemHash: 1747063685,
        name: "Stormdancer's Brace",
        classType: 2,
        interactions: [
          AbilityInteraction(
              kind: AbilityKind.superAbility, names: ['Stormtrance']),
        ],
      );
      const detail = SubclassDetail(
        item: DestinyItem(
          itemHash: 9,
          bucketHash: 3284755031,
          name: 'Stormcaller',
          iconPath: '',
          itemType: 16,
          itemInstanceId: '555',
          classType: 2,
        ),
        element: 2,
        screenshotPath: '',
        groups: [
          SubclassSocketGroup(label: 'SUPER', isSuper: true, sockets: [
            SubclassSocket(
              socketIndex: 2,
              abilityKind: AbilityKind.superAbility,
              equipped: ItemPlug(
                  name: 'Stormtrance',
                  iconPath: '',
                  category: PlugCategory.perk,
                  plugHash: 9002,
                  socketIndex: 2),
              options: [
                ItemPlug(
                    name: 'Chaos Reach',
                    iconPath: '',
                    category: PlugCategory.perk,
                    plugHash: 9001,
                    socketIndex: 2),
                ItemPlug(
                    name: 'Stormtrance',
                    iconPath: '',
                    category: PlugCategory.perk,
                    plugHash: 9002,
                    socketIndex: 2),
              ],
            ),
          ]),
        ],
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          subclassDetailProvider.overrideWith((ref) => detail),
          moveControllerProvider.overrideWith(() => _SpyMoveController()),
          clarityInsightProvider.overrideWith((ref, hash) => null),
          loadedExoticAbilityRepositoryProvider
              .overrideWithValue(_FakeExoticRepo([stormdancers])),
        ],
        child: const MaterialApp(home: Scaffold(body: SubclassDetailModal())),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star), findsOneWidget);
    });
  });

  testWidgets(
      'a not-owned subclass shows the NOT UNLOCKED pill and browsable, '
      'unselectable options', (tester) async {
    final spy = _SpyMoveController();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        subclassDetailProvider.overrideWith((ref) => _notOwnedDetail()),
        moveControllerProvider.overrideWith(() => spy),
        clarityInsightProvider.overrideWith((ref, hash) => null),
      ],
      child: const MaterialApp(home: Scaffold(body: SubclassDetailModal())),
    ));
    await tester.pumpAndSettle();

    // The lock pill and name render.
    expect(find.text('NOT UNLOCKED'), findsOneWidget);
    expect(find.text('Broodweaver'), findsOneWidget);

    // The socket chip renders (its first option, since nothing is equipped), so
    // the group is not empty. Open its picker.
    await tester.tap(find.byKey(const ValueKey('subclass-socket-2')));
    await tester.pumpAndSettle();

    // Both options are browsable in the grid…
    expect(find.byKey(const ValueKey('subclass-option-7001')), findsOneWidget);
    expect(find.byKey(const ValueKey('subclass-option-7002')), findsOneWidget);
    // …but neither can be selected (no insert fires).
    await tester.tap(find.byKey(const ValueKey('subclass-option-7002')),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(spy.lastInsert, isNull);
  });

  group('SubclassSocket.optionState precedence', () {
    ItemPlug plug(int hash) => ItemPlug(
        name: 'p$hash', iconPath: '', category: PlugCategory.perk, plugHash: hash);

    // A fragment socket: 1 is equipped here; 2 is equipped in another slot AND
    // also reported insertable account-wide (canInsert); 3 is unlocked; 4 is
    // locked.
    const socket = SubclassSocket(
      socketIndex: 7,
      equipped: ItemPlug(
          name: 'p1', iconPath: '', category: PlugCategory.perk, plugHash: 1),
      options: [],
      equippableHashes: {1, 2, 3},
      equippedElsewhereHashes: {2},
    );

    test('the equipped-here plug is equippable', () {
      expect(socket.optionState(plug(1)), SubclassOptionState.equippable);
    });

    test('equipped-elsewhere wins over canInsert (the reported bug)', () {
      // Hash 2 is in BOTH equippableHashes and equippedElsewhereHashes — it must
      // read as equipped-elsewhere, not equippable, so a duplicate can't be
      // socketed.
      expect(
          socket.optionState(plug(2)), SubclassOptionState.equippedElsewhere);
      expect(socket.canEquip(plug(2)), isFalse);
    });

    test('an unlocked (canInsert) plug is equippable', () {
      expect(socket.optionState(plug(3)), SubclassOptionState.equippable);
    });

    test('an unowned plug is locked', () {
      expect(socket.optionState(plug(4)), SubclassOptionState.locked);
    });
  });
}
