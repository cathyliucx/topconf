#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/topconf-release-common.sh"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/topconf-release-pipeline.sh validate
  ./scripts/topconf-release-pipeline.sh prepare --version <semver> --build-number <integer>
  ./scripts/topconf-release-pipeline.sh build --configuration Debug|Release [--clean]
  ./scripts/topconf-release-pipeline.sh package --version <semver>
  ./scripts/topconf-release-pipeline.sh release-check --version <semver>
  ./scripts/topconf-release-pipeline.sh merge --version <semver> --confirm-merge
  ./scripts/topconf-release-pipeline.sh tag --version <semver> --confirm-tag
  ./scripts/topconf-release-pipeline.sh publish --version <semver> --confirm-publish
  ./scripts/topconf-release-pipeline.sh verify-public --version <semver>
  ./scripts/topconf-release-pipeline.sh full-release --version <semver> --build-number <integer> --confirm-merge --confirm-tag --confirm-publish
EOF
}

[[ "${1:-}" != "--help" && $# -gt 0 ]] || { usage; exit 0; }
COMMAND="$1"
shift

run_all_validations() {
  local stage
  for stage in domain parser timezone catalog persistence reconciliation reminders viewmodels ui launcher assets integration release; do
    "$SCRIPT_DIR/topconf-validate-stage.sh" --stage "$stage"
  done
}

case "$COMMAND" in
  validate)
    "$SCRIPT_DIR/topconf-doctor.sh"
    run_all_validations
    ;;
  prepare)
    "$SCRIPT_DIR/topconf-prepare-version.sh" "$@"
    version=""
    while [[ $# -gt 0 ]]; do
      case "$1" in --version) version="$2"; shift 2 ;; *) shift ;; esac
    done
    "$SCRIPT_DIR/topconf-prepare-docs.sh" --version "$version"
    ;;
  build)
    "$SCRIPT_DIR/topconf-build.sh" "$@"
    ;;
  package)
    "$SCRIPT_DIR/topconf-package-dmg.sh" "$@"
    "$SCRIPT_DIR/topconf-verify-artifact.sh" "$@"
    ;;
  release-check)
    "$SCRIPT_DIR/topconf-git-release-check.sh" "$@"
    ;;
  merge)
    "$SCRIPT_DIR/topconf-merge-release.sh" "$@"
    ;;
  tag)
    "$SCRIPT_DIR/topconf-create-tag.sh" "$@"
    ;;
  publish)
    "$SCRIPT_DIR/topconf-publish-release.sh" "$@"
    ;;
  verify-public)
    "$SCRIPT_DIR/topconf-verify-public-release.sh" "$@"
    ;;
  full-release)
    version=""
    build_number=""
    merge_flag=()
    tag_flag=()
    publish_flag=()
    args=("$@")
    i=0
    while [[ $i -lt ${#args[@]} ]]; do
      case "${args[$i]}" in
        --version) version="${args[$((i + 1))]}"; i=$((i + 2)) ;;
        --build-number) build_number="${args[$((i + 1))]}"; i=$((i + 2)) ;;
        --confirm-merge) merge_flag=(--confirm-merge); i=$((i + 1)) ;;
        --confirm-tag) tag_flag=(--confirm-tag); i=$((i + 1)) ;;
        --confirm-publish) publish_flag=(--confirm-publish); i=$((i + 1)) ;;
        *) printf 'ERROR: unknown full-release argument: %s\n' "${args[$i]}" >&2; exit 2 ;;
      esac
    done
    [[ -n "$version" && -n "$build_number" ]] || { printf 'ERROR: --version and --build-number are required.\n' >&2; exit 2; }
    [[ ${#merge_flag[@]} -eq 1 && ${#tag_flag[@]} -eq 1 && ${#publish_flag[@]} -eq 1 ]] || { printf 'ERROR: merge, tag, and publish confirmations are required.\n' >&2; exit 2; }
    "$SCRIPT_DIR/topconf-doctor.sh" --mode publication
    run_all_validations
    "$SCRIPT_DIR/topconf-prepare-version.sh" --version "$version" --build-number "$build_number"
    "$SCRIPT_DIR/topconf-prepare-docs.sh" --version "$version"
    "$SCRIPT_DIR/topconf-git-release-check.sh" --version "$version"
    "$SCRIPT_DIR/topconf-build.sh" --configuration Release --clean
    "$SCRIPT_DIR/topconf-package-dmg.sh" --version "$version"
    "$SCRIPT_DIR/topconf-verify-artifact.sh" --version "$version"
    "$SCRIPT_DIR/topconf-merge-release.sh" "${merge_flag[@]}"
    "$SCRIPT_DIR/topconf-git-release-check.sh" --version "$version"
    "$SCRIPT_DIR/topconf-create-tag.sh" --version "$version" "${tag_flag[@]}"
    "$SCRIPT_DIR/topconf-publish-release.sh" --version "$version" "${publish_flag[@]}"
    "$SCRIPT_DIR/topconf-verify-public-release.sh" --version "$version"
    mkdir -p "$(topconf_report_dir)"
    printf 'TopConf %s full release completed at %s\n' "$version" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >"$(topconf_report_dir)/final-release-report.txt"
    ;;
  *) printf 'ERROR: unknown command: %s\n' "$COMMAND" >&2; usage >&2; exit 2 ;;
esac
