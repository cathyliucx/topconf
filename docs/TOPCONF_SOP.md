# TopConf macOS Project Build SOP

## 0. Purpose

This SOP defines the product scope, architectural boundaries, domain rules, implementation phases, testing requirements, and final acceptance criteria for TopConf.

This document is intended to guide Codex or another coding agent through the project in controlled phases.

Before making architectural changes, implementing features, or modifying multiple modules, the agent must read:

* `AGENTS.md`
* `README.md`
* `docs/TOPCONF_SOP.md`
* `docs/CODEX_FIRST_ENTRY_SOP.md`

The project must be implemented incrementally. The agent must not attempt to build the entire product in one unbounded task.

Core principle:

> Build and test a stable domain model first, then add persistence, UI, platform integrations, and remote synchronization.

---

# 1. Project Definition

Project name:

```text
TopConf
```

TopConf is a native macOS menu bar application for tracking academic conference submission deadlines.

When the user presses:

```text
⌥ Space
```

the application opens a Spotlight- or Raycast-style floating window that immediately displays up to 10 user-selected conferences, sorted by their nearest valid submission deadline.

The primary interface is deadline-focused and must avoid becoming a conference encyclopedia.

---

# 2. Product Goals

The core goal of TopConf is:

> Allow researchers to press a global shortcut from anywhere on macOS and immediately see the submission deadline, remaining time, original timezone, and Beijing Time for the conferences they care about most.

The first release must support:

* Native macOS menu bar application
* Global `⌥ Space` shortcut
* Spotlight-style floating panel
* Tracking up to 10 conferences
* Conference discovery across selected CCF categories
* CCF-A as the default discovery rank
* Conference search and management
* Cross-category deadline sorting
* Multiple deadlines per conference
* AoE support
* IANA timezone support
* Beijing Time display
* Opening official conference websites
* Local system notifications
* Offline cache
* Structured remote data synchronization
* Unit tests
* Basic UI tests
* Light and dark mode

---

# 3. First-Release Non-Goals

The first release must not implement:

* User accounts
* iCloud sync
* Cloud synchronization
* Multi-device synchronization
* Multi-user collaboration
* AI-based conference recommendations
* Paper project management
* Submission acceptance prediction
* Conference social features
* Chatbot functionality
* Complex kanban boards
* Conference logo system
* Electron
* Tauri
* React Native
* WebView
* HTML scraping
* Browser automation for data collection
* Python as an application runtime

Development scripts may use Python, but the shipped application must not require Python at runtime.

---

# 4. Supported Conference Scope

Conference discovery focuses on these four CCF categories:

1. Artificial Intelligence
2. Computer Graphics and Multimedia
3. Human-Computer Interaction and Ubiquitous Computing
4. Interdisciplinary, Comprehensive, and Emerging Areas

Default discovery filters:

```text
Categories: all four supported categories
Rank: CCF-A
```

These filters are only used to help users discover conferences.

A conference that is already being tracked must not disappear automatically because:

* its CCF rank changes;
* its category changes;
* its display name changes;
* a new edition is published;
* its next deadline has not yet been announced;
* the upstream source temporarily omits it.

---

# 5. Core User Flows

## 5.1 First Launch

On first launch:

1. Load bundled local conference data.
2. If a network connection is available, refresh remote conference data in the background.
3. Show CCF-A conferences from the four supported categories by default.
4. Allow the user to search and select conferences.
5. Allow the user to select at most 10 conferences.
6. Persist stable conference IDs.
7. Open the main deadline table.

Example onboarding interface:

```text
Choose Conferences                                  0 / 10

Search conferences...

Categories:
[AI ✓] [Graphics ✓] [HCI ✓] [Interdisciplinary ✓]

Rank:
[CCF-A ✓] [CCF-B] [CCF-C] [Unranked]

Available Conferences
```

---

## 5.2 Regular Launch

When the user presses:

```text
⌥ Space
```

the main floating panel appears.

The panel displays only tracked conferences.

Example:

```text
┌──────────────────────────────────────────────────────────────────────────┐
│ TopConf                              Manage · 8 / 10       Updated 2h ago │
│ Search tracked conferences...                                           │
├────┬──────────────┬────────────┬──────────────────┬─────────────────────┤
│    │ Conference   │ Remaining  │ Deadline         │ Beijing Time        │
├────┼──────────────┼────────────┼──────────────────┼─────────────────────┤
│ ★  │ CHI 2027     │ 18 days    │ Sep 12 · AoE     │ Sep 13 · 19:59     │
│ ★  │ NeurIPS 2027 │ 35 days    │ Sep 29 · AoE     │ Sep 30 · 19:59     │
│ ★  │ ACM MM 2027  │ 62 days    │ Oct 26 · AoE     │ Oct 27 · 19:59     │
│ ★  │ SIGGRAPH     │ TBD        │ Not announced    │ —                   │
└────┴──────────────┴────────────┴──────────────────┴─────────────────────┘
```

---

## 5.3 Empty State

If the user has not tracked any conferences:

```text
No conferences are being tracked.

Choose up to 10 conferences from Artificial Intelligence,
Computer Graphics and Multimedia, Human-Computer Interaction
and Ubiquitous Computing, or Interdisciplinary, Comprehensive,
and Emerging Areas.

[Choose Conferences]
```

---

# 6. Conference Tracking Rules

## 6.1 Tracking Limit

The user may track at most:

```text
10 conferences
```

Rules:

* The user may add conferences while the current count is between 0 and 9.
* The 10th conference must be accepted.
* The 11th conference must be rejected.
* Adding the same conference twice must be rejected.
* After removing a conference, the user may add another one.
* The tracking limit must be enforced by a domain service.
* The repository must not be the only place enforcing this rule.

Central policy:

