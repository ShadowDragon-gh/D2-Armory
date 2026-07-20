import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:d2_armory/core/destiny/plug_category.dart';
import 'package:d2_armory/domain/models/clarity_insight.dart';
import 'package:d2_armory/domain/models/destiny_item.dart';
import 'package:d2_armory/domain/models/item_detail.dart';
import 'package:d2_armory/domain/models/subclass_detail.dart';
import 'package:d2_armory/presentation/providers/clarity_provider.dart';
import 'package:d2_armory/presentation/providers/inventory_provider.dart';
import 'package:d2_armory/presentation/screens/inventory/subclass_detail_modal.dart';

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
