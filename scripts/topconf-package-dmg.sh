#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/topconf-release-common.sh"

usage() {
  cat <<'EOF'
Usage: scripts/topconf-package-dmg.sh --version <semver> [--app <path>] [--output-dir <path>]

Creates and verifies TopConf-<version>.dmg and TopConf-<version>.dmg.sha256.
EOF
}

[[ "${1:-}" != "--help" ]] || { usage; exit 0; }
VERSION=""
APP=""
OUTPUT_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="${2:?missing version}"; shift 2 ;;
    --app) APP="${2:?missing app path}"; shift 2 ;;
    --output-dir) OUTPUT_DIR="${2:?missing output dir}"; shift 2 ;;
    *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'ERROR: version must be semver.\n' >&2; exit 2; }

root="$(topconf_repo_root)"
APP="${APP:-$(topconf_release_app_path)}"
OUTPUT_DIR="${OUTPUT_DIR:-"$root/dist"}"
DMG="$(topconf_dmg_path "$VERSION" "$OUTPUT_DIR")"
SHA="$(topconf_sha_path "$VERSION" "$OUTPUT_DIR")"
STAGING="$OUTPUT_DIR/dmg-root"
MOUNT="/Volumes/TopConf $VERSION"
report="$(topconf_report_dir "$root")/package-report.txt"

cleanup() {
  if mount | grep -Fq "$MOUNT"; then
    hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

topconf_print_header "Package DMG $VERSION"
{
  [[ -d "$APP" ]] || { printf 'ERROR: app not found: %s\n' "$APP" >&2; exit 1; }
  [[ "$(topconf_info_value "$APP" CFBundleShortVersionString)" == "$VERSION" ]] || { printf 'ERROR: app version mismatch.\n' >&2; exit 1; }
  codesign --verify --deep --strict --verbose=2 "$APP"
  rm -rf "$STAGING"
  mkdir -p "$STAGING"
  cp -R "$APP" "$STAGING/"
  ln -s /Applications "$STAGING/Applications"
  hdiutil create -volname "TopConf $VERSION" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
  hdiutil verify "$DMG"
  hdiutil attach "$DMG" -nobrowse -readonly
  [[ -d "$MOUNT/TopConf.app" ]] || { printf 'ERROR: mounted app missing.\n' >&2; exit 1; }
  [[ -L "$MOUNT/Applications" ]] || { printf 'ERROR: Applications symlink missing.\n' >&2; exit 1; }
  codesign --verify --deep --strict --verbose=2 "$MOUNT/TopConf.app"
  hdiutil detach "$MOUNT"
  shasum -a 256 "$DMG" >"$SHA"
  printf 'DMG: %s\nSHA: %s\n' "$DMG" "$SHA"
} 2>&1 | tee "$report"
