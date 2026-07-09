import '../../core/errors/failures.dart';
import '../../domain/models/destiny_character.dart';
import '../../domain/models/destiny_membership.dart';
import '../remote/bungie_api.dart';

/// Resolves the signed-in user's Destiny characters.
class CharacterRepository {
  CharacterRepository(this._api);

  final BungieApi _api;

  /// Fetch the user's characters for their primary Destiny membership,
  /// ordered most-recently-played first.
  Future<List<DestinyCharacter>> fetchCharacters() async {
    final membership = await _resolvePrimaryMembership();
    final profile = await _api.getProfile(
      membershipType: membership.membershipType,
      membershipId: membership.membershipId,
      components: const [200], // Characters
    );

    // characters -> DictionaryComponentResponse: { data: { <id>: {...} } }
    final charactersComponent = profile['characters'] as Map<String, dynamic>?;
    final data = charactersComponent?['data'] as Map<String, dynamic>?;
    if (data == null) {
      // Requested but absent: surface rather than showing an empty list as if
      // the account genuinely has no characters.
      throw const ApiFailure(
          'Profile response contained no character data (check privacy '
          'settings on the Bungie account).');
    }

    final characters = data.values
        .map((c) => DestinyCharacter.fromJson(c as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.dateLastPlayed.compareTo(a.dateLastPlayed));
    return characters;
  }

  /// Choose the Destiny membership to query, honoring cross-save: when a
  /// primary membership id is present, use it; otherwise the sole membership.
  Future<DestinyMembership> _resolvePrimaryMembership() async {
    final data = await _api.getMembershipsForCurrentUser();
    final memberships = (data['destinyMemberships'] as List<dynamic>? ?? [])
        .map((m) => DestinyMembership.fromJson(m as Map<String, dynamic>))
        .toList();

    if (memberships.isEmpty) {
      throw const ApiFailure(
          'No Destiny memberships found for this Bungie account.');
    }

    final primaryId = data['primaryMembershipId']?.toString();
    if (primaryId != null) {
      for (final m in memberships) {
        if (m.membershipId == primaryId) return m;
      }
    }
    return memberships.first;
  }
}
