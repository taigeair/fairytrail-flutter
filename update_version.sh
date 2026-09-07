#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

END_POINTS="lib/utils/api/end_points.dart"
if [[ ! -f "$END_POINTS" ]]; then
  echo "error: $END_POINTS not found" >&2
  exit 1
fi

IS_PROD="$(
  grep -E 'static const isProd[[:space:]]*=' "$END_POINTS" \
    | head -1 \
    | sed -E 's/.*static const isProd[[:space:]]*=[[:space:]]*([^;[:space:]]+).*/\1/'
)"
if [[ "$IS_PROD" != "true" ]]; then
  if [[ "$IS_PROD" != "false" ]]; then
    echo "error: could not find EndPoints.isProd in $END_POINTS (found: ${IS_PROD:-missing})" >&2
    exit 1
  fi
  echo "==> Setting EndPoints.isProd = true"
  sed -i '' -E 's/(static const isProd[[:space:]]*=[[:space:]]*)false/\1true/' "$END_POINTS"
fi

if [[ ! -f pubspec.yaml ]]; then
  echo "error: pubspec.yaml not found in $SCRIPT_DIR" >&2
  exit 1
fi

VERSION_LINE="$(grep -E '^version:' pubspec.yaml | head -1 | awk '{print $2}')"
VERSION_NAME="${VERSION_LINE%%+*}"
VERSION_CODE="${VERSION_LINE##*+}"

if [[ -z "$VERSION_NAME" || -z "$VERSION_CODE" || "$VERSION_NAME" == "$VERSION_CODE" ]]; then
  echo "error: could not parse version from pubspec.yaml (expected name+code, e.g. 26.0.3+260003)" >&2
  exit 1
fi

echo "Syncing version from pubspec.yaml"
echo "  versionName / CFBundleShortVersionString: $VERSION_NAME"
echo "  versionCode / CFBundleVersion:            $VERSION_CODE"
echo

APP_VERSION_DART="lib/config/app_version.dart"
cat > "$APP_VERSION_DART" <<EOF
/// Keep in sync with pubspec.yaml (via ./update_version.sh).
abstract final class AppVersionInfo {
  static const version = '$VERSION_NAME';
  static const build = '$VERSION_CODE';

  /// RN \`isAcceptableBuild\` — compares numeric build against remote config
  /// \`acceptableBuild\`. Missing/invalid config = allow.
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
EOF
echo "==> Updated $APP_VERSION_DART → $VERSION_NAME ($VERSION_CODE)"
echo

echo "==> iOS: flutter build ios --config-only"
flutter build ios --config-only

echo
echo "==> Android: flutter build apk --config-only"
flutter build apk --config-only

echo
echo "Done. Native projects and app_version.dart now use $VERSION_NAME+$VERSION_CODE."
