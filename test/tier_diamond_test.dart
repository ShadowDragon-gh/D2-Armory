import 'package:flutter_test/flutter_test.dart';

import 'package:destiny2_loadout_planner/presentation/theme/armory_palette.dart';

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
}