```swift
enum TrackingPolicy {
    static let maximumConferenceCount = 10
}
```

The literal value `10` must not be scattered across views, view models, repositories, or services.

---

## 6.2 Tracked Entity

The user tracks:

```text
Conference
```

not:

```text
ConferenceEdition
```

For example, the user tracks:

```text
ICLR
```

rather than:

```text
ICLR 2027
```

When ICLR 2028 is published, the user must not need to add ICLR again.

---

## 6.3 Stable IDs

Conferences must use stable IDs.

Recommended format:

```text
ai-neurips
hci-chi
graphics-siggraph
interdisciplinary-www
```

A stable ID may be generated from:

* upstream category identifier;
* conference abbreviation;
* upstream file path;
* an explicitly maintained alias map.

Do not use:

* array indices;
* newly generated UUIDs on every sync;
* the current conference year;
* frequently changing full display names;

as the unique conference identity.

---

# 7. Conference Category Model

Do not store only the localized display name.

Recommended model:

```swift
struct ConferenceCategory: Codable, Hashable, Sendable {
    let sourceID: String
    let displayName: String
}
```

Example:

```text
sourceID: AI
displayName: Artificial Intelligence
```

The actual `sourceID` values must be determined by inspecting the real upstream structured data. The agent must not invent them.

Category mapping belongs in the Data layer:

```swift
protocol ConferenceCategoryMapping {
    func map(sourceValue: String) -> ConferenceCategory
}
```

Unknown categories must not cause:

* YAML parsing to crash;
* application startup to fail;
* the entire conference catalog to be discarded.

The original source identifier must be preserved.

---

# 8. CCF Rank Model

Support:

```swift
enum CCFRank: String, Codable, CaseIterable, Sendable {
    case a
    case b
    case c
    case unranked
    case unknown
}
```

CCF-A is the default discovery filter, not a permanent restriction on tracked conferences.

If a tracked conference changes from CCF-A to CCF-B:

* keep tracking it;
* update the displayed rank;
* optionally show a rank-change notice;
* do not remove it automatically.

---

# 9. Domain Models

## 9.1 Conference

```swift
struct Conference: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let abbreviation: String
    let fullName: String
    let category: ConferenceCategory
    let ccfRank: CCFRank
    let websiteURL: URL?
    let editions: [ConferenceEdition]
    let lastUpdatedAt: Date?
}
```

---

## 9.2 ConferenceEdition

```swift
struct ConferenceEdition: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let conferenceID: String
    let year: Int
    let conferenceStartDate: Date?
    let conferenceEndDate: Date?
    let location: String?
    let deadlines: [Deadline]
}
```

Recommended edition ID:

```text
ai-neurips-2027
```

---

## 9.3 Deadline

```swift
struct Deadline: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let editionID: String
    let type: DeadlineType
    let date: Date?
    let originalTimeZoneIdentifier: String?
    let rawDateValue: String?
    let comment: String?
}
```

Recommended deadline IDs:

```text
ai-neurips-2027-abstract
ai-neurips-2027-paper
```

Deadline IDs must be generated deterministically.

---

## 9.4 DeadlineType

Support at least:

```swift
enum DeadlineType: String, Codable, Hashable, Sendable {
    case abstract
    case paper
    case supplementary
    case rebuttal
    case cameraReady
    case registration
    case other
}
```

Unknown upstream deadline types may map to `.other`, while preserving the original description.

---

## 9.5 TrackedConference

```swift
struct TrackedConference: Identifiable, Codable, Hashable, Sendable {
    var id: String { conferenceID }

    let conferenceID: String
    let addedAt: Date
}
```

The first release does not require manual ordering.

The main list must always be sorted by deadline.

---

## 9.6 ConferenceAvailability

```swift
enum ConferenceAvailability: Equatable, Sendable {
    case available
    case deadlineToBeDetermined
    case allDeadlinesClosed
    case sourceUnavailable
}
```

---

## 9.7 ResolvedTrackedConference

```swift
struct ResolvedTrackedConference: Identifiable, Equatable, Sendable {
    var id: String { conferenceID }

    let conferenceID: String
    let conference: Conference?
    let edition: ConferenceEdition?
    let primaryDeadline: Deadline?
    let availability: ConferenceAvailability
}
```

---

## 9.8 ConferenceDiscoveryFilter

```swift
struct ConferenceDiscoveryFilter: Equatable, Sendable {
    var categorySourceIDs: Set<String>
    var ranks: Set<CCFRank>
    var query: String
}
```

Multiple selected categories use union semantics:

```text
AI OR Graphics OR HCI OR Interdisciplinary
```

Category and rank filters use intersection semantics:

```text
Selected Categories AND Selected Ranks
```

---

# 10. Core Domain Services

## 10.1 ConferenceTrackingService

Responsibilities:

* determine whether a conference can be added;
* verify that the conference exists;
* prevent duplicates;
* enforce the 10-conference limit;
* determine removal results.

Return explicit outcomes:

```swift
enum TrackingResult: Equatable {
    case added
    case removed
    case alreadyTracked
    case notTracked
    case limitReached(maximum: Int)
    case conferenceNotFound
}
```

Prefer pure functions for core rules where practical.

---

## 10.2 ConferenceDiscoveryService

Responsibilities:

* filter by category;
* filter by CCF rank;
* filter by search query;
* search abbreviation;
* search full name;
* normalize case and whitespace;
* preserve tracking state.

Discovery filters must never remove tracked conferences.

---

## 10.3 DeadlineSelectionService

Select the most relevant deadline from all editions and deadlines of a conference.

Rules:

