import '../../core/errors/failures.dart';
import '../../domain/models/destiny_membership.dart';
import '../remote/bungie_api.dart';

/// Resolves which Destiny platform membership to query for the signed-in user,
/// honoring cross-save. Shared by the repositories that call GetProfile.
class MembershipService {
  MembershipService(this._api);

  final BungieApi _api;

  /// When a primary membership id is present (cross-save active), use it;
  /// otherwise the sole/first membership.
  Future<DestinyMembership> resolvePrimary() async {
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
