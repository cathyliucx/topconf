#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/topconf-release-common.sh"

usage() {
  cat <<'EOF'
Usage: scripts/topconf-prepare-version.sh --version <semver> --build-number <integer>

Validates release version metadata. This script does not commit automatically.
EOF
}

[[ "${1:-}" != "--help" ]] || { usage; exit 0; }
VERSION=""
BUILD_NUMBER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="${2:?missing version}"; shift 2 ;;
    --build-number) BUILD_NUMBER="${2:?missing build number}"; shift 2 ;;
    *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'ERROR: version must be semver.\n' >&2; exit 2; }
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || { printf 'ERROR: build number must be an integer.\n' >&2; exit 2; }

root="$(topconf_repo_root)"
report="$(topconf_report_dir "$root")/version-report.txt"
topconf_print_header "Prepare version $VERSION ($BUILD_NUMBER)"
{
  topconf_verify_version_metadata "$VERSION" "$BUILD_NUMBER"
  stale_refs="$(
    {
      rg -n '[0-9]+\.[0-9]+\.[0-9]+|TopConf-[0-9]+\.[0-9]+\.[0-9]+\.dmg|v[0-9]+\.[0-9]+\.[0-9]+' "$root/README.md" "$root/RELEASE_NOTES.md" || true
      grep -n 'MARKETING_VERSION = ' "$root/TopConf.xcodeproj/project.pbxproj" || true
    } | grep -v "$VERSION" || true
  )"
  if [[ -n "$stale_refs" ]]; then
    printf 'ERROR: stale version references found:\n%s\n' "$stale_refs" >&2
    exit 1
  fi
  rg -n "$VERSION|TopConf-$VERSION.dmg|v$VERSION" "$root/README.md" "$root/RELEASE_NOTES.md" || true
  grep -n 'MARKETING_VERSION = ' "$root/TopConf.xcodeproj/project.pbxproj" || true
  printf 'Version references inspected above.\n'
  printf 'Version metadata passed.\n'
} | tee "$report"
