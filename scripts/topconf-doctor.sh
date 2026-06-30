#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/topconf-release-common.sh
source "$SCRIPT_DIR/lib/topconf-release-common.sh"

MODE="local"
if [[ "${1:-}" == "--help" ]]; then
  cat <<'EOF'
Usage: scripts/topconf-doctor.sh [--mode local|publication]

Checks macOS, Xcode, Git, project layout, repository state, Homebrew, GitHub CLI,
GitHub authentication, build paths, and signing status. Local mode warns when
GitHub CLI is missing. Publication mode fails when GitHub CLI or auth is missing.
EOF
  topconf_usage_common
  exit 0
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="${2:?missing mode}"; shift 2 ;;
    *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

root="$(topconf_repo_root)"
report="$(topconf_report_dir "$root")/environment-report.txt"

topconf_print_header "Doctor"
mkdir -p "$(dirname "$report")"
{
  printf 'Generated: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf 'Repository: %s\n' "$root"
  printf 'Mode: %s\n\n' "$MODE"

  [[ "$(uname -s)" == "Darwin" ]] || { printf 'ERROR: macOS is required.\n'; exit 1; }
  printf 'macOS: %s\n' "$(sw_vers -productVersion)"

  topconf_require_command git
  topconf_require_command xcodebuild
  topconf_require_command xcode-select
  topconf_require_command plutil
  topconf_require_command codesign
  topconf_require_command hdiutil
  topconf_assert_project

  printf 'Xcode path: %s\n' "$(xcode-select -p)"
  xcodebuild -version
  printf 'Git: %s\n' "$(git --version)"
  printf 'Branch: %s\n' "$(topconf_current_branch)"
  git -C "$root" status --short
  git -C "$root" remote -v

  if command -v brew >/dev/null 2>&1; then
    printf 'Homebrew: %s\n' "$(command -v brew)"
  elif [[ -x /opt/homebrew/bin/brew ]]; then
    printf 'Homebrew: /opt/homebrew/bin/brew\n'
  elif [[ -x /usr/local/bin/brew ]]; then
    printf 'Homebrew: /usr/local/bin/brew\n'
  else
    printf 'WARNING: Homebrew not found.\n'
  fi

  if command -v gh >/dev/null 2>&1; then
    printf 'GitHub CLI: %s\n' "$(command -v gh)"
    if gh auth status >/dev/null 2>&1; then
      printf 'GitHub auth: ok\n'
    else
      printf '%s: GitHub CLI is not authenticated.\n' "$([[ "$MODE" == "publication" ]] && printf ERROR || printf WARNING)"
      [[ "$MODE" != "publication" ]] || exit 1
    fi
  else
    printf '%s: GitHub CLI not found.\n' "$([[ "$MODE" == "publication" ]] && printf ERROR || printf WARNING)"
    [[ "$MODE" != "publication" ]] || exit 1
  fi

  printf 'DerivedData: %s\n' "$(topconf_derived_data "$root")"
  app="$(topconf_release_app_path)"
  if [[ -d "$app" ]]; then
    codesign -dv --verbose=2 "$app" 2>&1 || true
  else
    printf 'Release app: not built at %s\n' "$app"
  fi
} | tee "$report"

printf 'Doctor completed.\n'
