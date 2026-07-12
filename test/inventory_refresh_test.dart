import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:destiny2_loadout_planner/core/destiny/destiny_buckets.dart';
import 'package:destiny2_loadout_planner/data/repositories/inventory_repository.dart';
import 'package:destiny2_loadout_planner/domain/models/destiny_item.dart';
import 'package:destiny2_loadout_planner/domain/models/inventory_grid.dart';
import 'package:destiny2_loadout_planner/presentation/providers/inventory_provider.dart';

class _MockRepo extends Mock implements InventoryRepository {}

final _kh = EquipmentBucket.kineticWeapons.hash;

InventoryGrid _gridWith(List<String> vaultInstanceIds) => InventoryGrid([
      InventoryOwner(
        id: 'vault',
        title: 'Vault',
        isVault: true,
        itemsByBucket: {
          _kh: [
            for (final id in vaultInstanceIds)
              DestinyItem(
                itemHash: 1,
                bucketHash: _kh,
                name: 'Rifle $id',
                iconPath: '',
                itemInstanceId: id,
              ),
          ],
        },
      ),
    ]);

void main() {
  late _MockRepo repo;
  // The timestamp the repo reports; a fetch updates it, so it reflects the last
  // *completed* fetch — exactly as the real repository behaves.
  late DateTime? minted;

  setUp(() {
    repo = _MockRepo();
    minted = null;
    when(() => repo.lastMintedTimestamp).thenAnswer((_) => minted);
  });

  /// Stub the next [fetchInventory] to return [_gridWith(ids)] and, when it
  /// runs, stamp [mintedAt] as the last-fetched timestamp. Covers both the
  /// no-arg initial build and the `reuseDecoded: true` refresh call.
  void stubFetch(List<String> ids, {DateTime? mintedAt}) {
    Future<InventoryGrid> answer(_) async {
      minted = mintedAt;
      return _gridWith(ids);
    }

    when(() => repo.fetchInventory()).thenAnswer(answer);
    when(() => repo.fetchInventory(reuseDecoded: any(named: 'reuseDecoded')))
        .thenAnswer(answer);
  }

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      inventoryRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('refresh replaces the grid when Bungie mints a newer profile', () async {
    stubFetch(['a'], mintedAt: DateTime.utc(2026, 7, 12, 10, 0, 0));
    final c = container();
    final first = await c.read(inventoryGridProvider.future);
    expect(first.owners.single.itemsFor(_kh).map((i) => i.itemInstanceId),
        ['a']);

    // A newer profile (t1 > t0) with a different item.
    stubFetch(['b'], mintedAt: DateTime.utc(2026, 7, 12, 10, 5, 0));
    await c.read(inventoryGridProvider.notifier).refresh();

    expect(c.read(inventoryGridProvider).value!.owners.single
        .itemsFor(_kh).map((i) => i.itemInstanceId), ['b']);
  });

  test('refresh discards a profile no newer than the one already shown',
      () async {
    stubFetch(['a'], mintedAt: DateTime.utc(2026, 7, 12, 10, 0, 0));
    final c = container();
    await c.read(inventoryGridProvider.future);

    // Bungie's edge cache returns an OLDER profile with different data.
    stubFetch(['stale'], mintedAt: DateTime.utc(2026, 7, 12, 9, 55, 0));
    await c.read(inventoryGridProvider.notifier).refresh();

    // The stale response is discarded — the grid still shows the original item.
    expect(c.read(inventoryGridProvider).value!.owners.single
        .itemsFor(_kh).map((i) => i.itemInstanceId), ['a']);
  });

  test('patch replaces the grid immediately without any fetch', () async {
    stubFetch(['a']);
    final c = container();
    await c.read(inventoryGridProvider.future);
    clearInteractions(repo);

    c.read(inventoryGridProvider.notifier).patch(_gridWith(['a', 'c']));

    expect(c.read(inventoryGridProvider).value!.owners.single
        .itemsFor(_kh).map((i) => i.itemInstanceId), ['a', 'c']);
    verifyNever(() => repo.fetchInventory());
  });
}
