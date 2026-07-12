import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:destiny2_loadout_planner/core/destiny/destiny_buckets.dart';
import 'package:destiny2_loadout_planner/core/errors/failures.dart';
import 'package:destiny2_loadout_planner/data/repositories/item_transfer_repository.dart';
import 'package:destiny2_loadout_planner/domain/models/destiny_character.dart';
import 'package:destiny2_loadout_planner/domain/models/destiny_item.dart';
import 'package:destiny2_loadout_planner/domain/models/inventory_grid.dart';
import 'package:destiny2_loadout_planner/presentation/providers/inventory_provider.dart';
import 'package:destiny2_loadout_planner/presentation/screens/inventory/inventory_screen.dart';

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

InventoryGrid _grid() {
  final character = InventoryOwner(
    id: 'charA',
    title: 'Hunter',
    isVault: false,
    character: DestinyCharacter(
      characterId: 'charA',
      classType: 1,
      light: 1900,
      emblemPath: '',
      emblemBackgroundPath: '',
      dateLastPlayed: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    ),
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

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeOwner());
    registerFallbackValue(_vaultRifle());
  });

  late _MockTransfer transfer;

  setUp(() {
    transfer = _MockTransfer();
    when(() => transfer.moveItem(any(), any(), any())).thenAnswer((_) async {});
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
  });
}
