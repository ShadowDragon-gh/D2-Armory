import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:d2_armory/core/destiny/destiny_buckets.dart';
import 'package:d2_armory/core/errors/failures.dart';
import 'package:d2_armory/data/remote/bungie_api.dart';
import 'package:d2_armory/data/repositories/item_transfer_repository.dart';
import 'package:d2_armory/data/repositories/membership_service.dart';
import 'package:d2_armory/domain/models/destiny_character.dart';
import 'package:d2_armory/domain/models/destiny_item.dart';
import 'package:d2_armory/domain/models/destiny_membership.dart';
import 'package:d2_armory/domain/models/inventory_grid.dart';

class _MockApi extends Mock implements BungieApi {}

class _MockMemberships extends Mock implements MembershipService {}

/// A character owner whose id doubles as its characterId (as the real grid
/// builds it).
InventoryOwner _character(String id) => InventoryOwner(
      id: id,
      title: id,
      isVault: false,
      character: DestinyCharacter(
        characterId: id,
        classType: 1,
        light: 1900,
        emblemPath: '',
        emblemBackgroundPath: '',
        dateLastPlayed: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
      itemsByBucket: const {},
    );

final _vault = const InventoryOwner(
  id: 'vault',
  title: 'Vault',
  isVault: true,
  itemsByBucket: {},
);

DestinyItem _item({String? instanceId = '9001'}) => DestinyItem(
      itemHash: 555,
      bucketHash: EquipmentBucket.kineticWeapons.hash,
      name: 'Test Rifle',
      iconPath: '',
      itemInstanceId: instanceId,
    );

void main() {
  late _MockApi api;
  late _MockMemberships memberships;
  late ItemTransferRepository repo;

  setUp(() {
    api = _MockApi();
    memberships = _MockMemberships();
    repo = ItemTransferRepository(api: api, memberships: memberships);

    when(() => memberships.resolvePrimary()).thenAnswer((_) async =>
        const DestinyMembership(
            membershipType: 3, membershipId: '42', displayName: 'Guardian'));
    // Default: transfers succeed.
    when(() => api.transferItem(
          itemReferenceHash: any(named: 'itemReferenceHash'),
          itemId: any(named: 'itemId'),
          transferToVault: any(named: 'transferToVault'),
          characterId: any(named: 'characterId'),
          membershipType: any(named: 'membershipType'),
        )).thenAnswer((_) async {});
    when(() => api.equipItem(
          itemId: any(named: 'itemId'),
          characterId: any(named: 'characterId'),
          membershipType: any(named: 'membershipType'),
        )).thenAnswer((_) async {});
  });

  group('moveItem routing', () {
    test('character → vault is a single transferToVault:true from the source',
        () async {
      await repo.moveItem(_item(), _character('charA'), _vault);

      verify(() => api.transferItem(
            itemReferenceHash: 555,
            itemId: '9001',
            transferToVault: true,
            characterId: 'charA',
            membershipType: 3,
          )).called(1);
      verifyNever(() => api.transferItem(
            itemReferenceHash: any(named: 'itemReferenceHash'),
            itemId: any(named: 'itemId'),
            transferToVault: false,
            characterId: any(named: 'characterId'),
            membershipType: any(named: 'membershipType'),
          ));
    });

    test('vault → character is a single transferToVault:false to the dest',
        () async {
      await repo.moveItem(_item(), _vault, _character('charB'));

      verify(() => api.transferItem(
            itemReferenceHash: 555,
            itemId: '9001',
            transferToVault: false,
            characterId: 'charB',
            membershipType: 3,
          )).called(1);
    });

    test('character A → character B is two hops: A→vault then vault→B',
        () async {
      await repo.moveItem(_item(), _character('charA'), _character('charB'));

      // Hop 1: source character → vault.
      verify(() => api.transferItem(
            itemReferenceHash: 555,
            itemId: '9001',
            transferToVault: true,
            characterId: 'charA',
            membershipType: 3,
          )).called(1);
      // Hop 2: vault → destination character.
      verify(() => api.transferItem(
            itemReferenceHash: 555,
            itemId: '9001',
            transferToVault: false,
            characterId: 'charB',
            membershipType: 3,
          )).called(1);
    });

    test('same-owner move is a no-op (no API calls)', () async {
      final a = _character('charA');
      await repo.moveItem(_item(), a, a);
      verifyNever(() => api.transferItem(
            itemReferenceHash: any(named: 'itemReferenceHash'),
            itemId: any(named: 'itemId'),
            transferToVault: any(named: 'transferToVault'),
            characterId: any(named: 'characterId'),
            membershipType: any(named: 'membershipType'),
          ));
    });

    test('uninstanced item is rejected before any API call', () async {
      await expectLater(
        repo.moveItem(_item(instanceId: null), _character('a'), _vault),
        throwsA(isA<ApiFailure>()),
      );
      verifyNever(() => api.transferItem(
            itemReferenceHash: any(named: 'itemReferenceHash'),
            itemId: any(named: 'itemId'),
            transferToVault: any(named: 'transferToVault'),
            characterId: any(named: 'characterId'),
            membershipType: any(named: 'membershipType'),
          ));
    });
  });

  group('cross-character partial failure', () {
    test('hop 2 failure reports the item stranded in the vault, not success',
        () async {
      // Hop 1 (to vault) succeeds; hop 2 (from vault) fails.
      when(() => api.transferItem(
            itemReferenceHash: any(named: 'itemReferenceHash'),
            itemId: any(named: 'itemId'),
            transferToVault: true,
            characterId: any(named: 'characterId'),
            membershipType: any(named: 'membershipType'),
          )).thenAnswer((_) async {});
      when(() => api.transferItem(
            itemReferenceHash: any(named: 'itemReferenceHash'),
            itemId: any(named: 'itemId'),
            transferToVault: false,
            characterId: any(named: 'characterId'),
            membershipType: any(named: 'membershipType'),
          )).thenThrow(const ApiFailure('Destination full.', errorCode: 1642));

      await expectLater(
        repo.moveItem(_item(), _character('charA'), _character('charB')),
        throwsA(isA<StrandedInVaultFailure>()
            .having((f) => f.message, 'message', contains('in your vault'))
            .having((f) => f.cause, 'cause', isA<ApiFailure>())),
      );

      // Hop 1 did happen — the item really is in the vault now.
      verify(() => api.transferItem(
            itemReferenceHash: any(named: 'itemReferenceHash'),
            itemId: any(named: 'itemId'),
            transferToVault: true,
            characterId: 'charA',
            membershipType: 3,
          )).called(1);
    });

    test('hop 1 failure surfaces the underlying error and never attempts hop 2',
        () async {
      when(() => api.transferItem(
            itemReferenceHash: any(named: 'itemReferenceHash'),
            itemId: any(named: 'itemId'),
            transferToVault: true,
            characterId: any(named: 'characterId'),
            membershipType: any(named: 'membershipType'),
          )).thenThrow(const NetworkFailure('No connection.'));

      await expectLater(
        repo.moveItem(_item(), _character('charA'), _character('charB')),
        throwsA(isA<NetworkFailure>()),
      );
      // Hop 2 (from vault) must not run when hop 1 failed.
      verifyNever(() => api.transferItem(
            itemReferenceHash: any(named: 'itemReferenceHash'),
            itemId: any(named: 'itemId'),
            transferToVault: false,
            characterId: any(named: 'characterId'),
            membershipType: any(named: 'membershipType'),
          ));
    });
  });

  group('equip', () {
    test('equips an item on its character', () async {
      await repo.equip(_item(), _character('charA'));
      verify(() => api.equipItem(
            itemId: '9001',
            characterId: 'charA',
            membershipType: 3,
          )).called(1);
    });

    test('uninstanced item cannot be equipped', () async {
      await expectLater(
        repo.equip(_item(instanceId: null), _character('charA')),
        throwsA(isA<ApiFailure>()),
      );
      verifyNever(() => api.equipItem(
            itemId: any(named: 'itemId'),
            characterId: any(named: 'characterId'),
            membershipType: any(named: 'membershipType'),
          ));
    });
  });
}
