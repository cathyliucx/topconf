#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/topconf-release-common.sh"

usage() {
  cat <<'EOF'
Usage: scripts/topconf-prepare-docs.sh --version <semver>

Verifies README release information and RELEASE_NOTES.md. It does not invent
Developer ID, notarization, or signing claims.
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
topconf_print_header "Prepare docs $VERSION"
topconf_verify_release_docs "$VERSION"
printf 'Release documentation passed.\n'