1. Inspect all candidate editions.
2. Inspect all parseable deadlines.
3. Collect all future deadlines.
4. Select the earliest future deadline.
5. Do not rely on source array order.
6. If the abstract deadline has passed but the paper deadline remains open, select the paper deadline.
7. If all current deadlines are closed but a future edition exists with TBD deadlines, return that future TBD edition.
8. If no future or TBD deadline exists, return Closed.
9. Do not simply select the edition with the highest year.
10. Determine the relevant edition from actual deadline state.

---

## 10.4 TrackedConferenceResolver

Resolve:

```text
TrackedConference
+
Current Conference data
+
Last known cached data
```

into:

```text
ResolvedTrackedConference
```

It must handle:

* normal conference resolution;
* future deadline resolution;
* next-edition TBD;
* all deadlines closed;
* conference missing from current upstream data;
* last-known cache fallback;
* display-name changes;
* rank changes;
* category changes.

---

## 10.5 ConferenceSortingService

Input:

```swift
[ResolvedTrackedConference]
```

Sort order:

```text
1. Future deadline
2. TBD
3. Closed
4. Source unavailable
```

Within future deadlines:

```text
deadline ascending
abbreviation ascending
```

The following must not affect default sorting:

* category;
* CCF rank;
* added date;
* repository order;
* fixture order;
* upstream YAML order.

---

## 10.6 DeadlineCalculator

Responsibilities:

* determine deadline status;
* calculate remaining time;
* generate remaining-time text;
* determine whether a reminder time is still valid.

Define:

```swift
enum DeadlineStatus: Equatable {
    case upcoming
    case closingSoon
    case closed
    case toBeDetermined
}
```

Rules:

```text
date == nil             → TBD
date <= now             → Closed
date - now <= 7 days    → ClosingSoon
otherwise               → Upcoming
```

---

## 10.7 SearchService

Normalize and search:

* lowercase conversion;
* trimming leading and trailing whitespace;
* abbreviation;
* full name;
* year;
* empty query returns all;
* original models remain unchanged.

---

# 11. Clock Abstraction

Business logic must not call:

```swift
Date()
```

directly.

Define:

```swift
protocol Clock {
    var now: Date { get }
}
```

Production implementation:

```swift
struct SystemClock: Clock {
    var now: Date { Date() }
}
```

Test implementation:

```swift
struct FixedClock: Clock {
    let now: Date
}
```

Standard test reference time:

```text
2026-06-23T00:00:00Z
```

---

# 12. Timezone Rules

## 12.1 Default Display Timezone

TopConf uses Beijing Time by default:

```text
Asia/Shanghai
```

Display label:

```text
Beijing Time
```

Compact table label:

```text
Beijing
```

Do not rely only on:

```text
CST
```

because `CST` is ambiguous across multiple regions.

---

## 12.2 Preserve Original Deadline Information

Store and preserve:

* original deadline string;
* original timezone identifier;
* parsed absolute `Date`;
* Beijing Time display value.

Beijing Time is a presentation value and must not overwrite the original deadline.

---

## 12.3 AoE

AoE means Anywhere on Earth and must be interpreted as:

```text
UTC-12:00
```

Example:

```text
Original:
Sep 25, 23:59 AoE

Beijing Time:
Sep 26, 19:59
```

Beijing Time is 20 hours ahead of AoE.

---

## 12.4 IANA Timezones

Support standard IANA timezone identifiers, including:

```text
America/Los_Angeles
America/New_York
Europe/London
Asia/Shanghai
```

Use:

```swift
TimeZone(identifier:)
```

Do not hard-code:

```text
America/Los_Angeles
```

as UTC-8 because daylight-saving time applies.

---

## 12.5 Remaining-Time Formatting

Rules:

```text
>= 48 hours    show whole days
1–48 hours     show whole hours
< 1 hour       show whole minutes
past           Closed
no date        TBD
```

Examples:

```text
100 days
18 days
3 days
18 hours
45 min
Closed
TBD
```

Do not display seconds.

---

# 13. Repository Interfaces

## 13.1 ConferenceRepository

```swift
protocol ConferenceRepository {
    func loadAll() async throws -> [Conference]

    func conference(
        id: String
    ) async throws -> Conference?

    func replaceAll(
        _ conferences: [Conference],
        updatedAt: Date
    ) async throws

    func lastUpdatedAt() async throws -> Date?
}
```

---

## 13.2 TrackedConferenceRepository

```swift
protocol TrackedConferenceRepository {
    func loadAll() async throws -> [TrackedConference]

    func contains(
        conferenceID: String
    ) async throws -> Bool

    func add(
        _ trackedConference: TrackedConference
    ) async throws

    func remove(
        conferenceID: String
    ) async throws

    func count() async throws -> Int
}
```

The repository is responsible for persistence.

`ConferenceTrackingService` is responsible for the business limit.

---

## 13.3 ReminderRepository

```swift
protocol ReminderRepository {
    func rules(
        for deadlineID: String
    ) async throws -> [ReminderRule]

    func save(
        _ rule: ReminderRule
    ) async throws

    func delete(
        ruleID: String
    ) async throws

    func deleteAll(
        for deadlineID: String
    ) async throws
}
```

---

# 14. Technology Stack

Required:

```text
Swift
SwiftUI
AppKit
SwiftData
UserNotifications
URLSession
XCTest
Swift Package Manager
```

YAML parsing may use:

```text
Yams
```

Minimum supported system:

```text
macOS 14+
```

---

# 15. Architecture Layers

Use:

```text
App
Domain
Data
Features
Notifications
Shared
```

Dependency direction:

```text
Features ──────→ Domain
Data ─────────→ Domain
Notifications → Domain abstractions
App ──────────→ all concrete dependencies
```

The Domain layer must not depend on:

* SwiftUI;
* AppKit;
* SwiftData;
* UserNotifications;
* Yams;
* concrete networking implementations.

External capabilities must be injected through protocols.

---

# 16. Recommended Project Structure

