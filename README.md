# TopConf

TopConf is a native macOS menu bar application for tracking academic conference deadlines.

Press `⌥ Space` from anywhere on macOS to open a compact Spotlight-style launcher and immediately view the deadlines of the conferences you care about most.

The application is designed for researchers who want a fast, focused, and reliable way to track submission deadlines without repeatedly searching conference websites or manually converting timezones.

---

## Status

TopConf is currently under development.

TopConf `1.0.0` is the first public macOS release prepared from this
repository. The release build requires macOS 14 or later and is distributed as
a downloadable DMG artifact from GitHub Releases.

The project is implemented in phases. See:

* `AGENTS.md`
* `docs/TOPCONF_SOP.md`

The current implementation phase should be determined from the repository contents and test status rather than assumed from this README.

---

## Core Features

TopConf is designed to support:

* Native macOS menu bar application
* Global `⌥ Space` launcher
* Spotlight-style floating window
* Search and discovery across the supported conference catalog
* Tracking up to 10 selected conferences
* Deadline-first compact table layout
* Sorting by nearest valid submission deadline
* Conference search
* Conference discovery by category and CCF rank
* Multiple deadlines per conference
* Original timezone and Beijing-time display
* AoE deadline support
* IANA timezone support
* Local macOS notifications
* Offline conference cache
* Structured upstream data synchronization
* Light and dark mode

---

## Conference Scope

Conference discovery focuses on these CCF categories:

* Artificial Intelligence
* Computer Graphics and Multimedia
* Human-Computer Interaction and Ubiquitous Computing
* Interdisciplinary, Comprehensive, and Emerging Areas

The default discovery filter is:

```text
Selected categories: all four supported categories
CCF rank: CCF-A
```

The discovery filter is only used to help users find conferences.

The 10-conference limit applies only to the tracked set. It must not cap the
catalog, search results, category/rank results, bundled seed data, or future
structured synchronization.

A conference that is already being tracked must not disappear automatically because:

* its CCF rank changes;
* its category changes;
* its display name changes;
* a new edition is published;
* its next deadline has not yet been announced;
* the upstream source temporarily omits it.

---

## Product Behavior

Users track conferences rather than individual conference editions.

For example, the user tracks:

```text
ICLR
NeurIPS
CHI
SIGGRAPH
```

The application resolves the relevant edition and nearest valid deadline automatically.

Users do not need to re-add a conference when a new edition is published.

The maximum number of tracked conferences is:

```text
10
```

The 10th conference must be accepted. The 11th conference must be rejected.

---

## Main Launcher

The primary interface is a compact, deadline-focused table.

Expected columns:

```text
Tracked state
Conference
Remaining time
Original deadline
Beijing time
Actions
```

Example:

```text
★  CHI 2027       18 days   Sep 12 · 23:59 AoE   Sep 13 · 19:59 Beijing
★  NeurIPS 2027   35 days   Sep 29 · 23:59 AoE   Sep 30 · 19:59 Beijing
★  ACM MM 2027    62 days   Oct 26 · 23:59 AoE   Oct 27 · 19:59 Beijing
★  SIGGRAPH       TBD       Not announced        —
```

The main list is not grouped by category or CCF rank.

Default ordering:

1. Future deadlines
2. TBD deadlines
3. Closed deadlines
4. Unavailable source data

Future deadlines are sorted by:

1. deadline ascending;
2. conference abbreviation ascending when deadlines are equal.

---

## Keyboard Shortcuts

Planned shortcuts:

| Shortcut      | Action                     |
| ------------- | -------------------------- |
| `⌥ Space`     | Show or hide TopConf       |
| `↑` / `↓`     | Move selection             |
| `Enter`       | Open conference details    |
| `⌘ Enter`     | Open conference website    |
| `⌘ D`         | Configure reminders        |
| `⌘ Backspace` | Remove tracked conference  |
| `⌘ M`         | Open conference management |
| `Esc`         | Close the launcher         |

---

## Deadline Handling

A conference may contain multiple deadlines, such as:

