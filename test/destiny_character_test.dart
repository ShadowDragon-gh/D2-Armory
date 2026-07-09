import 'package:flutter_test/flutter_test.dart';

import 'package:destiny2_loadout_planner/domain/models/destiny_character.dart';

void main() {
  Map<String, dynamic> characterJson({
    int classType = 1,
    int light = 1810,
    String emblem = '/common/destiny2_content/icons/abc.jpg',
    String lastPlayed = '2026-07-01T12:00:00Z',
  }) =>
      {
        'characterId': 2305843009000000001,
        'classType': classType,
        'light': light,
        'emblemPath': '/common/destiny2_content/icons/small.jpg',
        'emblemBackgroundPath': emblem,
        'dateLastPlayed': lastPlayed,
      };

  test('maps classType to a class name', () {
    expect(DestinyCharacter.fromJson(characterJson(classType: 0)).className,
        'Titan');
    expect(DestinyCharacter.fromJson(characterJson(classType: 1)).className,
        'Hunter');
    expect(DestinyCharacter.fromJson(characterJson(classType: 2)).className,
        'Warlock');
    expect(DestinyCharacter.fromJson(characterJson(classType: 3)).className,
        'Guardian');
  });

  test('prefixes emblem paths with the Bungie CDN host', () {
    final c = DestinyCharacter.fromJson(characterJson());
    expect(c.emblemBackgroundUrl,
        'https://www.bungie.net/common/destiny2_content/icons/abc.jpg');
    expect(c.emblemIconUrl,
        'https://www.bungie.net/common/destiny2_content/icons/small.jpg');
  });

  test('emblem URL is null when the path is empty', () {
    final c = DestinyCharacter.fromJson(characterJson(emblem: ''));
    expect(c.emblemBackgroundUrl, isNull);
  });

  test('characterId larger than 2^31 survives as a string (no int overflow)',
      () {
    final c = DestinyCharacter.fromJson(characterJson());
    expect(c.characterId, '2305843009000000001');
  });

  test('parses dateLastPlayed for sorting', () {
    final c = DestinyCharacter.fromJson(
        characterJson(lastPlayed: '2026-07-01T12:00:00Z'));
    expect(c.dateLastPlayed, DateTime.utc(2026, 7, 1, 12));
  });
}
