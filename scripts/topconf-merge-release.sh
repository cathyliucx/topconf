#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/topconf-release-common.sh"

usage() {
  cat <<'EOF'
Usage: scripts/topconf-merge-release.sh --confirm-merge

Fetches, verifies dev/main, checks out main, pulls ff-only, merges dev with a
normal merge commit, and pushes main. Never force-pushes.
EOF
}

[[ "${1:-}" != "--help" ]] || { usage; exit 0; }
CONFIRM=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --confirm-merge) CONFIRM=1; shift ;;
    *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done
[[ "$CONFIRM" -eq 1 ]] || { printf 'ERROR: --confirm-merge is required.\n' >&2; exit 2; }

root="$(topconf_repo_root)"
topconf_print_header "Merge release"
topconf_assert_clean_tree
git -C "$root" fetch origin
[[ "$(git -C "$root" rev-list --left-right --count dev...origin/dev)" == "0	0" ]] || { printf 'ERROR: dev diverges from origin/dev.\n' >&2; exit 1; }
[[ "$(git -C "$root" rev-list --left-right --count main...origin/main)" == "0	0" ]] || { printf 'ERROR: main diverges from origin/main.\n' >&2; exit 1; }
git -C "$root" checkout main
git -C "$root" pull --ff-only origin main
git -C "$root" merge --no-ff dev -m "release: merge TopConf release"
git -C "$root" push origin main
printf 'Merge release completed.\n'
