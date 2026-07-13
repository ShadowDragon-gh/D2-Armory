import 'package:flutter_test/flutter_test.dart';

import 'package:d2_armory/domain/models/app_version.dart';

void main() {
  group('AppVersion.tryParse', () {
    test('parses plain and v-prefixed versions', () {
      expect(AppVersion.tryParse('1.2.3'), const AppVersion(1, 2, 3));
      expect(AppVersion.tryParse('v1.2.3'), const AppVersion(1, 2, 3));
    });

    test('strips a pubspec +build suffix', () {
      expect(AppVersion.tryParse('1.0.0+7'), const AppVersion(1, 0, 0));
    });

    test('defaults missing minor/patch to zero', () {
      expect(AppVersion.tryParse('2'), const AppVersion(2, 0, 0));
      expect(AppVersion.tryParse('2.5'), const AppVersion(2, 5, 0));
    });

    test('returns null when there is no leading number', () {
      expect(AppVersion.tryParse('latest'), isNull);
      expect(AppVersion.tryParse(''), isNull);
    });
  });

  group('AppVersion comparison', () {
    test('orders by major, then minor, then patch', () {
      expect(const AppVersion(1, 0, 0) > const AppVersion(0, 9, 9), isTrue);
      expect(const AppVersion(1, 2, 0) > const AppVersion(1, 1, 9), isTrue);
      expect(const AppVersion(1, 1, 2) > const AppVersion(1, 1, 1), isTrue);
    });

    test('equal versions are not greater than each other', () {
      expect(const AppVersion(1, 1, 1) > const AppVersion(1, 1, 1), isFalse);
      expect(const AppVersion(1, 1, 1), const AppVersion(1, 1, 1));
    });

    test('an older version is not greater than a newer one', () {
      expect(const AppVersion(1, 0, 0) > const AppVersion(1, 0, 1), isFalse);
    });
  });
}
