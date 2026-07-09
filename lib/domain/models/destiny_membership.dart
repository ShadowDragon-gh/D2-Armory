/// A Destiny platform membership (Steam/Xbox/PSN/etc.) for the signed-in user.
///
/// OAuth yields only a Bungie.net id; the platform membership needed for
/// profile calls comes from GetMembershipsForCurrentUser.
class DestinyMembership {
  const DestinyMembership({
    required this.membershipType,
    required this.membershipId,
    required this.displayName,
  });

  /// Platform code: Xbox=1, PSN=2, Steam=3, Epic=6 (BungieMembershipType).
  final int membershipType;
  final String membershipId;
  final String displayName;

  factory DestinyMembership.fromJson(Map<String, dynamic> json) =>
      DestinyMembership(
        membershipType: (json['membershipType'] as num).toInt(),
        membershipId: json['membershipId'].toString(),
        displayName: (json['displayName'] as String?) ?? '',
      );
}
