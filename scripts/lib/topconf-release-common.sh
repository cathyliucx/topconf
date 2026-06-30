#!/usr/bin/env bash
set -euo pipefail

topconf_repo_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "${script_dir}/../.." && pwd
}

topconf_print_header() {
  printf '\n== TopConf %s ==\n' "$1"
}

topconf_usage_common() {
  cat <<'EOF'
Common environment:
  TOPCONF_DERIVED_DATA  Override DerivedData path. Default: .build/DerivedData
  TOPCONF_REPORT_DIR    Override report path. Default: .build/reports
EOF
}

topconf_report_dir() {
  local root="${1:-$(topconf_repo_root)}"
  printf '%s\n' "${TOPCONF_REPORT_DIR:-"${root}/.build/reports"}"
}

topconf_derived_data() {
  local root="${1:-$(topconf_repo_root)}"
  printf '%s\n' "${TOPCONF_DERIVED_DATA:-"${root}/.build/DerivedData"}"
}

topconf_write_report() {
  local report="$1"
  shift
  mkdir -p "$(dirname "$report")"
  {
    printf 'Generated: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'Repository: %s\n\n' "$(topconf_repo_root)"
    "$@"
  } >"$report"
  printf 'Report: %s\n' "$report"
}

topconf_require_command() {
  local command="$1"
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'ERROR: required command not found: %s\n' "$command" >&2
    return 1
  fi
}

topconf_current_branch() {
  git -C "$(topconf_repo_root)" branch --show-current
}

topconf_assert_clean_tree() {
  local root
  root="$(topconf_repo_root)"
  if [[ -n "$(git -C "$root" status --short)" ]]; then
    printf 'ERROR: working tree is not clean.\n' >&2
    git -C "$root" status --short >&2
    return 1
  fi
}

topconf_assert_project() {
  local root
  root="$(topconf_repo_root)"
  [[ -d "$root/TopConf.xcodeproj" ]] || { printf 'ERROR: TopConf.xcodeproj missing.\n' >&2; return 1; }
  [[ -d "$root/TopConf" ]] || { printf 'ERROR: TopConf source directory missing.\n' >&2; return 1; }
  [[ -d "$root/TopConfTests" ]] || { printf 'ERROR: TopConfTests missing.\n' >&2; return 1; }
  [[ -d "$root/TopConfUITests" ]] || { printf 'ERROR: TopConfUITests missing.\n' >&2; return 1; }
}

topconf_info_value() {
  local app="$1"
  local key="$2"
  plutil -extract "$key" raw "$app/Contents/Info.plist"
}

topconf_release_app_path() {
  local root
  root="$(topconf_repo_root)"
  printf '%s\n' "$root/.build/DerivedData/Build/Products/Release/TopConf.app"
}

topconf_dmg_path() {
  local version="$1"
  local output_dir="${2:-$(topconf_repo_root)/dist}"
  printf '%s/TopConf-%s.dmg\n' "$output_dir" "$version"
}

topconf_sha_path() {
  local version="$1"
  local output_dir="${2:-$(topconf_repo_root)/dist}"
  printf '%s/TopConf-%s.dmg.sha256\n' "$output_dir" "$version"
}

topconf_verify_version_metadata() {
  local version="$1"
  local build_number="$2"
  local root app actual_version actual_build minimum bundle_id
  root="$(topconf_repo_root)"
  app="$(topconf_release_app_path)"
  if [[ -d "$app" ]]; then
    actual_version="$(topconf_info_value "$app" CFBundleShortVersionString)"
    actual_build="$(topconf_info_value "$app" CFBundleVersion)"
    minimum="$(topconf_info_value "$app" LSMinimumSystemVersion)"
    bundle_id="$(topconf_info_value "$app" CFBundleIdentifier)"
  else
    actual_version="$(grep -E 'MARKETING_VERSION = ' "$root/TopConf.xcodeproj/project.pbxproj" | head -1 | sed -E 's/.*= ([^;]+);/\1/')"
    actual_build="$(grep -E 'CURRENT_PROJECT_VERSION = ' "$root/TopConf.xcodeproj/project.pbxproj" | head -1 | sed -E 's/.*= ([^;]+);/\1/')"
    minimum="$(grep -E 'MACOSX_DEPLOYMENT_TARGET = ' "$root/TopConf.xcodeproj/project.pbxproj" | head -1 | sed -E 's/.*= ([^;]+);/\1/')"
    bundle_id="$(grep -E 'PRODUCT_BUNDLE_IDENTIFIER = ' "$root/TopConf.xcodeproj/project.pbxproj" | head -1 | sed -E 's/.*= ([^;]+);/\1/')"
  fi
  [[ "$actual_version" == "$version" ]] || { printf 'ERROR: version is %s, expected %s.\n' "$actual_version" "$version" >&2; return 1; }
  [[ "$actual_build" == "$build_number" ]] || { printf 'ERROR: build number is %s, expected %s.\n' "$actual_build" "$build_number" >&2; return 1; }
  [[ "$minimum" == "14.0" || "$minimum" == "14" ]] || { printf 'ERROR: minimum macOS is %s, expected 14.0.\n' "$minimum" >&2; return 1; }
  [[ "$bundle_id" == "com.example.TopConf" ]] || { printf 'ERROR: bundle identifier is %s.\n' "$bundle_id" >&2; return 1; }
}

topconf_verify_release_docs() {
  local version="$1"
  local root
  root="$(topconf_repo_root)"
  [[ -f "$root/README.md" ]] || { printf 'ERROR: README.md missing.\n' >&2; return 1; }
  [[ -f "$root/RELEASE_NOTES.md" ]] || { printf 'ERROR: RELEASE_NOTES.md missing.\n' >&2; return 1; }
  grep -Fq "TopConf-${version}.dmg" "$root/README.md" || { printf 'ERROR: README missing DMG reference for %s.\n' "$version" >&2; return 1; }
  grep -Fq "TopConf ${version}" "$root/RELEASE_NOTES.md" || { printf 'ERROR: release notes missing title for %s.\n' "$version" >&2; return 1; }
  grep -Eiq 'not notarized|notarization' "$root/README.md" || { printf 'ERROR: README missing notarization disclosure.\n' >&2; return 1; }
  grep -Eiq 'not notarized|notarization' "$root/RELEASE_NOTES.md" || { printf 'ERROR: release notes missing notarization disclosure.\n' >&2; return 1; }
}

topconf_gh_release_exists() {
  local tag="$1"
  gh release view "$tag" >/dev/null 2>&1
}
