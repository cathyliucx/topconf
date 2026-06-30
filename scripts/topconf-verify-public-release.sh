#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/topconf-release-common.sh"

usage() {
  cat <<'EOF'
Usage: scripts/topconf-verify-public-release.sh --version <semver>

Downloads public GitHub Release assets to a temp directory and verifies SHA,
DMG structure, mounted app signature, and version metadata.
EOF
}

[[ "${1:-}" != "--help" ]] || { usage; exit 0; }
VERSION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="${2:?missing version}"; shift 2 ;;
    *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'ERROR: version must be semver.\n' >&2; exit 2; }

root="$(topconf_repo_root)"
tmp="$(mktemp -d)"
MOUNT="/Volumes/TopConf $VERSION"
report="$(topconf_report_dir "$root")/public-verification-report.txt"
cleanup() {
  if mount | grep -Fq "$MOUNT"; then
    hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT

topconf_print_header "Verify public release v$VERSION"
{
  topconf_require_command gh
  gh release view "v$VERSION" --json tagName,name,isDraft,isPrerelease,assets,url
  gh release download "v$VERSION" --dir "$tmp" --pattern "TopConf-$VERSION.dmg"
  gh release download "v$VERSION" --dir "$tmp" --pattern "TopConf-$VERSION.dmg.sha256"
  (cd "$tmp" && shasum -a 256 -c "TopConf-$VERSION.dmg.sha256")
  hdiutil verify "$tmp/TopConf-$VERSION.dmg"
  hdiutil attach "$tmp/TopConf-$VERSION.dmg" -nobrowse -readonly
  [[ -d "$MOUNT/TopConf.app" ]] || { printf 'ERROR: mounted app missing.\n' >&2; exit 1; }
  [[ -L "$MOUNT/Applications" ]] || { printf 'ERROR: Applications symlink missing.\n' >&2; exit 1; }
  [[ "$(topconf_info_value "$MOUNT/TopConf.app" CFBundleShortVersionString)" == "$VERSION" ]] || { printf 'ERROR: public app version mismatch.\n' >&2; exit 1; }
  codesign --verify --deep --strict --verbose=2 "$MOUNT/TopConf.app"
  hdiutil detach "$MOUNT"
  printf 'Public release verification passed.\n'
} 2>&1 | tee "$report"
