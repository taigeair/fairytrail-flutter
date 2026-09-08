/// Keep in sync with pubspec.yaml (via ./update_version.sh).
abstract final class AppVersionInfo {
  static const version = '26.1.7';
  static const build = '260107';

  /// RN `isAcceptableBuild` — compares numeric build against remote config
  /// `acceptableBuild`. Missing/invalid config = allow.
  static bool isAcceptableBuild(String? acceptableBuildString) {
    if (acceptableBuildString == null || acceptableBuildString.isEmpty) {
      return true;
    }
    final acceptable = int.tryParse(acceptableBuildString);
    final current = int.tryParse(build);
    if (acceptable == null || current == null) return true;
    return current >= acceptable;
  }
}
