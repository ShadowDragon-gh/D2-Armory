import 'package:flutter_test/flutter_test.dart';

import 'package:destiny2_loadout_planner/domain/models/item_detail.dart';

ItemStat _stat(String name, StatDisplay display) =>
    ItemStat(name: name, value: 50, display: display);

void main() {
  test('sortStatsForDisplay groups bar, then recoil, then numeric — stable '
      'within each group', () {
    // Interleaved input in manifest order.
    final input = [
      _stat('Impact', StatDisplay.bar),
      _stat('RPM', StatDisplay.numeric),
      _stat('Recoil Direction', StatDisplay.recoil),
      _stat('Range', StatDisplay.bar),
      _stat('Magazine', StatDisplay.numeric),
      _stat('Stability', StatDisplay.bar),
    ];

    final sorted = sortStatsForDisplay(input).map((s) => s.name).toList();

    expect(sorted, [
      // Bars first, in original order.
      'Impact', 'Range', 'Stability',
      // Then the recoil gauge.
      'Recoil Direction',
      // Then numerics, in original order.
      'RPM', 'Magazine',
    ]);
  });

  test('sortStatsForDisplay preserves an already-ordered list', () {
    final input = [
      _stat('Impact', StatDisplay.bar),
      _stat('Recoil Direction', StatDisplay.recoil),
      _stat('Magazine', StatDisplay.numeric),
    ];
    expect(sortStatsForDisplay(input).map((s) => s.name),
        ['Impact', 'Recoil Direction', 'Magazine']);
  });
}
