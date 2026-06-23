# AGENTS.md

## 1. Project

TopConf is a native macOS menu bar application for tracking academic conference deadlines.

The user can select and track up to 10 conferences. Pressing `⌥ Space` opens a Spotlight-style floating window that displays the tracked conferences, sorted by their nearest valid submission deadline.

Conference discovery focuses on these CCF categories:

* Artificial Intelligence
* Computer Graphics and Multimedia
* Human-Computer Interaction and Ubiquitous Computing
* Interdisciplinary, Comprehensive, and Emerging Areas

The default discovery filter is CCF-A, but rank and category filters must not be hard-coded into the tracked-conference list.

Before making architectural or feature-level changes, read:

* `docs/TOPCONF_SOP.md`

If the repository implementation conflicts with these documents, report the conflict before making broad changes.

---

## 2. Technology

Use:

* Swift
* SwiftUI
* AppKit
* SwiftData
* UserNotifications
* URLSession
* XCTest
* macOS 14 or later

YAML parsing may use Yams through Swift Package Manager when the data layer is implemented.

Do not use:

* Electron
* Tauri
* React Native
* WebView
* HTML scraping
* Browser automation for extracting conference data
* Python as an application runtime
* A web frontend embedded inside the macOS application

Development scripts may use Python only when they are not required by the shipped application.

---

## 3. Architecture

Use these top-level layers:

```text
App
Domain
Data
Features
Notifications
Shared
```

The intended dependency direction is:

```text
Features ──────→ Domain
Data ─────────→ Domain
Notifications → Domain abstractions
App ──────────→ composition and concrete dependencies
```

The `Domain` layer must remain independent of UI, persistence, networking, parsing, and operating-system frameworks.

Files in `Domain` must not import:

* SwiftUI
* AppKit
* SwiftData
* UserNotifications
* Yams

Domain code should not directly use URLSession or concrete networking implementations.

External capabilities must be represented through protocols and injected from the application composition root.

---

## 4. Core Product Rules

### 4.1 Tracking limit

* A user may track at most 10 conferences.
* The 10th conference must be accepted.
* The 11th conference must be rejected.
* The limit must be defined in one policy location.
* Do not scatter the literal value `10` across views, view models, repositories, or services.
* The tracking limit must be enforced by a domain service, not by the persistence repository alone.

### 4.2 Tracking identity

* Users track conferences, not individual conference editions.
* A tracked item must reference a stable conference ID.
* Do not use array positions as identifiers.
* Do not use random UUIDs for conference identity when a deterministic source identity is available.
* Adding new editions must not require the user to select the conference again.

### 4.3 Upstream changes

A previously tracked conference must not disappear automatically because:

* its CCF rank changes;
* its category changes;
* its display name changes;
* a new edition is published;
* the next deadline is temporarily TBD;
* the upstream source temporarily omits the conference.

Discovery filters are for finding conferences. They must not delete or invalidate existing tracked-conference records.

### 4.4 Conference categories

The first release supports conference discovery across:

* Artificial Intelligence
* Computer Graphics and Multimedia
* Human-Computer Interaction and Ubiquitous Computing
* Interdisciplinary, Comprehensive, and Emerging Areas

Do not assume upstream category identifiers without inspecting the real structured data.

Preserve the upstream category identifier separately from the user-facing display name.

Unknown categories must not crash parsing or application startup.

### 4.5 Conference rank

Support:

* CCF-A
* CCF-B
* CCF-C
* Unranked
* Unknown

CCF-A is the default discovery filter, not a permanent restriction on tracked conferences.

### 4.6 Deadline selection

For every tracked conference:

* inspect relevant editions and deadlines;
* select the nearest valid future deadline;
* do not depend on source-array order;
* when the abstract deadline has passed but the paper deadline remains open, select the paper deadline;
* when all current deadlines are closed but a next edition is TBD, prefer the next-edition TBD state;
* when no future or TBD edition is available, report the conference as closed or awaiting the next edition.

### 4.7 Main-list sorting

The tracked-conference list must sort in this order:

1. Conferences with future deadlines
2. Conferences with TBD deadlines
3. Conferences whose known deadlines are closed
4. Conferences whose source data is unavailable

Conferences with future deadlines are sorted by:

1. deadline ascending;
2. conference abbreviation ascending when deadlines are equal.

Do not group the main list by category or rank.

Category, rank, added date, and repository order must not affect the default deadline ordering.

---

## 5. Date and Time Rules

Business logic must not call `Date()` directly.

Use a clock abstraction:

```swift
protocol Clock {
    var now: Date { get }
}
```

Production code may use:

```swift
struct SystemClock: Clock {
    var now: Date { Date() }
}
```

Tests must use a fixed clock.

