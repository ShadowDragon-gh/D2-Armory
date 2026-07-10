import 'package:flutter_test/flutter_test.dart';

import 'package:destiny2_loadout_planner/core/destiny/plug_category.dart';

void main() {
  group('classifyPlug', () {
    test('intrinsic frame', () {
      expect(classifyPlug('intrinsics'), PlugCategory.frame);
    });

    test('weapon traits (barrels/magazines/frames) are perks', () {
      expect(classifyPlug('barrels'), PlugCategory.perk);
      expect(classifyPlug('magazines'), PlugCategory.perk);
      expect(classifyPlug('frames'), PlugCategory.perk);
      expect(classifyPlug('origins'), PlugCategory.perk);
    });

    test('functional weapon mods are mods, not perks', () {
      // Backup Mag and similar: "v400.weapon.mod_magazine".
      expect(classifyPlug('v400.weapon.mod_magazine'), PlugCategory.mod);
      expect(classifyPlug('v400.weapon.mod_damage'), PlugCategory.mod);
    });

    test('cosmetic flair / kill VFX / mementos are cosmetic', () {
      expect(classifyPlug('weapon_tiering_kill_vfx'), PlugCategory.cosmetic);
      expect(classifyPlug('shader'), PlugCategory.cosmetic);
      expect(classifyPlug('armor_skins_hunter_class'), PlugCategory.cosmetic);
      expect(classifyPlug('mementos'), PlugCategory.cosmetic);
    });

    test('masterwork', () {
      expect(classifyPlug('v400.plugs.weapons.masterworks.range'),
          PlugCategory.masterwork);
    });

    test('crafting-era catalyst refits group with masterwork', () {
      expect(classifyPlug('catalysts'), PlugCategory.masterwork);
      expect(classifyPlug('v400.empty.exotic.masterwork'),
          PlugCategory.masterwork);
    });

    test('empty / unknown', () {
      expect(classifyPlug(null), PlugCategory.other);
      expect(classifyPlug(''), PlugCategory.other);
    });
  });
}
