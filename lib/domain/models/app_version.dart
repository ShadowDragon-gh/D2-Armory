/// A simple dotted numeric version (`major.minor.patch`) used to compare the
/// running app against the latest GitHub release.
///
/// Release tags may carry a leading `v` (e.g. `v1.2.0`) and a `+build` suffix
/// (as pubspec versions do); both are stripped before parsing. Only the numeric
/// components are compared — this project does not use pre-release tags.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  /// Parse `1.2.3`, `v1.2.3`, or `1.2.3+4`. Missing components default to 0
  /// (`1.2` -> `1.2.0`). Returns null if no leading numeric component is found.
  static AppVersion? tryParse(String raw) {
    final trimmed = raw.trim();
    final withoutPrefix =
        trimmed.startsWith('v') ? trimmed.substring(1) : trimmed;
    final core = withoutPrefix.split('+').first;
    final parts = core.split('.');
    final numbers = <int>[];
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null) break;
      numbers.add(n);
    }
    if (numbers.isEmpty) return null;
    return AppVersion(
      numbers[0],
      numbers.length > 1 ? numbers[1] : 0,
      numbers.length > 2 ? numbers[2] : 0,
    );
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersion &&
      major == other.major &&
      minor == other.minor &&
      patch == other.patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}