The standard test reference time is:

```text
2026-06-23T00:00:00Z
```

Store and preserve:

* the original deadline value;
* the original timezone identifier;
* the parsed absolute `Date`;
* the locally formatted display value.

Do not overwrite source deadline information with a localized display string.

AoE must be interpreted as UTC-12.

IANA timezone identifiers must be parsed using `TimeZone(identifier:)`. Do not hard-code daylight-saving offsets.

Unit tests must not depend on:

* the current wall-clock time;
* the developer machine’s timezone;
* the developer machine’s locale.

Use explicit locale, calendar, and timezone settings in tests where formatting is involved.

---

## 6. UI Rules

The main launcher is deadline-focused.

Use a compact table rather than large conference cards.

The main table should prioritize:

```text
Tracked state
Conference
Remaining time
Original deadline
Local time
Actions
```

Do not add a category column to the primary launcher table unless a later requirement explicitly calls for it.

Category and CCF rank belong in:

* conference discovery;
* conference details;
* hover or secondary metadata.

The UI must support light and dark mode.

Use monospaced digits for countdown and date values where appropriate.

Keep business rules out of SwiftUI views.

Views must not directly:

* parse YAML;
* access URLSession;
* query SwiftData for domain decisions;
* schedule UserNotifications;
* calculate complex deadline-selection rules.

---

## 7. Data Source Rules

Use structured upstream conference data.

Do not:

* scrape `ccfddl.top` HTML;
* simulate dropdown selections;
* parse webpage DOM output;
* depend on browser automation.

The remote data source, parser, repository, and UI must remain separate.

A malformed individual conference record must not make the whole conference catalog unavailable.

Preserve the last successful local snapshot so the application can remain useful offline.

Replacing conference catalog data must not delete tracked-conference records.

---

## 8. Persistence Rules

Repositories are responsible for persistence and consistency.

Repositories are not responsible for all business policy.

In particular:

* `TrackedConferenceRepository` persists tracked records;
* `ConferenceTrackingService` enforces the 10-conference limit;
* replacing conference catalog data must not clear tracked records;
* duplicate tracked records must not be persisted;
* repository tests should use an in-memory SwiftData container when testing SwiftData implementations.

Do not make domain tests depend on SwiftData.

---

## 9. Notification Rules

Unit tests must never schedule real system notifications.

Use a notification abstraction and a mock scheduler.

Notification identifiers must be deterministic:

```text
topconf.{deadlineID}.{offsetSeconds}
```

Requirements:

* do not create duplicate notifications for the same deadline and offset;
* do not schedule reminders in the past;
* cancel and reschedule notifications when a deadline changes;
* cancel obsolete notifications when a dated deadline becomes TBD;
* handle denied notification permission explicitly.

---

## 10. Engineering Rules

* Do not use `try!`.
* Do not use `fatalError` in production code.
* Avoid uncontrolled force unwraps.
* Do not delete tests to make a change pass.
* Do not weaken assertions to hide incorrect behavior.
* Do not mark failing required tests as skipped.
* Do not use the real network in unit tests.
* Do not send real notifications in tests.
* Do not open the real browser in tests.
* Prefer small, cohesive types.
* Prefer pure domain services where practical.
* Inject dependencies through protocols.
* Keep concrete dependency construction in the application composition root.
* Reuse correct existing code instead of creating duplicate models or services.
* Do not perform unrelated refactors during a scoped task.
* Do not implement future SOP phases unless explicitly requested.
* Do not create unnecessary nested project directories.

---

## 11. Project Inspection

When entering the repository for the first time, or when the current state is unclear, inspect before editing.

Read:

1. `AGENTS.md`
2. `docs/TOPCONF_SOP.md`
3. `README.md`
4. Xcode project and scheme configuration
5. Relevant source files
6. Relevant test files

Inspect Git state:

```bash
git status --short
git branch --show-current
git log --oneline -5
```

Inspect project structure:

```bash
find . -maxdepth 3 -type f | sort
```

Inspect Xcode targets and schemes:

```bash
xcodebuild -list
```

Do not assume that the scheme is named `TopConf`. Use the actual shared scheme discovered in the repository.

If uncommitted work already exists, do not overwrite, reset, delete, or revert it without explicit instruction.

---

## 12. Baseline Before Editing

Before making the first change in a task:

1. inspect the relevant source and test files;
2. determine the current SOP phase;
3. run the existing build when practical;
4. run the relevant existing tests;
5. report pre-existing failures separately from failures introduced by the task.

Expected build command form:

```bash
xcodebuild build \
  -scheme TopConf \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData
```

Expected test command form:

```bash
xcodebuild test \
  -scheme TopConf \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData
```

Replace `TopConf` with the actual shared scheme when different.