* Abstract deadline
* Full paper deadline
* Supplementary material deadline
* Rebuttal period
* Camera-ready deadline

TopConf selects the nearest valid future deadline.

Example:

```text
Abstract deadline: already closed
Full paper deadline: still open
Supplementary deadline: later
```

The primary list should display the full paper deadline.

Deadline selection must not depend on the order of records in the upstream source.

---

## Timezone Handling

TopConf preserves:

* the original deadline string;
* the original timezone identifier;
* the parsed absolute date;
* the Beijing-time display value.

The default display timezone is:

```text
Asia/Shanghai
```

TopConf should display the timezone label as:

```text
Beijing Time
```

or, in compact table layouts:

```text
Beijing
```

Avoid relying only on the ambiguous abbreviation `CST`, because it may refer to multiple timezones.

### AoE

AoE means Anywhere on Earth and is interpreted as:

```text
UTC-12:00
```

Example:

```text
Original:
Sep 25, 23:59 AoE

Beijing time:
Sep 26, 19:59
```

Beijing time is 20 hours ahead of AoE.

### IANA timezones

The application supports standard IANA timezone identifiers, including:

```text
America/Los_Angeles
America/New_York
Europe/London
Asia/Shanghai
```

Timezone conversion must account for daylight-saving time in regions where it applies.

Beijing time itself does not currently observe daylight-saving time, but source conference timezones may do so.

---

## Architecture

TopConf uses a layered architecture:

```text
App
Domain
Data
Features
Notifications
Shared
```

### App

Application startup and dependency composition.

Responsibilities include:

* application lifecycle;
* dependency container;
* menu bar setup;
* window and panel coordination.

### Domain

Framework-independent business rules.

Responsibilities include:

* conference models;
* tracked-conference policy;
* deadline selection;
* sorting;
* search;
* countdown calculation;
* conference discovery rules.

The Domain layer must not depend on:

* SwiftUI;
* AppKit;
* SwiftData;
* UserNotifications;
* Yams;
* concrete networking implementations.

### Data

Persistence, parsing, synchronization, and caching.

Responsibilities include:

* structured conference data parsing;
* SwiftData repositories;
* remote source access;
* local cache;
* category mapping;
* timezone parsing.

### Features

User-facing application features.

Examples:

* launcher;
* tracked-conference list;
* conference management;
* onboarding;
* details;
* reminders;
* settings.

### Notifications

Local notification scheduling and cancellation.

### Shared

Reusable UI components, extensions, logging, and formatting helpers.

---

## Intended Project Structure

```text
TopConf/
├── App/
├── Domain/
│   ├── Models/
│   ├── Policies/
│   ├── Services/
│   ├── Repositories/
│   ├── Time/
│   └── Errors/
├── Data/
│   ├── Remote/
│   ├── Local/
│   ├── Cache/
│   └── Fixtures/
├── Features/
│   ├── Launcher/
│   ├── TrackedConferenceList/
│   ├── ConferenceManagement/
│   ├── ConferenceDetail/
│   ├── Reminders/
│   ├── Onboarding/
│   └── Settings/
├── Notifications/
├── Shared/
├── TopConfTests/
└── TopConfUITests/
```

The actual repository may be built incrementally according to the current implementation phase.

---

## Technology

TopConf uses:

* Swift
* SwiftUI
* AppKit
* SwiftData
* UserNotifications
* URLSession
* XCTest
* Yams
* Swift Package Manager

Minimum supported system:

```text
macOS 14+
```

---

## Requirements

Development requires:

* macOS
* Xcode with a macOS 14 or later SDK
* Swift 5.9 or later
* Git

Use the current stable Xcode release supported by the project.

---

## Installation

Download `TopConf-1.0.0.dmg` from the GitHub Releases page, open the disk
image, and drag `TopConf.app` into Applications.

TopConf runs as an accessory menu bar app and does not show a Dock icon during
normal use. Use the calendar icon in the macOS menu bar or press `⌥ Space` to
show the floating deadline launcher.

