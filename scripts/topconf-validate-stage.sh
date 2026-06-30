#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/topconf-release-common.sh"

usage() {
  cat <<'EOF'
Usage: scripts/topconf-validate-stage.sh --stage <stage>

Stages:
  domain parser timezone catalog persistence reconciliation reminders
  viewmodels ui launcher assets integration release
EOF
}

[[ "${1:-}" != "--help" ]] || { usage; exit 0; }
STAGE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stage) STAGE="${2:?missing stage}"; shift 2 ;;
    *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done
[[ -n "$STAGE" ]] || { usage >&2; exit 2; }

root="$(topconf_repo_root)"
report="$(topconf_report_dir "$root")/stage-validation-report.txt"
topconf_print_header "Validate stage: $STAGE"
mkdir -p "$(dirname "$report")"

check_rg() {
  local pattern="$1"
  local label="$2"
  shift 2
  local paths=()
  local path
  for path in "$@"; do
    paths+=("$root/$path")
  done
  rg -n "$pattern" "${paths[@]}" >/dev/null || { printf 'ERROR: missing %s\n' "$label" >&2; return 1; }
}

{
  printf 'Generated: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf 'Repository: %s\nStage: %s\n\n' "$root" "$STAGE"
  topconf_assert_project
  case "$STAGE" in
    domain)
      check_rg 'struct SystemClock|protocol Clock' 'clock abstraction' TopConf/Domain
      check_rg 'maximumConferenceCount|trackingLimit|maxTrackedConferences' 'tracking policy' TopConf/Domain
      check_rg 'DeadlineSelectionService|TrackedConferenceResolver|ConferenceSortingService' 'deadline and sorting services' TopConf/Domain
      ;;
    parser)
      check_rg 'loaded as\\? \\[\\[String: Any\\]\\]|malformedRoot|unsupportedTimeZone' 'array-root parser and strict timezone errors' TopConf/Data/Remote
      check_rg 'array root|UnsupportedKDD|KDD|unsupported rank|missing rank' 'parser regression tests' TopConfTests/Data/Remote
      ;;
    timezone)
      check_rg 'AoE|UTC-12|PT|unsupportedTimeZone|TimeZone[(]identifier:' 'timezone parser' TopConf/Data/Remote
      check_rg 'AoE|UTC\\+|Not/AZone|PT|America/Los_Angeles' 'timezone tests' TopConfTests/Data/Remote
      ;;
    catalog)
      check_rg 'AI|CG|HI|MX|conference/AI|conference/CG|conference/HI|conference/MX' 'supported directories' TopConf/Data TopConfTests/Data
      check_rg 'unsupportedFiles|incompleteBatch|noUsableConferences' 'catalog diagnostics' TopConf/Data
      ;;
    persistence)
      check_rg 'SwiftData.*Repository|ModelContainer|TrackedConferenceEntity|ReminderEntity' 'SwiftData repositories' TopConf/Data/Local
      check_rg 'SwiftData.*RepositoryTests|PersistenceRecreation' 'persistence tests' TopConfTests/Data/SwiftData
      ;;
    reconciliation)
      check_rg 'reconcile|orphan|remove|cancel' 'orphan reconciliation' TopConf/App TopConf/Data TopConf/Features
      check_rg 'graphics-acm-mm|hci-chi|orphan|accepted refresh|cache|seed' 'reconciliation regressions' TopConfTests
      ;;
    reminders)
      check_rg 'NotificationScheduling|DeadlineNotificationService|deadlinePrefix|authorization' 'notification abstractions' TopConf/Notifications TopConf/Domain
      check_rg 'Mock|SilentNotificationScheduler|DeadlineNotificationServiceTests|NotificationIdentifierTests' 'notification tests' TopConfTests TopConf/Notifications
      ;;
    viewmodels)
      check_rg 'TrackedConferenceListViewModel|ConferenceManagementViewModel|ReminderViewModel' 'view models' TopConf/Features
      check_rg 'TrackedConferenceListViewModelTests|ConferenceManagementViewModelTests|ReminderViewModelTests' 'view model tests' TopConfTests/Features
      ;;
    ui)
      check_rg 'accessibilityIdentifier|ConferenceFilterBar|OnboardingView|ConferenceManagementView' 'UI identifiers and views' TopConf/Features TopConf/App
      check_rg 'Unranked|CCF-A|CCF-B|CCF-C|ConferenceManagementUITests' 'UI regression tests' TopConfUITests TopConfTests
      ;;
    launcher)
      check_rg 'NSStatusItem|NSPanel|GlobalHotkey|LSUIElement|MenuBarStatusItem' 'launcher implementation' TopConf TopConf.xcodeproj
      check_rg 'button.title|isTemplate|accessibilityLabel|Show TopConf|Quit TopConf' 'launcher tests' TopConfTests/App
      ;;
    assets)
      [[ -f "$root/TopConf/Assets.xcassets/AppIcon.appiconset/Contents.json" ]] || exit 1
      [[ -f "$root/TopConf/Assets.xcassets/MenuBarCalendar.imageset/Contents.json" ]] || exit 1
      check_rg 'template-rendering-intent|template' 'template menu-bar asset' TopConf/Assets.xcassets/MenuBarCalendar.imageset
      ;;
    integration)
      check_rg 'AppCompositionTests|FixtureDrivenDomainTests' 'integration tests' TopConfTests
      check_rg 'DependencyContainer|AppRootView|TopConfAppDelegate' 'composition root' TopConf/App
      ;;
    release)
      topconf_verify_release_docs "1.0.0"
      topconf_verify_version_metadata "1.0.0" "1"
      [[ -f "$root/dist/TopConf-1.0.0.dmg" ]] || { printf 'ERROR: release DMG missing.\n' >&2; exit 1; }
      [[ -f "$root/dist/TopConf-1.0.0.dmg.sha256" ]] || { printf 'ERROR: release SHA missing.\n' >&2; exit 1; }
      ;;
    *) printf 'ERROR: unknown stage: %s\n' "$STAGE" >&2; exit 2 ;;
  esac
  printf 'Stage %s passed.\n' "$STAGE"
} | tee -a "$report"