If the baseline fails, identify the cause before making broad project changes.

Possible causes include:

* missing Xcode project;
* missing or unshared scheme;
* signing configuration;
* missing test target;
* package resolution failure;
* existing compile failure;
* unavailable SDK;
* incorrect project configuration.

---

## 13. Development Workflow

For every implementation task, follow:

```text
Inspect
→ Plan
→ Implement
→ Focused Tests
→ Full Relevant Tests
→ Diff Review
→ Report
```

Before editing:

1. read the relevant source and test files;
2. compare the repository with the requested SOP phase;
3. identify the smallest coherent change;
4. give a concise implementation plan.

During implementation:

* modify only files required for the current task;
* preserve existing correct behavior;
* add or update tests with production changes;
* avoid speculative abstractions unrelated to the current phase.

After implementation:

1. run focused tests;
2. run the full relevant test suite;
3. inspect `git status`;
4. inspect `git diff --stat`;
5. inspect the complete relevant diff;
6. check for unrelated changes and architectural violations;
7. report actual commands and results.

Do not declare completion while required tests fail.

---

## 14. Test Workflow

Run focused tests first.

Example:

```bash
xcodebuild test \
  -scheme TopConf \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  -only-testing:TopConfTests/ConferenceTrackingServiceTests
```

Then run the complete relevant unit test suite:

```bash
xcodebuild test \
  -scheme TopConf \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData
```

When tests fail:

1. read the actual failure;
2. determine whether it is a production-code, fixture, configuration, or pre-existing issue;
3. fix the underlying issue;
4. rerun the focused test;
5. rerun the relevant full suite.

Do not solve failures by deleting tests, weakening assertions, or hiding failures with skips.

---

## 15. Diff Review

After tests pass, inspect:

```bash
git status --short
git diff --stat
git diff
```

Review for:

* unrelated file changes;
* duplicate domain models;
* Domain importing forbidden frameworks;
* use of real time in domain tests;
* unstable conference IDs;
* incorrect 10-item boundary handling;
* deadline-selection errors;
* incorrect cross-category sorting;
* missing tests;
* accidental package additions;
* Xcode project configuration damage;
* unnecessary directory nesting;
* `try!`, `fatalError`, and unsafe force unwraps.

Do not modify unrelated user changes.

---

## 16. Phase Boundaries

Follow `docs/TOPCONF_SOP.md`.

The initial phases are:

### Phase 0

Project initialization:

* valid macOS Xcode project;
* App target;
* Unit Test target;
* UI Test target;
* macOS 14 minimum;
* shared scheme;
* baseline README and repository structure;
* successful empty build and test execution.

### Phase 1

Domain layer only:

* domain models;
* clock abstraction;
* tracking policy;
* discovery service;
* tracking service;
* deadline selection;
* tracked-conference resolution;
* sorting;
* countdown calculation;
* search;
* test support;
* domain unit tests.

During Phase 1, do not implement:

* full SwiftUI feature views;
* NSPanel;
* global hotkeys;
* SwiftData;
* YAML parsing;
* remote synchronization;
* UserNotifications;
* menu bar functionality.

Do not advance to a later phase unless explicitly instructed.

---

## 17. Required Reporting

At the end of a task, report:

```text
Phase:
Goal:

Baseline:
- Build command:
- Build result:
- Test command:
- Tests passed:
- Tests failed:
- Tests skipped:

Completed:

Files Created:

Files Modified:

Tests Added:

Focused Test Command:

Full Test Command:

Final Test Result:
- Passed:
- Failed:
- Skipped:
- Exit code:

Diff Summary:

Known Issues:

Deferred Work:

Recommended Next Phase:
```

Always distinguish:

* pre-existing failures;
* failures introduced by the current change;
* known limitations deliberately deferred to a later phase.

Do not report “everything works” without actual test evidence.

---

## 18. Source-Control Safety

Do not run destructive Git commands without explicit instruction.

Do not use:

```bash
git reset --hard
git clean -fd
git checkout -- .
git restore .
```

when they could remove existing user work.

Do not amend, squash, rebase, or push unless explicitly requested.

Do not create commits unless the user asks for a commit.

Preserve uncommitted work that existed before the current task.

---

## 19. Definition of Done

A task is complete only when:

* requested scope is implemented;
* scope does not include unrelated future phases;
* relevant tests exist;
* focused tests pass;
* the full relevant test suite passes, or pre-existing failures are clearly isolated;
* the diff has been reviewed;
* no unrelated user work was overwritten;
* actual commands and results are reported;
* known risks and deferred work are stated honestly.

The governing principle is:

> Read the rules before the code, establish the baseline before editing, implement one coherent scope at a time, verify with real tests, and review every diff before declaring completion.

