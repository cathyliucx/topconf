# TopConf

TopConf is a native macOS menu-bar app for tracking academic conference deadlines. It helps researchers discover supported conferences, track up to 10 important venues, and open a compact deadline launcher from anywhere with `Option-Space`.

## Requirements

TopConf requires macOS 14 or later.

## Features

* macOS menu-bar conference deadline tracker
* Calendar-style menu-bar icon
* `Option-Space` floating launcher
* Conference discovery across the supported CCF categories:
  * Artificial Intelligence
  * Computer Graphics and Multimedia
  * Human-Computer Interaction and Ubiquitous Computing
  * Interdisciplinary, Comprehensive, and Emerging Areas
* CCF-A, CCF-B, and CCF-C rank filtering
* Maximum of 10 tracked conferences
* Deadline-first tracked list
* Multi-edition, timezone-aware deadline resolution
* Original deadline and Beijing-time display
* Local reminder scheduling with macOS notifications
* Structured ccfddl synchronization
* Persisted offline catalog fallback
* Light and dark mode support

## Installation

Download `TopConf-1.0.0.dmg` from the GitHub Releases page, open the disk image, and drag `TopConf.app` into Applications.

TopConf is currently signed to run locally by Xcode during release packaging. It is not notarized and is not distributed with a Developer ID signature in this repository state. Depending on your macOS security settings, you may need to approve the first launch in System Settings.

## First Launch

On first launch, TopConf opens conference management so you can choose conferences to track. The default discovery view shows the supported categories with CCF-A selected. Use search, category filters, and A/B/C rank filters to find conferences, then add up to 10 to your tracked list.

Tracked conferences are persisted locally. The catalog is also cached locally so the app can continue to show the last accepted catalog when offline.

## Menu Bar and Keyboard Shortcut

TopConf runs as an accessory menu-bar app and does not show a Dock icon during normal use.

Use the calendar icon in the macOS menu bar to open the app menu. The menu includes actions to show TopConf or quit the app.

Use `Option-Space` to show or hide the floating deadline launcher. The launcher displays tracked conferences sorted by nearest valid deadline, followed by TBD, closed, and unavailable states.

## Reminders

TopConf can schedule local macOS notifications for tracked conference deadlines. macOS notification permission is requested explicitly when needed. If permission is denied, reminder settings remain visible and recoverable, but notifications are not scheduled until permission is granted.

Notification scheduling is local to your Mac. TopConf does not send reminder data to a server.

## Data Source

TopConf uses structured conference data derived from the ccfddl / ccf-deadlines project:

* ccfddl: https://github.com/ccfddl/ccf-deadlines

TopConf preserves upstream identifiers where possible, handles malformed individual records without discarding the whole catalog, and keeps a persisted local fallback after a successful refresh.

## Privacy

TopConf stores preferences, tracked conferences, cached catalog data, and reminder configuration locally on your device. Local notification requests are scheduled through macOS. The app does not require an account and does not upload your tracked conference selections or reminders.

## Development

Build the app:

```bash
xcodebuild build \
  -project TopConf.xcodeproj \
  -scheme TopConf \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData
```

Run the test suite:

```bash
xcodebuild test \
  -project TopConf.xcodeproj \
  -scheme TopConf \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData
```

Build a Release app:

```bash
xcodebuild build \
  -project TopConf.xcodeproj \
  -scheme TopConf \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData
```

## Distribution and Signing

The current project uses automatic local signing with no configured development team. Release artifacts produced from this repository are ad-hoc / local Xcode signed and are not notarized.

Do not claim notarization or Developer ID distribution unless those steps have been configured and verified for a later release.

## License

No license file is currently present in this repository. Until a license is added, redistribution and reuse rights are not explicitly granted.

## Version

### TopConf 1.0.0

Initial public release for macOS 14 or later.
