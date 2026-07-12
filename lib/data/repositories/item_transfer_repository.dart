import '../../core/errors/failures.dart';
import '../../domain/models/destiny_item.dart';
import '../../domain/models/inventory_grid.dart';
import '../remote/bungie_api.dart';
import 'membership_service.dart';

/// Orchestrates item moves against the Bungie action endpoints, resolving the
/// hop sequence a transfer requires. The vault has no character id, so a move
/// between two characters is two transfers (source → vault → destination); the
/// service sequences these and fails visibly if the second hop cannot complete
/// (the item is then stranded in the vault, never reported as a success).
///
/// Pure orchestration: it owns no grid state. Callers refresh the grid after a
/// successful move.
class ItemTransferRepository {
  ItemTransferRepository({
    required this._api,
    required this._memberships,
  });

  final BungieApi _api;
  final MembershipService _memberships;

  /// Move [item] from [fromOwner] to [toOwner]. [item] must be instanced
  /// (guarded by the caller / validation). Throws a [Failure] if any hop fails;
  /// on a failed second hop of a cross-character move the message states that
  /// the item is now in the vault.
  ///
  /// The three routes:
  /// - character → vault: one transfer (`transferToVault: true`).
  /// - vault → character: one transfer (`transferToVault: false`).
  /// - character A → character B: A → vault, then vault → B.
  Future<void> moveItem(
    DestinyItem item,
    InventoryOwner fromOwner,
    InventoryOwner toOwner,
  ) async {
    final itemId = item.itemInstanceId;
    if (itemId == null) {
      throw const ApiFailure('Only instanced items can be moved.');
    }
    if (fromOwner.id == toOwner.id) return; // no-op

    final membershipType = await _resolveMembershipType();

    // vault → character: pull to the destination character.
    if (fromOwner.isVault) {
      await _api.transferItem(
        itemReferenceHash: item.itemHash,
        itemId: itemId,
        transferToVault: false,
        characterId: _characterIdOf(toOwner),
        membershipType: membershipType,
      );
      return;
    }

    // character → vault: push from the source character.
    if (toOwner.isVault) {
      await _api.transferItem(
        itemReferenceHash: item.itemHash,
        itemId: itemId,
        transferToVault: true,
        characterId: _characterIdOf(fromOwner),
        membershipType: membershipType,
      );
      return;
    }

    // character A → character B: two hops via the vault.
    await _api.transferItem(
      itemReferenceHash: item.itemHash,
      itemId: itemId,
      transferToVault: true,
      characterId: _characterIdOf(fromOwner),
      membershipType: membershipType,
    );
    try {
      await _api.transferItem(
        itemReferenceHash: item.itemHash,
        itemId: itemId,
        transferToVault: false,
        characterId: _characterIdOf(toOwner),
        membershipType: membershipType,
      );
    } on Failure catch (e) {
      // Hop 1 succeeded, hop 2 did not: the item is in the vault, not on the
      // destination. Never report this as a completed move.
      throw ApiFailure(
        'Moved "${item.name}" to the vault, but could not reach '
        '${toOwner.title}. It is in your vault.',
        cause: e,
      );
    }
  }

  /// Equip [item], which must already be on [owner] (a character). Throws a
  /// [Failure] if the equip is rejected (e.g. the item is not on that
  /// character, or the character is in an activity that blocks equipping).
  Future<void> equip(DestinyItem item, InventoryOwner owner) async {
    final itemId = item.itemInstanceId;
    if (itemId == null) {
      throw const ApiFailure('Only instanced items can be equipped.');
    }
    final membershipType = await _resolveMembershipType();
    await _api.equipItem(
      itemId: itemId,
      characterId: _characterIdOf(owner),
      membershipType: membershipType,
    );
  }

  Future<int> _resolveMembershipType() async {
    final membership = await _memberships.resolvePrimary();
    return membership.membershipType;
  }

  /// The character id for a character owner (its [InventoryOwner.id]). The
  /// vault has no character id, so reaching here for the vault is a routing
  /// error rather than a valid transfer target.
  String _characterIdOf(InventoryOwner owner) {
    if (owner.isVault) {
      throw const ApiFailure('The vault has no character id.');
    }
    return owner.id;
  }
}
