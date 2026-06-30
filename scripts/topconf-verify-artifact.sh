#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/topconf-release-common.sh"

usage() {
  cat <<'EOF'
Usage: scripts/topconf-verify-artifact.sh --version <semver> [--output-dir <path>]

Verifies local DMG, SHA sidecar, mounted contents, copied app signature, and version metadata.
EOF
}

[[ "${1:-}" != "--help" ]] || { usage; exit 0; }
VERSION=""
OUTPUT_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="${2:?missing version}"; shift 2 ;;
    --output-dir) OUTPUT_DIR="${2:?missing output dir}"; shift 2 ;;
    *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'ERROR: version must be semver.\n' >&2; exit 2; }

root="$(topconf_repo_root)"
OUTPUT_DIR="${OUTPUT_DIR:-"$root/dist"}"
DMG="$(topconf_dmg_path "$VERSION" "$OUTPUT_DIR")"
SHA="$(topconf_sha_path "$VERSION" "$OUTPUT_DIR")"
MOUNT="/Volumes/TopConf $VERSION"
report="$(topconf_report_dir "$root")/package-report.txt"

cleanup() {
  if mount | grep -Fq "$MOUNT"; then
    hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

topconf_print_header "Verify artifact $VERSION"
{
  [[ -f "$DMG" ]] || { printf 'ERROR: DMG missing: %s\n' "$DMG" >&2; exit 1; }
  [[ -f "$SHA" ]] || { printf 'ERROR: SHA sidecar missing: %s\n' "$SHA" >&2; exit 1; }
  (cd "$OUTPUT_DIR" && shasum -a 256 -c "$(basename "$SHA")")
  hdiutil verify "$DMG"
  hdiutil attach "$DMG" -nobrowse -readonly
  [[ -d "$MOUNT/TopConf.app" ]] || { printf 'ERROR: mounted app missing.\n' >&2; exit 1; }
  [[ -L "$MOUNT/Applications" ]] || { printf 'ERROR: Applications symlink missing.\n' >&2; exit 1; }
  [[ "$(topconf_info_value "$MOUNT/TopConf.app" CFBundleShortVersionString)" == "$VERSION" ]] || { printf 'ERROR: mounted app version mismatch.\n' >&2; exit 1; }
  codesign --verify --deep --strict --verbose=2 "$MOUNT/TopConf.app"
  hdiutil detach "$MOUNT"
  printf 'Artifact verification passed.\n'
} 2>&1 | tee "$report"