The current repository release is signed for local execution by Xcode during
packaging. It is not notarized and is not distributed with a Developer ID
signature in this repository state. Depending on macOS security settings, you
may need to approve the first launch in System Settings.

---

## Privacy

TopConf stores tracked conferences, cached catalog data, reminder
configuration, and preferences locally on your Mac. Local notification requests
are scheduled through macOS. TopConf does not require an account and does not
upload tracked conference selections or reminder settings.

---

## Getting Started

Enter the repository:

```bash
cd ~/AI/projects/topconf
```

Inspect the repository:

```bash
git status
xcodebuild -list
```

Open the project in Xcode:

```bash
open TopConf.xcodeproj
```

If the project uses a workspace instead, open the discovered `.xcworkspace`.

Do not assume the project or scheme name without checking:

```bash
xcodebuild -list
```

---

## Build

Expected command:

```bash
xcodebuild build \
  -scheme TopConf \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData
```

If the shared scheme has a different name, replace `TopConf` with the actual scheme reported by:

```bash
xcodebuild -list
```

---

## Release Verification

Before declaring a release candidate, run:

```bash
xcodebuild test \
  -project TopConf.xcodeproj \
  -scheme TopConf \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData

xcodebuild build \
  -project TopConf.xcodeproj \
  -scheme TopConf \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData
```

The Release app should be inspected at:

```text
.build/DerivedData/Build/Products/Release/TopConf.app
```

Final manual macOS checks include confirming the menu bar item appears, the Dock icon stays hidden, `⌥ Space` toggles the panel, `Esc` closes it, and real notification permission/delivery works as expected.

---

## Distribution

Release packaging creates:

```text
dist/TopConf-1.0.0.dmg
dist/TopConf-1.0.0.dmg.sha256
```

The DMG volume is named:

```text
TopConf 1.0.0
```

The mounted volume contains:

```text
TopConf.app
Applications -> /Applications
```

Do not claim notarization or Developer ID distribution unless those steps have
been configured and verified for a later release.

---

## Test

Run all unit tests:

```bash
xcodebuild test \
  -scheme TopConf \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData
```

Run a focused test class:

```bash
xcodebuild test \
  -scheme TopConf \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  -only-testing:TopConfTests/ConferenceTrackingServiceTests
```

Tests must not depend on:

* the real network;
* the real current time;
* the local machine timezone;
* the local machine locale;
* real system notifications;
* a real browser.

---

## Test Reference Time

Domain tests use the fixed reference time:

```text
2026-06-23T00:00:00Z
```

Business logic must use a clock abstraction rather than calling `Date()` directly.

Example:

```swift
protocol Clock {
    var now: Date { get }
}
```

Timezone-formatting tests must explicitly use:

```text
Asia/Shanghai
```

They must not rely on the developer machine’s current timezone.

---

## Data Source

TopConf must consume structured upstream conference data.

The application must not:

* scrape `ccfddl.top` HTML;
* simulate website dropdown selections;
* parse rendered page DOM;
* use browser automation as its data pipeline.

The remote source, parser, repository, and UI must remain separate.

A malformed individual record must not prevent the rest of the conference catalog from loading.

---

## Offline Behavior

TopConf should remain useful without a network connection.

Expected startup flow:

```text
Launch application
→ Load local cache
→ Display tracked conferences immediately
→ Refresh remote data in the background
→ Validate and persist successful updates
→ Refresh the interface
```

Remote refresh failures must not clear the existing cache.

Replacing conference catalog data must not delete tracked-conference records.

---

## Local Notifications

Planned reminder presets:

```text
90 days before
60 days before
30 days before
14 days before
7 days before
3 days before
1 day before
6 hours before
```

Notification identifiers must be deterministic:

```text
topconf.{deadlineID}.{offsetSeconds}
```

Notification content should display the deadline in Beijing time.

Example:

```text
CHI 2027 Full Paper Deadline is in 7 days
Deadline: Sep 13, 2027 at 19:59 Beijing Time
```

The application must not:

* schedule reminders in the past;
* create duplicate reminders;
* retain obsolete reminders after a deadline changes;
* schedule real system notifications during unit tests.

---

## Development Workflow

Before editing:

1. Read `AGENTS.md`.
2. Read `docs/TOPCONF_SOP.md`.
3. Inspect the repository.
4. Check Git status.
5. Discover actual Xcode targets and schemes.
6. Establish build and test baselines.
7. Determine the current implementation phase.

For every task:

```text
Inspect
→ Plan
→ Implement
→ Focused Tests
→ Full Relevant Tests
→ Diff Review
→ Report
```

Do not advance to a later SOP phase unless explicitly requested.

---

## Implementation Phases

### Phase 0 — Project Initialization

* macOS Xcode project
* App target
* Unit Test target
* UI Test target
* macOS 14 minimum
* shared scheme
* initial repository structure
* baseline build and tests

### Phase 1 — Domain Layer

* conference models
* clock abstraction
* tracking policy
* conference discovery
* conference tracking
* deadline selection
* tracked-conference resolution
* sorting
* countdown calculation
* search
* domain unit tests

### Phase 2 — Fixtures and In-Memory Repositories

* representative conference fixtures
* in-memory repositories
* fixture-driven domain validation

### Phase 3 — SwiftData Persistence

* SwiftData entities
* conference repository
* tracked-conference repository
* reminder repository
* in-memory SwiftData tests

### Phase 4 — Conference Management

* onboarding
* four-category discovery
* CCF-rank filters
* search
* add and remove tracking
* 10-conference tracked-set limit without limiting the catalog or discovery results

### Phase 5 — Main Deadline Table

* compact tracked-conference table
* deadline sorting
* countdown
* original and Beijing time
* TBD, closed, and unavailable states
* details

### Phase 6 — Launcher and Menu Bar

* NSPanel
* global `⌥ Space` shortcut
* menu bar application
* current-screen positioning
* Escape handling
* Dock hiding

### Phase 7 — Notifications

* notification authorization
* reminder configuration
* deterministic notification IDs
* cancellation and rescheduling
* notification tests

### Phase 8 — Remote Synchronization

* structured upstream source
* YAML parser
* category mapping
* caching
* background refresh
* upstream error handling

### Phase 9 — UI Tests and Release Preparation

* accessibility identifiers
* UI tests
* light and dark mode validation
* documentation
* final acceptance checks

---

## Engineering Rules

* Do not use `try!`.
* Do not use `fatalError` in production code.
* Avoid uncontrolled force unwraps.
* Do not delete or weaken tests to make them pass.
* Do not skip required failing tests.
* Keep business logic out of SwiftUI views.
* Inject dependencies through protocols.
* Keep concrete dependencies in the application composition root.
* Do not perform unrelated refactors during scoped tasks.
* Do not implement later phases without explicit instruction.
* Do not create unnecessary nested project directories.
* Do not overwrite existing uncommitted work.

---

## Git Safety

Before editing:

```bash
git status --short
git branch --show-current
git log --oneline -5
```

After editing:

```bash
git status --short
git diff --stat
git diff
```

Do not run destructive commands without explicit instruction:

```bash
git reset --hard
git clean -fd
git checkout -- .
git restore .
```

Do not commit, amend, rebase, squash, or push unless explicitly requested.

---

## Documentation

Project instructions:

* `AGENTS.md`
* `docs/TOPCONF_SOP.md`

These documents define the intended architecture, workflow, phase boundaries, testing requirements, and acceptance criteria.

---

## Current Limitations

The first release is intentionally limited to:

* macOS only;
* a maximum of 10 tracked conferences;
* Beijing time as the default local display timezone;
* local persistence;
* local reminders;
* no account system;
* no cloud sync;
* no multi-device sync;
* no AI conference recommendation;
* no paper project management;
* no collaboration features.

Conference accuracy depends on the quality and freshness of the upstream structured data.

---

## License

A license has not yet been selected.

Do not add or assume a license without an explicit project decision.

---

## Version

### TopConf 1.0.0

Initial public release for macOS 14 or later.
