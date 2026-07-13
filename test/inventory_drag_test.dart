import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:d2_armory/core/destiny/destiny_buckets.dart';
import 'package:d2_armory/core/errors/failures.dart';
import 'package:d2_armory/data/repositories/item_transfer_repository.dart';
import 'package:d2_armory/domain/models/destiny_character.dart';
import 'package:d2_armory/domain/models/destiny_item.dart';
import 'package:d2_armory/domain/models/inventory_grid.dart';
import 'package:d2_armory/presentation/providers/inventory_provider.dart';
import 'package:d2_armory/presentation/screens/inventory/inventory_screen.dart';

class _MockTransfer extends Mock implements ItemTransferRepository {}

class _FakeOwner extends Fake implements InventoryOwner {}

/// A grid notifier that serves a fixed grid (no network), for widget tests.
class _FixedGridNotifier extends InventoryGridNotifier {
  _FixedGridNotifier(this._fixed);
  final InventoryGrid _fixed;
  @override
  Future<InventoryGrid> build() async => _fixed;
}

const _kinetic = EquipmentBucket.kineticWeapons;

DestinyItem _vaultRifle() => const DestinyItem(
      itemHash: 555,
      bucketHash: 1498876634, // kinetic
      name: 'Vault Rifle',
      iconPath: '',
      itemInstanceId: 'inst-1',
    );

DestinyCharacter _hunter() => DestinyCharacter(
      characterId: 'charA',
      classType: 1,
      light: 1900,
      emblemPath: '',
      emblemBackgroundPath: '',
      dateLastPlayed: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );

InventoryGrid _grid() {
  final character = InventoryOwner(
    id: 'charA',
    title: 'Hunter',
    isVault: false,
    character: _hunter(),
    itemsByBucket: const {},
  );
  final vault = InventoryOwner(
    id: 'vault',
    title: 'Vault',
    isVault: true,
    itemsByBucket: {
      _kinetic.hash: [_vaultRifle()],
    },
  );
  return InventoryGrid([character, vault]);
}

