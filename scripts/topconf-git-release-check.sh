#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/topconf-release-common.sh"

usage() {
  cat <<'EOF'
Usage: scripts/topconf-git-release-check.sh --version <semver>

Verifies clean tree, dev/main branches, remote state, divergence, version docs,
and conflicting tag/release state. Does not mutate Git state.
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
report="$(topconf_report_dir "$root")/git-release-report.txt"
topconf_print_header "Git release check $VERSION"
{
  topconf_assert_clean_tree
  git -C "$root" rev-parse --verify dev >/dev/null
  git -C "$root" rev-parse --verify main >/dev/null
  git -C "$root" rev-parse --verify origin/dev >/dev/null
  git -C "$root" rev-parse --verify origin/main >/dev/null
  printf 'Current branch: %s\n' "$(topconf_current_branch)"
  printf 'dev divergence: %s\n' "$(git -C "$root" rev-list --left-right --count dev...origin/dev)"
  printf 'main divergence: %s\n' "$(git -C "$root" rev-list --left-right --count main...origin/main)"
  [[ "$(git -C "$root" rev-list --left-right --count dev...origin/dev)" == "0	0" ]] || { printf 'ERROR: dev diverges from origin/dev.\n' >&2; exit 1; }
  [[ "$(git -C "$root" rev-list --left-right --count main...origin/main)" == "0	0" ]] || { printf 'ERROR: main diverges from origin/main.\n' >&2; exit 1; }
  topconf_verify_version_metadata "$VERSION" "1"
  topconf_verify_release_docs "$VERSION"
  if git -C "$root" rev-parse --verify "v$VERSION" >/dev/null 2>&1; then
    tag_target="$(git -C "$root" rev-list -n 1 "v$VERSION")"
    main_target="$(git -C "$root" rev-parse main)"
    if [[ "$tag_target" != "$main_target" ]]; then
      printf 'ERROR: tag v%s exists but does not point to main.\n' "$VERSION" >&2
      exit 1
    fi
    printf 'Existing tag v%s points to main: %s\n' "$VERSION" "$tag_target"
  fi
  if command -v gh >/dev/null 2>&1 && gh release view "v$VERSION" >/dev/null 2>&1; then
    printf 'Existing GitHub Release v%s is present; publish stage must not overwrite it without explicit permission.\n' "$VERSION"
  fi
  printf 'Git release check passed.\n'
} | tee "$report"
