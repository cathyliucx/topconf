#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE="$ROOT/.codex/skills/topconf-release-pipeline/SKILL.md"
TARGET="$ROOT/.codex/skills/topconf-release-pipeline/SKILL.md"

if [[ "${1:-}" == "--help" ]]; then
  cat <<'EOF'
Usage: scripts/install-codex-skill.sh [--confirm-overwrite]

Ensures the project-level TopConf release pipeline skill exists under:
  .codex/skills/topconf-release-pipeline/SKILL.md

This intentionally does not install to ~/.codex/skills.
EOF
  exit 0
fi

CONFIRM=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --confirm-overwrite) CONFIRM=1; shift ;;
    *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

printf '\n== TopConf project skill install check ==\n'
mkdir -p "$(dirname "$TARGET")"
if [[ -f "$TARGET" && "$SOURCE" != "$TARGET" && "$CONFIRM" -ne 1 ]]; then
  printf 'ERROR: refusing to overwrite a different existing project skill without --confirm-overwrite.\n' >&2
  exit 1
fi
[[ -f "$SOURCE" ]] || { printf 'ERROR: project skill source missing: %s\n' "$SOURCE" >&2; exit 1; }
printf 'Project-level skill present: %s\n' "$TARGET"
printf 'Global install intentionally not performed.\n'
