import 'dart:async';

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

class _MockTransfer extends Mock implements ItemTransferRepository {}

class _FakeOwner extends Fake implements InventoryOwner {}

/// A grid notifier that serves a fixed grid and records refresh() calls, so the
/// insert path's post-write refetch can be observed without a network.
class _FixedGridNotifier extends InventoryGridNotifier {
  _FixedGridNotifier(this._fixed);
  final InventoryGrid _fixed;
  int refreshCount = 0;

  @override
  Future<InventoryGrid> build() async => _fixed;

  @override
  Future<void> refresh() async => refreshCount++;
}

const _kinetic = EquipmentBucket.kineticWeapons;

DestinyItem _charRifle() => const DestinyItem(
      itemHash: 555,
      bucketHash: 1498876634, // kinetic
      name: 'Char Rifle',
      iconPath: '',
      itemInstanceId: 'inst-1',
      classType: 1,
    );

DestinyItem _vaultRifle() => const DestinyItem(
      itemHash: 556,
      bucketHash: 1498876634,
      name: 'Vault Rifle',
      iconPath: '',
      itemInstanceId: 'inst-2',
    );

DestinyCharacter _hunter() => DestinyCharacter(
      characterId: 'charA',
      classType: 1,
      light: 1900,
      emblemPath: '',
      emblemBackgroundPath: '',
      dateLastPlayed: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );

