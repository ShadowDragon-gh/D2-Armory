import '../../core/config/app_config.dart';

/// A player character, from the Characters (200) profile component.
///
/// Class/race/gender come back as small int enums (classType etc.) in addition
/// to hashes; the enums are used directly here so no manifest lookup is needed
/// to show them.
class DestinyCharacter {
  const DestinyCharacter({
    required this.characterId,
    required this.classType,
    required this.light,
    required this.emblemPath,
    required this.emblemBackgroundPath,
    required this.dateLastPlayed,
  });

  final String characterId;
  final int classType;
  final int light;

  /// Bungie-relative icon paths; prefix with the CDN host to load.
  final String emblemPath;
  final String emblemBackgroundPath;

  final DateTime dateLastPlayed;

  factory DestinyCharacter.fromJson(Map<String, dynamic> json) =>
      DestinyCharacter(
        characterId: json['characterId'].toString(),
        classType: (json['classType'] as num?)?.toInt() ?? 3,
        light: (json['light'] as num?)?.toInt() ?? 0,
        emblemPath: (json['emblemPath'] as String?) ?? '',
        emblemBackgroundPath: (json['emblemBackgroundPath'] as String?) ?? '',
        dateLastPlayed:
            DateTime.tryParse(json['dateLastPlayed'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

  /// DestinyClass enum: 0=Titan, 1=Hunter, 2=Warlock, 3=Unknown.
  String get className => switch (classType) {
        0 => 'Titan',
        1 => 'Hunter',
        2 => 'Warlock',
        _ => 'Guardian',
      };

  /// Full URL for the emblem background (the wide banner image), or null when
  /// the path is empty.
  String? get emblemBackgroundUrl => emblemBackgroundPath.isEmpty
      ? null
      : '${AppConfig.bungieBaseUrl}$emblemBackgroundPath';

  String? get emblemIconUrl =>
      emblemPath.isEmpty ? null : '${AppConfig.bungieBaseUrl}$emblemPath';
}
