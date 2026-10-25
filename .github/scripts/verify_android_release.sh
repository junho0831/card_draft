#!/usr/bin/env bash
set -euo pipefail

aab_path="${1:?Usage: verify_android_release.sh path/to/release.aab}"
[[ -s "$aab_path" ]] || { echo "Missing AAB: $aab_path" >&2; exit 1; }

jarsigner -verify "$aab_path" >/dev/null

actual_sha1="$({
  keytool -exportcert \
    -keystore "$ANDROID_KEYSTORE_PATH" \
    -alias "$ANDROID_KEY_ALIAS" \
    -storepass "$ANDROID_KEYSTORE_PASSWORD" \
    -rfc
} | openssl x509 -noout -fingerprint -sha1 | cut -d= -f2)"

bundle_sha1="$({
  unzip -p "$aab_path" 'META-INF/*.RSA' 2>/dev/null || \
  unzip -p "$aab_path" 'META-INF/*.EC' 2>/dev/null
} | keytool -printcert | awk -F': ' '/SHA1:/{print $2; exit}')"

[[ -n "$bundle_sha1" && "$bundle_sha1" == "$actual_sha1" ]] || {
  echo "AAB signer does not match the configured upload key" >&2
  exit 1
}

entries="$(unzip -Z1 "$aab_path")"
grep -q '^base/lib/arm64-v8a/' <<<"$entries" || { echo "Missing arm64-v8a" >&2; exit 1; }
grep -q '^base/lib/armeabi-v7a/' <<<"$entries" || { echo "Missing armeabi-v7a" >&2; exit 1; }

grep -q 'targetSdk[[:space:]]*:[[:space:]]*36' android/build/config.gradle || {
  echo "Generated Android build does not target API 36" >&2
  exit 1
}
grep -q "version/code=${EXPECTED_VERSION_CODE}" export_presets.cfg || {
  echo "Export preset version code mismatch" >&2
  exit 1
}
grep -q "version/name=\"${EXPECTED_VERSION_NAME}\"" export_presets.cfg || {
  echo "Export preset version name mismatch" >&2
  exit 1
}

echo "PASS signed Android release: API 36, ARM64 + ARMv7, upload key ${actual_sha1}"
