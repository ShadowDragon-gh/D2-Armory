import '../../core/errors/failures.dart';
import '../../domain/models/destiny_character.dart';
import '../remote/bungie_api.dart';
import 'membership_service.dart';

/// Resolves the signed-in user's Destiny characters.
class CharacterRepository {
  CharacterRepository(this._api) : _memberships = MembershipService(_api);

  final BungieApi _api;
  final MembershipService _memberships;

  /// Fetch the user's characters for their primary Destiny membership,
  /// ordered most-recently-played first.
  Future<List<DestinyCharacter>> fetchCharacters() async {
    final membership = await _memberships.resolvePrimary();
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
}