```text
TopConf/
├── App/
│   ├── TopConfApp.swift
│   ├── AppDelegate.swift
│   ├── AppState.swift
│   ├── DependencyContainer.swift
│   └── AppEnvironment.swift
│
├── Domain/
│   ├── Models/
│   │   ├── Conference.swift
│   │   ├── ConferenceEdition.swift
│   │   ├── Deadline.swift
│   │   ├── DeadlineType.swift
│   │   ├── ConferenceCategory.swift
│   │   ├── CCFRank.swift
│   │   ├── TrackedConference.swift
│   │   ├── ReminderRule.swift
│   │   ├── ConferenceAvailability.swift
│   │   ├── ConferenceDiscoveryFilter.swift
│   │   └── ResolvedTrackedConference.swift
│   │
│   ├── Policies/
│   │   ├── TrackingPolicy.swift
│   │   └── DeadlineUrgencyPolicy.swift
│   │
│   ├── Services/
│   │   ├── ConferenceTrackingService.swift
│   │   ├── ConferenceDiscoveryService.swift
│   │   ├── TrackedConferenceResolver.swift
│   │   ├── DeadlineSelectionService.swift
│   │   ├── DeadlineCalculator.swift
│   │   ├── ConferenceSortingService.swift
│   │   └── SearchService.swift
│   │
│   ├── Repositories/
│   │   ├── ConferenceRepository.swift
│   │   ├── TrackedConferenceRepository.swift
│   │   └── ReminderRepository.swift
│   │
│   ├── Time/
│   │   └── Clock.swift
│   │
│   └── Errors/
│       └── DomainError.swift
│
├── Data/
│   ├── Remote/
│   │   ├── ConferenceRemoteSource.swift
│   │   ├── GitHubConferenceSource.swift
│   │   ├── ConferenceYAMLParser.swift
│   │   ├── ConferenceCategoryMapper.swift
│   │   ├── TimeZoneParser.swift
│   │   └── DTO/
│   │       ├── ConferenceYAMLDTO.swift
│   │       ├── ConferenceEditionDTO.swift
│   │       └── DeadlineDTO.swift
│   │
│   ├── Local/
│   │   ├── SwiftDataConferenceRepository.swift
│   │   ├── SwiftDataTrackedConferenceRepository.swift
│   │   ├── SwiftDataReminderRepository.swift
│   │   └── Entities/
│   │       ├── ConferenceEntity.swift
│   │       ├── ConferenceEditionEntity.swift
│   │       ├── DeadlineEntity.swift
│   │       ├── TrackedConferenceEntity.swift
│   │       └── ReminderEntity.swift
│   │
│   ├── Cache/
│   │   ├── ConferenceCacheCoordinator.swift
│   │   └── LastKnownConferenceSnapshot.swift
│   │
│   └── Fixtures/
│       ├── conferences.json
│       ├── sample_normal.yml
│       ├── sample_multiple_deadlines.yml
│       ├── sample_aoe.yml
│       ├── sample_iana_timezone.yml
│       ├── sample_tbd.yml
│       ├── sample_closed.yml
│       ├── sample_unknown_category.yml
│       └── sample_invalid.yml
│
├── Features/
│   ├── Launcher/
│   │   ├── LauncherPanelController.swift
│   │   ├── LauncherView.swift
│   │   ├── GlobalHotkeyManager.swift
│   │   └── ActiveScreenResolver.swift
│   │
│   ├── TrackedConferenceList/
│   │   ├── TrackedConferenceListView.swift
│   │   ├── TrackedConferenceTableView.swift
│   │   ├── TrackedConferenceRowView.swift
│   │   └── TrackedConferenceListViewModel.swift
│   │
│   ├── ConferenceManagement/
│   │   ├── ConferenceManagementView.swift
│   │   ├── ConferenceManagementViewModel.swift
│   │   ├── ConferenceDiscoveryListView.swift
│   │   ├── TrackedSelectionView.swift
│   │   └── ConferenceFilterBar.swift
│   │
│   ├── ConferenceDetail/
│   │   ├── ConferenceDetailView.swift
│   │   └── ConferenceDetailViewModel.swift
│   │
│   ├── Reminders/
│   │   ├── ReminderPopoverView.swift
│   │   └── ReminderViewModel.swift
│   │
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   └── OnboardingViewModel.swift
│   │
│   └── Settings/
│       ├── SettingsView.swift
│       └── SettingsViewModel.swift
│
├── Notifications/
│   ├── NotificationScheduling.swift
│   ├── DeadlineNotificationService.swift
│   ├── DeadlineNotificationRequest.swift
│   └── NotificationIdentifier.swift
│
├── Shared/
│   ├── Components/
│   │   ├── EmptyStateView.swift
│   │   ├── DeadlineBadge.swift
│   │   ├── ConferenceCategoryTag.swift
│   │   └── LoadingIndicator.swift
│   │
│   ├── Extensions/
│   │   ├── Date+Formatting.swift
│   │   ├── String+Normalization.swift
│   │   └── View+Accessibility.swift
│   │
│   └── Logging/
│       └── AppLogger.swift
│
├── TopConfTests/
└── TopConfUITests/
```

---

# 17. Fixture Data Requirements

During development, use local fixtures first.

Fixtures must cover at least:

* 5 normal upcoming conferences;
* 1 conference with multiple deadlines;
* 1 deadline using AoE;
* 1 deadline using an IANA timezone;
* 1 conference with a TBD deadline;
* 1 closed conference;
* 1 conference with an unknown category;
* 1 malformed record.

A single conference may cover multiple scenarios.

For example:

```text
multiple deadlines
+
AoE
```

The project does not need a fixed number of separate conferences.

---

# 18. Data Source Rules

Define:

```swift
protocol ConferenceRemoteSource {
    func fetchConferences() async throws -> [Conference]
}
```

Implement:

```swift
final class GitHubConferenceSource: ConferenceRemoteSource
```

Use structured upstream data.

Do not:

* scrape `ccfddl.top` HTML;
* simulate website dropdown selections;
* parse rendered DOM output;
* use browser automation as the production data pipeline.

---

# 19. Synchronization Flow

Application startup:

```text
Load local cache
→ Display tracked conferences immediately
→ Fetch remote data in the background
→ Parse and validate
→ Update the conference catalog
→ Preserve tracked records
→ Re-resolve current deadlines
→ Refresh the interface
```

When the network request fails:

* do not clear the cache;
* do not clear tracked records;
* show the last update time;
* continue using existing data.

---

# 20. Upstream Change Handling

## 20.1 Category Change

```text
Keep tracking
Update the category
Do not remove automatically
```

## 20.2 CCF Rank Change

```text
Keep tracking
Update the rank
Do not remove automatically
```

## 20.3 Name Change

When the stable ID still matches:

```text
Keep tracking
Update the display name
```

## 20.4 New Edition Published

```text
Resolve the new edition automatically
Do not require the user to add the conference again
```

## 20.5 Conference Temporarily Missing Upstream

```text
Preserve TrackedConference
Use the last successful cache
Mark Source unavailable
Allow manual removal
```

---

# 21. Cache Rules

Preserve the last successful snapshot:

```swift
struct LastKnownConferenceSnapshot: Codable {
    let conference: Conference
    let capturedAt: Date
}
```

Old cached data must display its capture or update time.

If the cached deadline may no longer be valid, the application must not silently schedule new system reminders from it.

---

# 22. Main Interface Design

Use a compact table, not large cards.

Column order:

```text
Tracked state
Conference
Remaining time
Original deadline
Beijing Time
Actions
```

The full conference name may appear as secondary text below the abbreviation.

Do not repeat the following in the main table:

* category;
* CCF rank;
* location;
* long conference description.

Show those details in the conference detail view.

---

## 22.1 Remaining-Time Styling

Apply restrained status styling only to the Remaining column.

```text
> 60 days       normal primary text
30–60 days      subtle emphasis
7–30 days       warning emphasis
< 7 days        strong warning
Closed          disabled gray
TBD             secondary text
```

Do not color the entire row.

Use:

```swift
.monospacedDigit()
```

to avoid visual movement as numbers change.

---

# 23. Keyboard Interaction

Support:

```text
↑ / ↓        Move selection
Enter        Open conference details
⌘ Enter      Open official website
⌘ D          Configure reminders
⌘ Backspace  Remove tracked conference
⌘ M          Open conference management
Esc          Close floating panel
```

---

# 24. Conference Management Interface

Use a two-column layout:

```text
Available Conferences
My Conferences
```

Support:

* search;
* multi-select across four categories;
* multi-select across CCF ranks;
* add conference;
* remove conference;
* display `x / 10`;
* disable additional add buttons when 10 conferences are tracked;
* restore add capability after removal.

Manual drag-and-drop ordering is not required in the first release.

The main list remains deadline-sorted.

---

# 25. Global Shortcut and Floating Panel

Use:

```text
NSPanel
```

Recommended configuration:

```swift
panel.level = .floating
panel.collectionBehavior = [
    .canJoinAllSpaces,
    .fullScreenAuxiliary,
    .transient
]
panel.isFloatingPanel = true
panel.hidesOnDeactivate = true
panel.isReleasedWhenClosed = false
panel.titleVisibility = .hidden
panel.titlebarAppearsTransparent = true
```

Default size:

```text
Width: 960
Height: 580
Minimum width: 760
Minimum height: 420
```

Requirements:

* center on the currently active screen;
* focus the search field when opened;
* `⌥ Space` toggles show and hide;
* `Esc` closes the panel;
* clicking outside closes the panel;
* remain available from the menu bar;
* hide the Dock icon by default.

---

# 26. Local Reminders

Preset reminders:

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

A single deadline may have multiple reminders.

Notification ID:

```text
topconf.{deadlineID}.{offsetSeconds}
```

Requirements:

* generate IDs deterministically;
* avoid duplicates;
* do not schedule reminders in the past;
* cancel obsolete notifications when a deadline changes;
* reschedule notifications after a deadline update;
* cancel dated reminders when a deadline becomes TBD;
* never send real notifications during unit tests.

Notification content must use Beijing Time:

```text
CHI 2027 Full Paper Deadline is in 7 days
Deadline: 2027-09-13 19:59 Beijing Time
```

---

# 27. Notification Protocol

```swift
protocol NotificationScheduling {
    func requestAuthorization() async throws -> Bool

    func schedule(
        _ request: DeadlineNotificationRequest
    ) async throws

    func remove(
        identifier: String
    ) async

    func removeAll(
        for deadlineID: String
    ) async
}
```

Tests must use:

```text
MockNotificationScheduler
```

---

# 28. ViewModel Rules

View models may depend only on:

* repository protocols;
* domain services;
* abstract system capabilities.

Example:

```swift
@MainActor
final class ConferenceManagementViewModel: ObservableObject {
    private let conferenceRepository: ConferenceRepository
    private let trackedRepository: TrackedConferenceRepository
    private let discoveryService: ConferenceDiscoveryService
    private let trackingService: ConferenceTrackingService
}
```

View models must not directly:

* parse YAML;
* call URLSession;
* use UserNotifications;
* implement SwiftData query details;
* implement complex deadline selection rules.

---

# 29. Testing Principles

Use:

```text
XCTest
```

All tests must:

* be repeatable;
* avoid the real network;
* avoid the current system time;
* avoid the developer machine’s timezone;
* avoid the developer machine’s locale;
* avoid real notifications;
* avoid opening a real browser;
* avoid test-order dependencies;
* use `FixedClock`;
* explicitly use `Asia/Shanghai` when needed.

