import 'package:flutter_test/flutter_test.dart';

import 'package:d2_armory/data/repositories/d2ai_repository.dart';

/// Loads the real bundled d2ai snapshot (registered in pubspec assets) and
/// asserts known entries resolve — proving the asset ships and parses, and the
/// string-keyed lookup by int hash works.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late D2aiRepository repo;

  setUp(() => repo = D2aiRepository());

  test('loads the bundled snapshot and resolves a known source hash', () async {
    expect(repo.isReady, isFalse);
    await repo.ensureLoaded();
    expect(repo.isReady, isTrue);

    // A stable, long-standing entry in DIM's sources.json.
    expect(repo.sourceFor(10464158), 'Source: Acquired from Xûr');
    // An unknown source hash yields null (caller keeps the manifest string).
    expect(repo.sourceFor(1), isNull);
  });

  test('resolves a known weapon->quest-step mapping', () async {
    await repo.ensureLoaded();

    // From weapon-from-quest.json: weapon 42351395 -> quest step 3601169173.
    expect(repo.questStepFor(42351395), 3601169173);
    expect(repo.questStepFor(1), isNull);
  });

  test('ensureLoaded is idempotent', () async {
    await repo.ensureLoaded();
    await repo.ensureLoaded();
    expect(repo.isReady, isTrue);
    expect(repo.sourceFor(10464158), isNotNull);
  });

  test('loads the source-overrides asset and resolves a bundled override',
      () async {
    await repo.ensureLoaded();
    // A hand-authored override that ships in source_overrides.json (Bushido
    // Vest → Vanguard Ops). Proves the asset is registered, parses, and the
    // per-item lookup works against real bundled data.
    expect(repo.sourceOverrideFor(1154629600), 'Source: Vanguard Ops');
    // A hash with no override entry resolves to null.
    expect(repo.sourceOverrideFor(10464158), isNull);
  });
}
