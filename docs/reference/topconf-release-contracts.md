# TopConf Release Contracts

These contracts define release-blocking implementation and delivery invariants for TopConf. They are preventive: a failed contract stops the workflow and is reported as evidence, not silently repaired.

| Contract | Lifecycle stage | Owner | Implementation rule | Validation command | Severity | Release blocking |
| --- | --- | --- | --- | --- | --- | --- |
| CATALOG-001 | Catalog ingestion | Data | Upstream array-root YAML parses successfully; dictionary-root remains supported. | `./scripts/topconf-validate-stage.sh --stage parser` | Critical | Yes |
| CATALOG-002 | Catalog ingestion | Data | AI, CG, HI, and MX directories are loaded explicitly. | `./scripts/topconf-validate-stage.sh --stage catalog` | Critical | Yes |
| CATALOG-003 | Category policy | Data | Unsupported KDD/DB records are excluded and reported; they must not fall back to Emerging. | `./scripts/topconf-validate-stage.sh --stage parser` | Critical | Yes |
| CATALOG-004 | Catalog ingestion | Data | Malformed individual records do not invalidate an otherwise usable supported batch. | `./scripts/topconf-validate-stage.sh --stage catalog` | High | Yes |
| RANK-001 | Rank policy | Features/Data | Visible rank filters are exactly CCF-A, CCF-B, and CCF-C. | `./scripts/topconf-validate-stage.sh --stage ui` | Critical | Yes |
| RANK-002 | Rank policy | Data | Missing and unsupported upstream ranks parse safely as non-exposed unknown data-layer states. | `./scripts/topconf-validate-stage.sh --stage parser` | High | Yes |
| TIME-001 | Timezone model | Data | AoE uses UTC-12 semantics. | `./scripts/topconf-validate-stage.sh --stage timezone` | Critical | Yes |
| TIME-002 | Timezone model | Data | UTC, UTC offsets, PT aliases, and IANA identifiers parse deterministically. | `./scripts/topconf-validate-stage.sh --stage timezone` | Critical | Yes |
| TIME-003 | Timezone model | Data | Invalid timezone identifiers are rejected; no silent fallback is allowed. | `./scripts/topconf-validate-stage.sh --stage timezone` | Critical | Yes |
| DEADLINE-001 | Domain model | Domain | Multi-edition deadline selection chooses the nearest valid future deadline independent of source order. | `./scripts/topconf-validate-stage.sh --stage domain` | Critical | Yes |
| DEADLINE-002 | Domain model | Domain | TBD and no-deadline states remain valid presentation states and do not remove tracked conferences. | `./scripts/topconf-validate-stage.sh --stage viewmodels` | High | Yes |
| TIME-004 | Domain model | Domain | Production uses `SystemClock`; tests use fixed clocks. | `./scripts/topconf-validate-stage.sh --stage domain` | High | Yes |
| TRACK-001 | Reconciliation | App/Data | Fresh production bootstrap starts with zero tracked conferences. | `./scripts/topconf-validate-stage.sh --stage integration` | Critical | Yes |
| TRACK-002 | Reconciliation | App/Data | Orphan tracked conferences do not render or consume slots after accepted reconciliation. | `./scripts/topconf-validate-stage.sh --stage reconciliation` | Critical | Yes |
| TRACK-003 | Reconciliation | App/Data | Orphan cleanup runs only after a complete accepted catalog refresh or accepted persisted catalog startup reconciliation. | `./scripts/topconf-validate-stage.sh --stage reconciliation` | Critical | Yes |
| TRACK-004 | Reconciliation | App/Data | Failed, rejected, seed, and cache-only paths are non-destructive. | `./scripts/topconf-validate-stage.sh --stage reconciliation` | Critical | Yes |
| REMINDER-001 | Reminder lifecycle | Notifications/App | Removed orphan tracked conferences cancel reminder rules and pending notifications. | `./scripts/topconf-validate-stage.sh --stage reminders` | Critical | Yes |
| BOOT-001 | View-model publication | App/Features | Reconciliation completes before tracked view models publish rows. | `./scripts/topconf-validate-stage.sh --stage integration` | Critical | Yes |
| UI-001 | Onboarding/UI | Features | Onboarding routes directly to searchable conference management. | `./scripts/topconf-validate-stage.sh --stage ui` | High | Yes |
| UI-002 | Menu bar | App | Status item displays a template calendar image and no visible title. | `./scripts/topconf-validate-stage.sh --stage launcher` | High | Yes |
| UI-003 | Menu bar | App | Accessibility label, tooltip, hotkey, Show, Quit, accessory mode, and hidden Dock behavior are preserved. | `./scripts/topconf-validate-stage.sh --stage launcher` | High | Yes |
| ASSET-001 | Asset pipeline | App | AppIcon and MenuBarCalendar assets exist and compile into the Release bundle. | `./scripts/topconf-validate-stage.sh --stage assets` | High | Yes |
| VERSION-001 | Version preparation | Release | App bundle version matches the release version. | `./scripts/topconf-prepare-version.sh --version 1.0.0 --build-number 1` | Critical | Yes |
| DOCS-001 | Release preparation | Release | README and release notes accurately state signing and notarization status. | `./scripts/topconf-prepare-docs.sh --version 1.0.0` | Critical | Yes |
| BUILD-001 | Release build | Release | Release build succeeds from the shared scheme. | `./scripts/topconf-release-pipeline.sh build --configuration Release --clean` | Critical | Yes |
| PACKAGE-001 | Packaging | Release | DMG contains `TopConf.app` and `Applications` symlink. | `./scripts/topconf-package-dmg.sh --version 1.0.0` | Critical | Yes |
| SIGN-001 | Packaging | Release | Built app and mounted DMG app pass `codesign --verify --deep --strict`. | `./scripts/topconf-verify-artifact.sh --version 1.0.0` | Critical | Yes |
| HASH-001 | Packaging | Release | Local DMG matches its SHA-256 sidecar. | `./scripts/topconf-verify-artifact.sh --version 1.0.0` | Critical | Yes |
| GIT-001 | Git gate | Release | Release tag points to the final `main` commit. | `./scripts/topconf-git-release-check.sh --version 1.0.0` | Critical | Yes |
| GIT-002 | Git gate | Release | `dev`, `main`, and remotes have no unexpected divergence before merge/tag/publish. | `./scripts/topconf-git-release-check.sh --version 1.0.0` | Critical | Yes |
| RELEASE-001 | Publication | Release | GitHub Release contains expected tag, title, DMG, and SHA sidecar. | `./scripts/topconf-publish-release.sh --version <version> --confirm-publish` | Critical | Yes |
| PUBLIC-001 | Public verification | Release | Publicly downloaded DMG matches the SHA sidecar and verifies with `hdiutil`. | `./scripts/topconf-verify-public-release.sh --version <version>` | Critical | Yes |
| PUBLIC-002 | Public verification | Release | Publicly downloaded mounted app has correct version metadata and signature integrity. | `./scripts/topconf-verify-public-release.sh --version <version>` | Critical | Yes |