/// A grid where the Hunter holds an equipped rifle plus an unequipped one in
/// the same bucket, so an unequipped copy can be dragged onto the equipped slot.
InventoryGrid _gridWithEquippable() {
  const equipped = DestinyItem(
    itemHash: 555,
    bucketHash: 1498876634,
    name: 'Equipped Rifle',
    iconPath: '',
    itemInstanceId: 'equipped-1',
    classType: 1,
    isEquipped: true,
  );
  const spare = DestinyItem(
    itemHash: 556,
    bucketHash: 1498876634,
    name: 'Spare Rifle',
    iconPath: '',
    itemInstanceId: 'spare-1',
    classType: 1,
  );
  return InventoryGrid([
    InventoryOwner(
      id: 'charA',
      title: 'Hunter',
      isVault: false,
      character: _hunter(),
      itemsByBucket: const {
        1498876634: [equipped, spare],
      },
    ),
    const InventoryOwner(
      id: 'vault',
      title: 'Vault',
      isVault: true,
      itemsByBucket: {},
    ),
  ]);
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeOwner());
    registerFallbackValue(_vaultRifle());
  });

  late _MockTransfer transfer;

  setUp(() {
    transfer = _MockTransfer();
    when(() => transfer.moveItem(any(), any(), any())).thenAnswer((_) async {});
    when(() => transfer.equip(any(), any())).thenAnswer((_) async {});
  });

  Widget harness() => ProviderScope(
        overrides: [
          inventoryGridProvider.overrideWith(() => _FixedGridNotifier(_grid())),
          itemTransferRepositoryProvider.overrideWithValue(transfer),
        ],
        // A Scaffold supplies the ScaffoldMessenger the move snackbar needs.
        child: const MaterialApp(
          home: Scaffold(body: InventoryScreen()),
        ),
      );

  testWidgets('dragging a vault tile onto a character dispatches a move to '
      'that character', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // The vault rifle is the only draggable tile in the grid.
    final rifle = find.byType(Draggable<ItemDrag>);
    expect(rifle, findsOneWidget);

    // Every bucket cell (character + vault) is a DragTarget; the character's
    // kinetic cell is the first one, in the same bucket row as the vault rifle.
    // Drop onto the character column at the rifle's own vertical position (same
    // row), shifted into the character column via its header's x-centre.
    final characterHeader = find.text('Hunter');
    expect(characterHeader, findsOneWidget);

    final from = tester.getCenter(rifle);
    final characterX = tester.getCenter(characterHeader).dx;
    final to = Offset(characterX, from.dy);

    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 50));
    // Move in two steps so the DragTarget registers the hover before release.
    await gesture.moveTo(Offset((from.dx + characterX) / 2, from.dy));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(to);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    // Let the drop dispatch and the success toast animate in. (Not
    // pumpAndSettle: the toast holds on a timer before auto-dismissing.)
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The move dispatched: vault rifle → the Hunter character.
    final captured =
        verify(() => transfer.moveItem(captureAny(), captureAny(), captureAny()))
            .captured;
    final item = captured[0] as DestinyItem;
    final from2 = captured[1] as InventoryOwner;
    final to2 = captured[2] as InventoryOwner;
    expect(item.itemInstanceId, 'inst-1');
    expect(from2.id, 'vault');
    expect(to2.id, 'charA');

    // Drain the toast's hold + slide-out so no timer outlives the test.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('a failed move shows an error toast and does not claim success',
      (tester) async {
    // The controller catches Failure and surfaces its message.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryGridProvider.overrideWith(() => _FixedGridNotifier(_grid())),
          itemTransferRepositoryProvider.overrideWithValue(transfer),
        ],
        child: const MaterialApp(home: Scaffold(body: InventoryScreen())),
      ),
    );
    await tester.pumpAndSettle();

    // Directly exercise the controller failure path (drag geometry is covered
    // by the test above): a failed move must surface its message, not success.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(InventoryScreen)),
    );
    when(() => transfer.moveItem(any(), any(), any())).thenThrow(
      // A stranded-in-vault style partial failure the controller surfaces.
      const ApiFailure('Moved to the vault, but could not reach Hunter.'),
    );

    final grid = await container.read(inventoryGridProvider.future);
    final vault = grid.owners.firstWhere((o) => o.isVault);
    final character = grid.owners.firstWhere((o) => !o.isVault);
    await container.read(moveControllerProvider.notifier).move(
          ItemDrag(item: _vaultRifle(), fromOwnerId: vault.id),
          character,
        );
    // Let the failure toast animate in (not pumpAndSettle: it holds on a timer).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The failure message is shown, tagged as a failure by the toast's heading.
    expect(find.text('Moved to the vault, but could not reach Hunter.'),
        findsOneWidget);
    expect(find.text('Move failed'), findsOneWidget);

    // Drain the toast's hold + slide-out so no timer outlives the test.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('dropping a spare copy on the equipped slot equips it (not move)',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        inventoryGridProvider
            .overrideWith(() => _FixedGridNotifier(_gridWithEquippable())),
        itemTransferRepositoryProvider.overrideWithValue(transfer),
      ],
      child: const MaterialApp(home: Scaffold(body: InventoryScreen())),
    ));
    await tester.pumpAndSettle();

    // Only the unequipped spare is draggable (equipped items are not).
    final spare = find.byType(Draggable<ItemDrag>);
    expect(spare, findsOneWidget);

    // The equipped slot is the 72px tile; drop the spare on it. The equipped
    // tile renders the "Equipped Rifle" — target its position.
    final from = tester.getCenter(spare);
    // The equipped slot sits to the left of the spare in the same row.
    final to = Offset(from.dx - 100, from.dy);

    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(Offset((from.dx + to.dx) / 2, from.dy));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(to);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Equip dispatched for the spare on charA; no transfer move happened.
    final captured =
        verify(() => transfer.equip(captureAny(), captureAny())).captured;
    expect((captured[0] as DestinyItem).itemInstanceId, 'spare-1');
    expect((captured[1] as InventoryOwner).id, 'charA');
    verifyNever(() => transfer.moveItem(any(), any(), any()));

    await tester.pump(const Duration(seconds: 4)); // drain the success toast
  });

  group('grid patch on move (no refetch)', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(overrides: [
        inventoryGridProvider.overrideWith(() => _FixedGridNotifier(_grid())),
        itemTransferRepositoryProvider.overrideWithValue(transfer),
      ]);
      addTearDown(container.dispose);
    });

    test('a successful move relocates the item in the grid without refetching',
        () async {
      final grid = await container.read(inventoryGridProvider.future);
      final vault = grid.owners.firstWhere((o) => o.isVault);
      final character = grid.owners.firstWhere((o) => !o.isVault);

      await container.read(moveControllerProvider.notifier).move(
            ItemDrag(item: _vaultRifle(), fromOwnerId: vault.id),
            character,
          );

      // The grid now shows the rifle on the character, gone from the vault —
      // and this came from the in-memory patch, not a second fetch (the fixed
      // notifier's build() has no refetch path).
      final patched = container.read(inventoryGridProvider).value!;
      final patchedVault = patched.owners.firstWhere((o) => o.isVault);
      final patchedChar = patched.owners.firstWhere((o) => !o.isVault);
      expect(patchedVault.itemsFor(_kinetic.hash), isEmpty);
      expect(patchedChar.itemsFor(_kinetic.hash).map((i) => i.itemInstanceId),
          ['inst-1']);
    });

    test('a successful move marks the item as recently moved (for the flash)',
        () async {
      final grid = await container.read(inventoryGridProvider.future);
      final vault = grid.owners.firstWhere((o) => o.isVault);
      final character = grid.owners.firstWhere((o) => !o.isVault);

      expect(container.read(recentlyMovedProvider), isNull);
      await container.read(moveControllerProvider.notifier).move(
            ItemDrag(item: _vaultRifle(), fromOwnerId: vault.id),
            character,
          );

      // The moved instance is flagged so its tile flashes the green border.
      expect(container.read(recentlyMovedProvider), 'inst-1');
    });

    test('a stranded-in-vault failure patches the item into the vault',
        () async {
      // Vault-sourced move that reports stranded: the item should end in the
      // vault (its true location), and the outcome is a failure.
      when(() => transfer.moveItem(any(), any(), any())).thenThrow(
        const StrandedInVaultFailure('Stranded in vault.'),
      );

      final grid = await container.read(inventoryGridProvider.future);
      final vault = grid.owners.firstWhere((o) => o.isVault);
      final character = grid.owners.firstWhere((o) => !o.isVault);

      // Start the rifle on the character so the stranded patch (→ vault) is
      // observable.
      final onChar = ItemDrag(
        item: const DestinyItem(
          itemHash: 555,
          bucketHash: 1498876634,
          name: 'Vault Rifle',
          iconPath: '',
          itemInstanceId: 'inst-1',
        ),
        fromOwnerId: character.id,
      );
      // Move the rifle onto the character first (direct patch) so it lives there.
      container.read(inventoryGridProvider.notifier).patch(
            grid.withItemMoved(
                instanceId: 'inst-1',
                fromOwnerId: vault.id,
                toOwnerId: character.id),
          );

      await container.read(moveControllerProvider.notifier).move(
            onChar,
            InventoryOwner(
              id: 'charB',
              title: 'Warlock',
              isVault: false,
              itemsByBucket: const {},
              character: grid.owners.first.character,
            ),
          );

      // moveItem threw stranded → the item is patched to the vault.
      final patched = container.read(inventoryGridProvider).value!;
      final patchedVault = patched.owners.firstWhere((o) => o.isVault);
      expect(patchedVault.itemsFor(_kinetic.hash).map((i) => i.itemInstanceId),
          contains('inst-1'));
      expect(container.read(moveControllerProvider)!.ok, isFalse);
    });

    test('a successful equip patches the grid in place (no refetch)', () async {
      final c = ProviderContainer(overrides: [
        inventoryGridProvider
            .overrideWith(() => _FixedGridNotifier(_gridWithEquippable())),
        itemTransferRepositoryProvider.overrideWithValue(transfer),
      ]);
      addTearDown(c.dispose);

      final grid = await c.read(inventoryGridProvider.future);
      final character = grid.owners.firstWhere((o) => !o.isVault);
      const spare = DestinyItem(
        itemHash: 556,
        bucketHash: 1498876634,
        name: 'Spare Rifle',
        iconPath: '',
        itemInstanceId: 'spare-1',
        classType: 1,
      );

      await c.read(moveControllerProvider.notifier).equip(
            ItemDrag(item: spare, fromOwnerId: character.id),
            character,
          );

      // The spare is now the equipped item; the old one is unequipped — from
      // the in-memory patch, since the fixed notifier has no refetch path.
      final bucket = c
          .read(inventoryGridProvider)
          .value!
          .owners
          .firstWhere((o) => !o.isVault)
          .itemsFor(_kinetic.hash);
      expect(bucket.firstWhere((i) => i.isEquipped).itemInstanceId, 'spare-1');
      expect(bucket.where((i) => i.isEquipped).length, 1);
      expect(c.read(moveControllerProvider)!.ok, isTrue);
    });

    test('equipping a vault item onto a character moves it there then equips',
        () async {
      // _grid(): vault holds the rifle (inst-1); charA is empty. Dropping it on
      // charA's equip slot must move it in AND equip it.
      final grid = await container.read(inventoryGridProvider.future);
      final vault = grid.owners.firstWhere((o) => o.isVault);
      final character = grid.owners.firstWhere((o) => !o.isVault);

      await container.read(moveControllerProvider.notifier).equip(
            ItemDrag(item: _vaultRifle(), fromOwnerId: vault.id),
            character,
          );

      // Both the transfer and the equip were dispatched.
      verify(() => transfer.moveItem(any(), any(), any())).called(1);
      verify(() => transfer.equip(any(), any())).called(1);

      // The grid shows the rifle equipped on the character, gone from the vault.
      final patched = container.read(inventoryGridProvider).value!;
      final charBucket = patched.owners
          .firstWhere((o) => !o.isVault)
          .itemsFor(_kinetic.hash);
      expect(charBucket.single.itemInstanceId, 'inst-1');
      expect(charBucket.single.isEquipped, isTrue);
      expect(
          patched.owners.firstWhere((o) => o.isVault).itemsFor(_kinetic.hash),
          isEmpty);
      expect(container.read(moveControllerProvider)!.ok, isTrue);
    });

    test('a cross-character equip whose equip step fails keeps the move', () async {
      // Move succeeds, equip throws: the item stays on the character
      // (unequipped) and the outcome is a failure that says so.
      when(() => transfer.equip(any(), any()))
          .thenThrow(const ApiFailure('Cannot equip right now.'));

      final grid = await container.read(inventoryGridProvider.future);
      final vault = grid.owners.firstWhere((o) => o.isVault);
      final character = grid.owners.firstWhere((o) => !o.isVault);

      await container.read(moveControllerProvider.notifier).equip(
            ItemDrag(item: _vaultRifle(), fromOwnerId: vault.id),
            character,
          );

      final patched = container.read(inventoryGridProvider).value!;
      final charBucket = patched.owners
          .firstWhere((o) => !o.isVault)
          .itemsFor(_kinetic.hash);
      // The move happened (item on the character) but it is NOT equipped.
      expect(charBucket.single.itemInstanceId, 'inst-1');
      expect(charBucket.single.isEquipped, isFalse);
      final outcome = container.read(moveControllerProvider)!;
      expect(outcome.ok, isFalse);
      expect(outcome.message, contains('could not'));
    });
  });
}
