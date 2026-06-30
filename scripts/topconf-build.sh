#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/topconf-release-common.sh"

usage() {
  cat <<'EOF'
Usage: scripts/topconf-build.sh [--configuration Debug|Release] [--clean] [--open]

Builds the TopConf shared scheme into .build/DerivedData.
EOF
}

[[ "${1:-}" != "--help" ]] || { usage; exit 0; }
CONFIGURATION="Debug"
CLEAN=0
OPEN_APP=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --configuration) CONFIGURATION="${2:?missing configuration}"; shift 2 ;;
    --clean) CLEAN=1; shift ;;
    --open) OPEN_APP=1; shift ;;
    *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done
[[ "$CONFIGURATION" == "Debug" || "$CONFIGURATION" == "Release" ]] || { printf 'ERROR: invalid configuration.\n' >&2; exit 2; }

root="$(topconf_repo_root)"
derived="$(topconf_derived_data "$root")"
report="$(topconf_report_dir "$root")/build-report.txt"
topconf_print_header "Build $CONFIGURATION"
[[ "$CLEAN" -eq 0 ]] || rm -rf "$derived"
mkdir -p "$(dirname "$report")"
{
  printf 'Configuration: %s\nDerivedData: %s\n\n' "$CONFIGURATION" "$derived"
  xcodebuild build \
    -project "$root/TopConf.xcodeproj" \
    -scheme TopConf \
    -configuration "$CONFIGURATION" \
    -destination 'platform=macOS' \
    -derivedDataPath "$derived"
} 2>&1 | tee "$report"

if [[ "$OPEN_APP" -eq 1 ]]; then
  app="$derived/Build/Products/$CONFIGURATION/TopConf.app"
  [[ -d "$app" ]] || { printf 'ERROR: built app missing: %s\n' "$app" >&2; exit 1; }
  open -g "$app"
fi
