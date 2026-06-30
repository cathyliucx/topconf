#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/topconf-release-common.sh"

usage() {
  cat <<'EOF'
Usage: scripts/topconf-publish-release.sh --version <semver> --confirm-publish [--replace-assets]

Publishes GitHub Release v<version> with DMG and SHA sidecar. Requires gh auth.
EOF
}

[[ "${1:-}" != "--help" ]] || { usage; exit 0; }
VERSION=""
CONFIRM=0
REPLACE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="${2:?missing version}"; shift 2 ;;
    --confirm-publish) CONFIRM=1; shift ;;
    --replace-assets) REPLACE=1; shift ;;
    *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'ERROR: version must be semver.\n' >&2; exit 2; }
[[ "$CONFIRM" -eq 1 ]] || { printf 'ERROR: --confirm-publish is required.\n' >&2; exit 2; }

root="$(topconf_repo_root)"
DMG="$(topconf_dmg_path "$VERSION" "$root/dist")"
SHA="$(topconf_sha_path "$VERSION" "$root/dist")"
report="$(topconf_report_dir "$root")/publication-report.txt"
topconf_print_header "Publish release v$VERSION"
{
  topconf_require_command gh
  gh auth status >/dev/null
  [[ -f "$DMG" && -f "$SHA" ]] || { printf 'ERROR: release artifacts missing.\n' >&2; exit 1; }
  git -C "$root" rev-parse --verify "v$VERSION" >/dev/null
  if gh release view "v$VERSION" >/dev/null 2>&1; then
    [[ "$REPLACE" -eq 1 ]] || { printf 'ERROR: release v%s already exists. Use --replace-assets only with explicit permission.\n' "$VERSION" >&2; exit 1; }
    gh release upload "v$VERSION" "$DMG" "$SHA" --clobber
  else
    gh release create "v$VERSION" "$DMG" "$SHA" \
      --title "TopConf $VERSION" \
      --notes-file "$root/RELEASE_NOTES.md" \
      --verify-tag
  fi
  gh release view "v$VERSION" --json tagName,name,isDraft,isPrerelease,assets,url
} | tee "$report"
