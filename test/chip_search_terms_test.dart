import 'package:flutter_test/flutter_test.dart';

import 'package:d2_armory/core/destiny/destiny_enums.dart';
import 'package:d2_armory/core/search/item_filter.dart';
import 'package:d2_armory/domain/models/destiny_item.dart';

// A minimal item for grammar matching.
DestinyItem item({
  int itemType = 3,
  int itemSubType = 9,
  int tierType = 5,
  int? damageType,
  int ammoType = 0,
}) =>
    DestinyItem(
      itemHash: 1,
      bucketHash: 1498876634,
      name: 'X',
      iconPath: '',
      itemType: itemType,
      itemSubType: itemSubType,
      tierType: tierType,
      ammoType: ammoType,
      damageType: damageType,
    );

void main() {
  test('chip keyword helpers produce terms the search grammar matches', () {
    // Weapon type: subType 9 → is:handcannon, matches a hand cannon.
    expect(DestinyEnums.weaponTypeKeyword(9), 'handcannon');
    expect(
        compileQuery('is:handcannon').matches(item(itemSubType: 9)), isTrue);
    expect(
        compileQuery('is:handcannon').matches(item(itemSubType: 13)), isFalse);

    // Element: Void (4) → is:void.
    expect(DestinyEnums.damageKeyword(4), 'void');
    expect(compileQuery('is:void').matches(item(damageType: 4)), isTrue);

    // Rarity: Exotic (6) → is:exotic.
    expect(DestinyEnums.rarityKeyword(6), 'exotic');
    expect(compileQuery('is:exotic').matches(item(tierType: 6)), isTrue);
    expect(compileQuery('is:exotic').matches(item(tierType: 5)), isFalse);

    // Ammo: Heavy (3) → ammo:heavy.
    expect(DestinyEnums.ammoKeyword(3), 'heavy');
    expect(compileQuery('ammo:heavy').matches(item(ammoType: 3)), isTrue);

    // Armor slot: Helmet (26) → is:helmet (a valid bucket keyword).
    expect(DestinyEnums.armorSlotKeyword(26), 'helmet');

    // Legendary label colour is the lighter, readable purple (Void tone).
    expect(DestinyEnums.rarityLabelColor(5).toARGB32(), 0xFFB185DF);
  });
}