Do not:

* delete failing tests;
* weaken assertions;
* hide required failures with skips;
* wait on real time to test countdowns;
* access production GitHub data from unit tests.

---

# 30. Domain Unit Tests

## 30.1 ConferenceTrackingServiceTests

Cover at least:

1. adding when zero conferences are tracked;
2. allowing the 10th conference when nine are tracked;
3. rejecting the 11th conference when ten are tracked;
4. returning `alreadyTracked` for duplicates;
5. handling conference-not-found;
6. removing a tracked conference;
7. removing a non-tracked conference;
8. adding again after removal;
9. preserving tracking identity after category changes;
10. preserving tracking identity after rank changes.

---

## 30.2 ConferenceDiscoveryServiceTests

Cover at least:

1. Artificial Intelligence filtering;
2. Graphics and Multimedia filtering;
3. HCI filtering;
4. Interdisciplinary filtering;
5. multi-category union;
6. CCF-A;
7. CCF-B;
8. multi-rank union;
9. category-rank intersection;
10. abbreviation search;
11. full-name search;
12. year search;
13. case-insensitive search;
14. leading and trailing whitespace;
15. unknown category;
16. empty query returns all.

---

## 30.3 DeadlineSelectionServiceTests

Cover at least:

1. one future deadline;
2. multiple future deadlines;
3. both abstract and paper deadlines are future;
4. abstract closed but paper still open;
5. supplementary deadline later;
6. shuffled source-array order;
7. all deadlines closed;
8. next edition is TBD;
9. multiple years;
10. later year already closed;
11. earlier year still has a valid deadline;
12. no parseable deadline.

---

## 30.4 TrackedConferenceResolverTests

Cover at least:

1. normal conference;
2. cross-category conference;
3. future deadline resolution;
4. TBD;
5. Closed;
6. Source unavailable;
7. last-known cache fallback;
8. name change;
9. rank change;
10. category change.

---

## 30.5 ConferenceSortingServiceTests

Cover at least:

1. earlier deadline sorts first;
2. cross-category conferences sort together;
3. cross-rank conferences sort together;
4. equal deadline sorts by abbreviation;
5. TBD after future deadlines;
6. Closed after TBD;
7. Unavailable last;
8. added order does not affect sorting;
9. repository order does not affect sorting.

---

## 30.6 DeadlineCalculatorTests

Use the fixed reference time:

```text
2026-06-23T00:00:00Z
```

Cover at least:

1. 100 days;
2. 3 days;
3. 18 hours;
4. 45 minutes;
5. exact current time;
6. past date;
7. nil date;
8. ClosingSoon;
9. Closed;
10. TBD;
11. Beijing Time formatting;
12. fixed locale;
13. fixed timezone.

---

# 31. Data-Layer Tests

## 31.1 ConferenceYAMLParserTests

Fixtures:

```text
sample_normal.yml
sample_multiple_deadlines.yml
sample_aoe.yml
sample_iana_timezone.yml
sample_tbd.yml
sample_closed.yml
sample_unknown_category.yml
sample_invalid.yml
```

Cover at least:

1. normal fields;
2. missing optional fields;
3. multiple years;
4. multiple timeline entries;
5. AoE;
6. IANA timezone;
7. TBD;
8. invalid URL;
9. unknown category;
10. unknown rank;
11. malformed individual record is skipped;
12. malformed root structure returns a clear error.

---

## 31.2 ConferenceCategoryMapperTests

Use real upstream identifiers and cover:

* Artificial Intelligence;
* Computer Graphics and Multimedia;
* Human-Computer Interaction and Ubiquitous Computing;
* Interdisciplinary, Comprehensive, and Emerging Areas;
* unknown category;
* case differences;
* leading and trailing whitespace;
* future newly introduced categories.

---

## 31.3 TimeZoneParserTests

Cover:

* AoE;
* UTC;
* UTC-12;
* `Asia/Shanghai`;
* `America/Los_Angeles`;
* daylight-saving date;
* non-daylight-saving date;
* unknown timezone;
* Beijing Time formatting.

---

## 31.4 TrackedConferenceRepositoryTests

Cover:

1. initial state is empty;
2. add;
3. remove;
4. prevent duplicate persistence;
5. persistence survives repository recreation;
6. store 10 records;
7. repository does not secretly enforce the domain limit;
8. replacing the conference catalog preserves tracked records.

---

# 32. ViewModel Tests

## 32.1 ConferenceManagementViewModelTests

Cover:

1. four categories selected by default;
2. CCF-A selected by default;
3. search;
4. multi-category filtering;
5. multi-rank filtering;
6. add conference;
7. add the 10th conference;
8. reject the 11th conference;
9. duplicate add;
10. remove conference;
11. add capability restored after removal;
12. count display;
13. repository error;
14. unknown category;
15. tracked conferences remain visible in the tracked column even when excluded by the current discovery filter.

---

## 32.2 TrackedConferenceListViewModelTests

Cover:

1. no tracked conferences;
2. normal loading;
3. cross-category deadline sorting;
4. search tracked conferences;
5. search does not mutate underlying data;
6. TBD;
7. Closed;
8. Source unavailable;
9. tracking preserved after sync;
10. tracking preserved after rank change;
11. tracking preserved after category change;
12. remove conference;
13. repository error;
14. cache fallback;
15. correct Beijing Time presentation model.

---

# 33. UI Tests

Cover at least:

1. first launch shows conference selection;
2. CCF-A is selected by default;
3. four category filters are interactive;
4. conference can be added;
5. tracked count updates;
6. 10th conference can be added;
7. 11th conference is blocked;
8. removing one allows another to be added;
9. main list shows only tracked conferences;
10. main list is sorted by deadline;
11. tracked-conference search;
12. opening conference details;
13. opening reminder configuration;
14. `Esc` closes the floating panel.

