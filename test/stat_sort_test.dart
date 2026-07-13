import 'package:flutter_test/flutter_test.dart';

import 'package:destiny2_loadout_planner/domain/models/item_detail.dart';

// Real weapon stat hashes so the canonical in-game ordering applies.
const _impact = 4043523819;
const _range = 1240592695;
const _stability = 155624089;
const _handling = 943549884;
const _reload = 4188031367;
const _aim = 1345609583;
const _zoom = 3555269338;
const _airborne = 2714457168;
const _ammoGen = 1931675084;
const _recoil = 2715839340;
const _rpm = 4284893193;
const _magazine = 3871231066;
const _blastRadius = 3614673599;
const _velocity = 2523465841;
const _accuracy = 1591432999;
const _shieldDuration = 1842278586;

ItemStat _stat(int hash, String name, StatDisplay display) =>
    ItemStat(statHash: hash, name: name, value: 50, display: display);

void main() {
  test('groups bar → recoil → numeric, and orders bars by the in-game '
      'sequence — Zoom sits third from the bottom of the bars', () {
    // Scrambled input; the sort must impose the canonical in-game order.
    final input = [
      _stat(_ammoGen, 'Ammo Generation', StatDisplay.bar),
      _stat(_rpm, 'Rounds Per Minute', StatDisplay.numeric),
      _stat(_zoom, 'Zoom', StatDisplay.bar),
      _stat(_recoil, 'Recoil Direction', StatDisplay.recoil),
      _stat(_range, 'Range', StatDisplay.bar),
      _stat(_impact, 'Impact', StatDisplay.bar),
      _stat(_airborne, 'Airborne Effectiveness', StatDisplay.bar),
      _stat(_magazine, 'Magazine', StatDisplay.numeric),
      _stat(_handling, 'Handling', StatDisplay.bar),
      _stat(_stability, 'Stability', StatDisplay.bar),
      _stat(_reload, 'Reload Speed', StatDisplay.bar),
      _stat(_aim, 'Aim Assistance', StatDisplay.bar),
    ];

    final sorted = sortStatsForDisplay(input).map((s) => s.name).toList();

    expect(sorted, [
      // Bars in the in-game order: Zoom is third from the bottom, before
      // Airborne Effectiveness and Ammo Generation.
      'Impact', 'Range', 'Stability', 'Handling', 'Reload Speed',
      'Aim Assistance', 'Zoom', 'Airborne Effectiveness', 'Ammo Generation',
      // Then the recoil gauge, then numeric stats.
      'Recoil Direction',
      'Rounds Per Minute', 'Magazine',
    ]);
  });

  test('launcher/glaive/bow order: Blast Radius + Velocity lead, Accuracy '
      'follows Impact, Shield Duration follows Range', () {
    // A grenade-launcher-ish bar set plus glaive/bow stats, scrambled.
    final input = [
      _stat(_range, 'Range', StatDisplay.bar),
      _stat(_velocity, 'Velocity', StatDisplay.bar),
      _stat(_shieldDuration, 'Shield Duration', StatDisplay.bar),
      _stat(_impact, 'Impact', StatDisplay.bar),
      _stat(_blastRadius, 'Blast Radius', StatDisplay.bar),
      _stat(_accuracy, 'Accuracy', StatDisplay.bar),
      _stat(_stability, 'Stability', StatDisplay.bar),
    ];
    expect(sortStatsForDisplay(input).map((s) => s.name), [
      'Blast Radius', 'Velocity', // lead
      'Impact', 'Accuracy', // Accuracy just after Impact
      'Range', 'Shield Duration', // Shield Duration just after Range
      'Stability',
    ]);
  });

  test('unlisted stats sort to the end of their group, keeping input order',
      () {
    final input = [
      _stat(999001, 'Custom B', StatDisplay.bar),
      _stat(_range, 'Range', StatDisplay.bar),
      _stat(999002, 'Custom A', StatDisplay.bar),
    ];
    expect(sortStatsForDisplay(input).map((s) => s.name),
        ['Range', 'Custom B', 'Custom A']);
  });
}
