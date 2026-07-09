import 'package:flutter_test/flutter_test.dart';

import 'package:destiny2_loadout_planner/data/local/manifest_database.dart';

void main() {
  group('ManifestDatabase.signedHash', () {
    test('leaves values within the signed range unchanged', () {
      expect(ManifestDatabase.signedHash(0), 0);
      expect(ManifestDatabase.signedHash(1), 1);
      expect(ManifestDatabase.signedHash(0x7FFFFFFF), 0x7FFFFFFF);
    });

    test('maps values above the signed max into the negative range', () {
      // 0x80000000 (2147483648) -> -2147483648
      expect(ManifestDatabase.signedHash(0x80000000), -2147483648);
      // 0xFFFFFFFF (4294967295) -> -1
      expect(ManifestDatabase.signedHash(0xFFFFFFFF), -1);
    });

    test('a known large item hash converts correctly', () {
      // 3184839370 is > 2^31; signed form is 3184839370 - 2^32.
      expect(ManifestDatabase.signedHash(3184839370), 3184839370 - 4294967296);
    });

    test('normalizes hashes that already exceed 32 bits', () {
      // Some API responses return already-negative or overflowed values; the
      // low 32 bits are what matters.
      expect(ManifestDatabase.signedHash(0x1FFFFFFFF), -1);
    });
  });
}