InventoryGrid _grid() => InventoryGrid([
      InventoryOwner(
        id: 'charA',
        title: 'Hunter',
        isVault: false,
        character: _hunter(),
        itemsByBucket: {
          _kinetic.hash: [_charRifle()],
        },
      ),
      InventoryOwner(
        id: 'vault',
        title: 'Vault',
        isVault: true,
        itemsByBucket: {
          _kinetic.hash: [_vaultRifle()],
        },
      ),
    ]);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeOwner());
    registerFallbackValue(_charRifle());
  });

  late _MockTransfer transfer;
  late _FixedGridNotifier gridNotifier;
  late ProviderContainer container;

  setUp(() {
    transfer = _MockTransfer();
    gridNotifier = _FixedGridNotifier(_grid());
    container = ProviderContainer(overrides: [
      inventoryGridProvider.overrideWith(() => gridNotifier),
      itemTransferRepositoryProvider.overrideWithValue(transfer),
    ]);
    addTearDown(container.dispose);
  });

  test('a successful insert dispatches the socket + plug and refetches',
      () async {
    when(() => transfer.insertPlug(any(), any(),
        socketIndex: any(named: 'socketIndex'),
        plugHash: any(named: 'plugHash'))).thenAnswer((_) async {});

    // The grid must be loaded so the owner can be resolved.
    await container.read(inventoryGridProvider.future);
    final revBefore = container.read(gearModalRevisionProvider);

    await container.read(moveControllerProvider.notifier).insertPlug(
          _charRifle(),
          socketIndex: 1,
          plugHash: 9999,
          plugName: 'Rampage',
        );

    final captured = verify(() => transfer.insertPlug(
          captureAny(),
          captureAny(),
          socketIndex: captureAny(named: 'socketIndex'),
          plugHash: captureAny(named: 'plugHash'),
        )).captured;
    expect((captured[0] as DestinyItem).itemInstanceId, 'inst-1');
    expect((captured[1] as InventoryOwner).id, 'charA');
    expect(captured[2], 1); // socketIndex
    expect(captured[3], 9999); // plugHash

    // Reconciled by a refetch.
    expect(gridNotifier.refreshCount, 1);
    // The revision bumped, so the modal's instance-detail re-resolves from the
    // patched cache even if the re-selected item is the same object.
    expect(container.read(gearModalRevisionProvider),
        greaterThan(revBefore));

    // Success outcome, named for the action.
    final outcome = container.read(moveControllerProvider);
    expect(outcome?.ok, isTrue);
    expect(outcome?.title, 'Perk selected');
    expect(outcome?.message, contains('Rampage'));
  });

  test('the optimistic override moves the highlight while the insert is in '
      'flight, and holds after success', () async {
    // A slow insert lets us observe the override before it resolves.
    when(() => transfer.insertPlug(any(), any(),
            socketIndex: any(named: 'socketIndex'),
            plugHash: any(named: 'plugHash')))
        .thenAnswer((_) => Future<void>.delayed(const Duration(seconds: 1)));

    await container.read(inventoryGridProvider.future);
    // Select the instance so the override provider keys to it.
    container.read(gearModalInstanceProvider.notifier).select(_charRifle());
    expect(container.read(gearModalPlugOverrideProvider), isEmpty);

    final future = container.read(moveControllerProvider.notifier).insertPlug(
          _charRifle(),
          socketIndex: 2,
          plugHash: 4242,
          plugName: 'Frenzy',
        );

    // Override is set immediately (before the POST completes).
    expect(container.read(gearModalPlugOverrideProvider)[2], 4242);

    await future;
    // Survives the successful reconcile (same-instance re-select keeps it).
    expect(container.read(gearModalPlugOverrideProvider)[2], 4242);
  });

  test('rapid switches queue: clicks during an in-flight insert are not '
      'dropped — POSTs run serially, the last pick wins', () async {
    // Gate each insert on a completer so we control when it finishes and can
    // interleave clicks deterministically.
    final gates = <Completer<void>>[];
    final dispatched = <int>[]; // plug hashes in POST order
    when(() => transfer.insertPlug(any(), any(),
        socketIndex: any(named: 'socketIndex'),
        plugHash: any(named: 'plugHash'))).thenAnswer((inv) {
      dispatched.add(inv.namedArguments[#plugHash] as int);
      final gate = Completer<void>();
      gates.add(gate);
      return gate.future;
    });

    await container.read(inventoryGridProvider.future);
    container.read(gearModalInstanceProvider.notifier).select(_charRifle());
    final notifier = container.read(moveControllerProvider.notifier);

    // Click A (starts in flight), then B and C while A is still running.
    // (The first call's future intentionally resolves only after the whole
    // drained chain finishes, so it is not awaited before the gates complete.)
    unawaited(notifier.insertPlug(_charRifle(),
        socketIndex: 1, plugHash: 111, plugName: 'A'));
    unawaited(notifier.insertPlug(_charRifle(),
        socketIndex: 1, plugHash: 222, plugName: 'B'));
    unawaited(notifier.insertPlug(_charRifle(),
        socketIndex: 1, plugHash: 333, plugName: 'C'));

    // Only A has been POSTed so far (B and C are queued, C overwrote B). The
    // override already shows the latest pick, C.
    expect(dispatched, [111]);
    expect(container.read(gearModalPlugOverrideProvider)[1], 333);

    // Finish A → the queued pick (C, not B) runs next.
    gates[0].complete();
    await pumpEventQueue();
    expect(dispatched, [111, 333]); // B was collapsed away
    expect(gates.length, 2);

    // Finish C.
    gates[1].complete();
    await pumpEventQueue();
    expect(container.read(gearModalPlugOverrideProvider)[1], 333);
    final outcome = container.read(moveControllerProvider);
    expect(outcome?.ok, isTrue);
    expect(outcome?.message, contains('C'));
  });

  test('a failed insert rolls back the override and surfaces the failure',
      () async {
    when(() => transfer.insertPlug(any(), any(),
            socketIndex: any(named: 'socketIndex'),
            plugHash: any(named: 'plugHash')))
        .thenThrow(const ApiFailure('This action is not currently available.'));

    await container.read(inventoryGridProvider.future);
    container.read(gearModalInstanceProvider.notifier).select(_charRifle());
    final revBefore = container.read(gearModalRevisionProvider);

    await container.read(moveControllerProvider.notifier).insertPlug(
          _charRifle(),
          socketIndex: 3,
          plugHash: 7777,
          plugName: 'Outlaw',
        );

    // Optimistic highlight rolled back.
    expect(container.read(gearModalPlugOverrideProvider).containsKey(3),
        isFalse);
    // No refetch on failure.
    expect(gridNotifier.refreshCount, 0);
    // The revision still advances: the optimistic patch and its rollback each
    // bump it so the detail re-resolves to (and then away from) the pick.
    expect(container.read(gearModalRevisionProvider),
        greaterThan(revBefore));
    final outcome = container.read(moveControllerProvider);
    expect(outcome?.ok, isFalse);
    expect(outcome?.message, 'This action is not currently available.');
  });

  test('an item in the vault is refused (sockets need a character)', () async {
    await container.read(inventoryGridProvider.future);

    await container.read(moveControllerProvider.notifier).insertPlug(
          _vaultRifle(),
          socketIndex: 1,
          plugHash: 1234,
          plugName: 'Backup Mag',
        );

    // Never hit the API; surfaced a clear failure.
    verifyNever(() => transfer.insertPlug(any(), any(),
        socketIndex: any(named: 'socketIndex'),
        plugHash: any(named: 'plugHash')));
    final outcome = container.read(moveControllerProvider);
    expect(outcome?.ok, isFalse);
    expect(outcome?.message, contains('character'));
  });
}
