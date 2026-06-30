#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/topconf-release-common.sh"

usage() {
  cat <<'EOF'
Usage: scripts/topconf-create-tag.sh --version <semver> --confirm-tag

Creates and pushes annotated tag v<version> on final main. Does not overwrite tags.
EOF
}

[[ "${1:-}" != "--help" ]] || { usage; exit 0; }
VERSION=""
CONFIRM=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="${2:?missing version}"; shift 2 ;;
    --confirm-tag) CONFIRM=1; shift ;;
    *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'ERROR: version must be semver.\n' >&2; exit 2; }
[[ "$CONFIRM" -eq 1 ]] || { printf 'ERROR: --confirm-tag is required.\n' >&2; exit 2; }

root="$(topconf_repo_root)"
report="$(topconf_report_dir "$root")/tag-report.txt"
topconf_print_header "Create tag v$VERSION"
{
  topconf_assert_clean_tree
  [[ "$(topconf_current_branch)" == "main" ]] || { printf 'ERROR: must tag from main.\n' >&2; exit 1; }
  if git -C "$root" rev-parse --verify "v$VERSION" >/dev/null 2>&1; then
    printf 'ERROR: tag v%s already exists.\n' "$VERSION" >&2
    exit 1
  fi
  git -C "$root" tag -a "v$VERSION" -m "TopConf $VERSION"
  [[ "$(git -C "$root" rev-list -n 1 "v$VERSION")" == "$(git -C "$root" rev-parse main)" ]] || { printf 'ERROR: tag does not point to main.\n' >&2; exit 1; }
  git -C "$root" push origin "v$VERSION"
  printf 'Tag v%s created and pushed.\n' "$VERSION"
} | tee "$report"