System-level global shortcut simulation is not required in CI.

`GlobalHotkeyManager` callback behavior must be covered by unit tests.

---

# 34. Accessibility Identifiers

Provide stable identifiers:

```text
topconf.search.tracked
topconf.search.discovery
topconf.tracked.table
topconf.management.available
topconf.management.tracked
topconf.management.count
topconf.filter.category.ai
topconf.filter.category.graphics
topconf.filter.category.hci
topconf.filter.category.interdisciplinary
topconf.filter.rank.a
topconf.filter.rank.b
topconf.filter.rank.c
topconf.add.{conferenceID}
topconf.remove.{conferenceID}
topconf.row.{conferenceID}
topconf.website.{conferenceID}
topconf.reminder.{deadlineID}
topconf.empty.noTracked
topconf.detail
```

UI tests must not rely mainly on display text.

---

# 35. Error Handling

Define:

```swift
enum AppError: LocalizedError {
    case networkUnavailable
    case invalidConferenceData
    case conferenceNotFound
    case trackingLimitReached(maximum: Int)
    case persistenceFailure
    case notificationPermissionDenied
    case unsupportedTimeZone(String)
    case sourceUnavailable
}
```

Production code must not use:

```text
try!
fatalError
uncontrolled force unwraps
```

A malformed individual conference must not make the entire catalog unavailable.

---

# 36. Logging

Use a unified:

```text
AppLogger
```

Log:

* refresh start;
* refresh completion;
* downloaded record count;
* parsed record count;
* skipped record count;
* repository errors;
* notification scheduling result;
* hotkey registration failure;
* cache fallback.

Logs must not contain sensitive user information.

---

# 37. Development Phases

## Phase 0: Project Initialization

Complete:

* macOS Xcode project;
* App target;
* Unit Test target;
* UI Test target;
* macOS 14 minimum;
* shared scheme;
* `.gitignore`;
* README;
* AGENTS.md;
* SOP documents;
* baseline build;
* baseline tests.

Acceptance:

```text
Project builds
Test target runs
Scheme is discoverable through xcodebuild
```

---

## Phase 1: Domain Layer

Complete:

* Domain models;
* Clock;
* TrackingPolicy;
* ConferenceTrackingService;
* ConferenceDiscoveryService;
* DeadlineSelectionService;
* TrackedConferenceResolver;
* ConferenceSortingService;
* DeadlineCalculator;
* SearchService;
* TestSupport;
* Domain tests.

Do not implement:

* UI;
* SwiftData;
* networking;
* notifications;
* Yams;
* NSPanel;
* global hotkeys.

Acceptance:

```text
All Domain tests pass
```

---

## Phase 2: Fixtures and In-Memory Repositories

Complete:

* fixtures;
* `InMemoryConferenceRepository`;
* `InMemoryTrackedConferenceRepository`;
* `InMemoryReminderRepository`;
* fixture-driven tests.

Acceptance:

```text
Domain tests
Fixture tests
In-memory repository tests

All pass
```

---

## Phase 3: SwiftData

Complete:

* SwiftData entities;
* ConferenceRepository implementation;
* TrackedConferenceRepository implementation;
* ReminderRepository implementation;
* in-memory ModelContainer tests;
* repository recreation tests.

Acceptance:

```text
Tracked records survive repository recreation
Replacing the conference catalog preserves tracking relationships
```

---

## Phase 4: Conference Management

Complete:

* onboarding;
* conference discovery list;
* four-category filters;
* CCF rank filters;
* search;
* add;
* remove;
* 10-conference limit;
* ViewModel tests.

Acceptance:

```text
The user can select up to 10 conferences
The 11th conference is rejected
```

---

## Phase 5: Main Deadline Table

Complete:

* TrackedConferenceList;
* compact table;
* deadline sorting;
* remaining time;
* original timezone;
* Beijing Time;
* TBD;
* Closed;
* Source unavailable;
* search;
* details.

Acceptance:

```text
Conferences from different categories are sorted together by nearest deadline
Beijing Time is displayed correctly
```

---

## Phase 6: Menu Bar and Floating Panel

Complete:

* NSPanel;
* `⌥ Space`;
* menu bar;
* active-screen centering;
* Escape handling;
* outside-click closing;
* Dock hiding.

Acceptance:

```text
The global shortcut reliably shows and hides the floating panel
```

---

## Phase 7: Reminders

Complete:

* notification permission;
* ReminderPopover;
* multiple reminders;
* cancellation;
* updates;
* deadline-change rescheduling;
* mock tests;
* Beijing Time notification content.

Acceptance:

```text
No duplicate notifications
No reminders scheduled in the past
```

---

## Phase 8: Remote Synchronization

Complete:

* Yams;
* DTOs;
* parser;
* category mapping;
* GitHub remote source;
* cache;
* background refresh;
* error tolerance;
* upstream missing-data handling.

Acceptance:

```text
The application remains usable offline
Remote updates do not remove tracking configuration
```

---

## Phase 9: UI Tests and Release Preparation

Complete:

* accessibility identifiers;
* UI tests;
* light mode;
* dark mode;
* README updates;
* build command;
* test command;
* final acceptance;
* known limitations.

---

# 38. Agent Workflow

Every phase must follow:

```text
Inspect
→ Plan
→ Implement
→ Focused Tests
→ Full Relevant Tests
→ Diff Review
→ Report
```

Do not:

```text
Generate all features at once
Skip tests
Delete failing tests
Cross phase boundaries
Claim completion without verification
```

---

# 39. Per-Phase Report Format

The agent must report:

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

The agent must report real commands and real results.

---

# 40. Git Safety

Before changes:

```bash
git status --short
git branch --show-current
git log --oneline -5
```

