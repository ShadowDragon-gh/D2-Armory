import 'package:flutter_test/flutter_test.dart';

import 'package:destiny2_loadout_planner/domain/models/destiny_item.dart';
import 'package:destiny2_loadout_planner/presentation/theme/armory_palette.dart';

DestinyItem _item({required int itemType, required int tierType, int gearTier = 5}) =>
    DestinyItem(
      itemHash: 1,
      bucketHash: 1,
      name: 'x',
      iconPath: '',
      itemType: itemType,
      tierType: tierType,
      gearTier: gearTier,
    );

void main() {
  test('tierDiamond colour: grey for tiers 1-3, purple at 4, gold at 5', () {
    for (final t in [1, 2, 3]) {
      expect(ArmoryPalette.tierDiamond(t), ArmoryPalette.tierDiamondGrey,
          reason: 'tier $t should be grey');
    }
    expect(ArmoryPalette.tierDiamond(4), ArmoryPalette.tierDiamondPurple);
    expect(ArmoryPalette.tierDiamond(5), ArmoryPalette.tierDiamondGold);
    // Above the max still reads as the top (gold) colour.
    expect(ArmoryPalette.tierDiamond(6), ArmoryPalette.tierDiamondGold);
  });

  test('showsGearTier: on for tiered weapons and non-exotic armor, off for '
      'exotic armor and untiered gear', () {
    // itemType 2 = armor, 3 = weapon; tierType 6 = exotic, 5 = legendary.
    expect(_item(itemType: 3, tierType: 6).showsGearTier, isTrue); // exotic wpn
    expect(_item(itemType: 3, tierType: 5).showsGearTier, isTrue); // legend wpn
    expect(_item(itemType: 2, tierType: 5).showsGearTier, isTrue); // legend armor
    expect(_item(itemType: 2, tierType: 6).showsGearTier, isFalse); // EXOTIC ARMOR
    // No tier → never shown, regardless of type.
    expect(_item(itemType: 3, tierType: 6, gearTier: 0).showsGearTier, isFalse);
  });
}