After changes:

```bash
git status --short
git diff --stat
git diff
```

Without explicit user approval, do not run:

```bash
git reset --hard
git clean -fd
git checkout -- .
git restore .
```

Do not independently:

* commit;
* amend;
* rebase;
* squash;
* push.

Do not overwrite existing uncommitted user changes.

---

# 41. README Requirements

The README must include:

* product overview;
* core features;
* four supported categories;
* maximum of 10 tracked conferences;
* Beijing Time;
* AoE;
* IANA timezones;
* architecture;
* technology stack;
* build instructions;
* test instructions;
* implementation phases;
* data-source principles;
* offline strategy;
* notification strategy;
* current limitations.

---

# 42. Final Functional Acceptance

```text
[ ] Application builds
[ ] Application launches
[ ] Menu bar icon exists
[ ] Dock icon is hidden by default
[ ] ⌥ Space shows and hides the panel
[ ] Esc closes the panel
[ ] First launch allows conference selection
[ ] Four target categories are supported
[ ] CCF-A is the default
[ ] Maximum 10 tracked conferences
[ ] 10th conference is accepted
[ ] 11th conference is rejected
[ ] Conferences can be removed and replaced
[ ] Main list shows only tracked conferences
[ ] Cross-category conferences sort together by deadline
[ ] Multiple deadlines are resolved correctly
[ ] AoE conversion is correct
[ ] IANA timezone conversion is correct
[ ] Beijing Time display is correct
[ ] TBD is correct
[ ] Closed is correct
[ ] Source unavailable is correct
[ ] Upstream changes preserve tracking
[ ] Official website opens
[ ] Reminders can be added and removed
[ ] Notifications use Beijing Time
[ ] Cache is available offline
[ ] Light mode works
[ ] Dark mode works
```

---

# 43. Final Test Acceptance

```text
[ ] Domain tests pass
[ ] Fixture tests pass
[ ] Parser tests pass
[ ] Repository tests pass
[ ] Notification tests pass
[ ] ViewModel tests pass
[ ] UI tests pass
[ ] Tests do not use the real network
[ ] Tests do not depend on system time
[ ] Tests do not depend on the developer machine timezone
[ ] Tests do not send real notifications
[ ] Beijing Time tests explicitly use Asia/Shanghai
```

---

# 44. Final Architecture Acceptance

```text
[ ] Domain does not depend on UI frameworks
[ ] Domain does not depend on SwiftData
[ ] Domain does not depend on Yams
[ ] Views do not contain business logic
[ ] ViewModels do not directly use URLSession
[ ] ViewModels do not directly use UserNotifications
[ ] Repositories do not enforce the tracking-limit business rule
[ ] The tracking limit is enforced by a domain service
[ ] Conference and ConferenceEdition are separated
[ ] Stable conference IDs are used
[ ] The data source does not scrape HTML
[ ] No WebView
[ ] No try!
[ ] No fatalError
[ ] No uncontrolled force unwraps
[ ] README is complete
[ ] AGENTS.md is complete
```

---

# 45. First Agent Execution Scope

On the first project entry, execute only:

```text
Phase 0
+
Phase 1
```

If Phase 0 is already complete, execute only Phase 1.

The first execution must:

1. inspect the repository;
2. read `AGENTS.md`;
3. read `README.md`;
4. read both SOP documents;
5. run `xcodebuild -list`;
6. establish the build baseline;
7. establish the test baseline;
8. create domain models;
9. create Clock;
10. create domain services;
11. create TestSupport;
12. create domain tests;
13. run tests;
14. review the diff;
15. report real results.

The first execution must not implement:

* complete SwiftUI features;
* SwiftData;
* Yams;
* remote synchronization;
* notifications;
* NSPanel;
* global hotkeys;
* menu bar functionality.

---

# 46. First Execution Prompt

```text
Read these files completely before modifying anything:

- AGENTS.md
- README.md
- docs/TOPCONF_SOP.md
- docs/CODEX_FIRST_ENTRY_SOP.md

First inspect the repository and establish the build and test baseline.

Then implement Phase 0 and Phase 1 only.

If Phase 0 is already complete, do not recreate the project. Reuse the
existing valid project and implement only the missing Phase 1 components.

Phase 1 scope:

- Domain models
- Clock abstraction
- TrackingPolicy
- ConferenceTrackingService
- ConferenceDiscoveryService
- DeadlineSelectionService
- TrackedConferenceResolver
- ConferenceSortingService
- DeadlineCalculator
- SearchService
- TestSupport
- Domain unit tests

Do not implement:

- full SwiftUI features
- AppKit NSPanel
- global hotkeys
- SwiftData
- YAML parsing
- network synchronization
- UserNotifications
- menu bar functionality

Requirements:

- Users can track at most 10 conferences.
- The 10th conference must be accepted.
- The 11th conference must be rejected.
- Users track conferences, not editions.
- Use stable conference IDs.
- Cross-category conferences must be sorted together by deadline.
- Business logic must use a Clock abstraction.
- Tests must use a fixed clock.
- Default display timezone is Asia/Shanghai.
- Tests must not depend on the real network, local timezone, or locale.
- Do not use try!, fatalError, or uncontrolled force unwraps.
- Do not weaken or delete tests.

After implementation:

1. Run focused Domain tests.
2. Run the complete unit test suite.
3. Review git status and git diff.
4. Fix regressions.
5. Report actual commands, exit codes, test counts, changed files,
   known issues, and deferred work.

Do not claim completion unless all required tests pass.
```

---

# 47. Final Principle

TopConf must follow this principle:

> Users track conferences, not years. The primary interface tracks deadlines, not conference encyclopedia content. Beijing Time is the default display timezone, but the original timezone must always be preserved. Build testable domain rules first, then integrate platform features and remote data.

