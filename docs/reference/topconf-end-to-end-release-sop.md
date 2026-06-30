# TopConf End-to-End Release SOP

This SOP defines the preventive, contract-driven, stage-gated, build-to-release lifecycle for TopConf.

Every section uses the same operating fields: Objective, Prerequisites, Inputs, Actions, Expected outputs, Validation commands, Stop conditions, Evidence to retain.

## 1. Purpose and scope
Objective: Take TopConf from clean development state to verified public release without repair-loop behavior.
Prerequisites: Clean repository, explicit user release request.
Inputs: product requirements, contracts, release version.
Actions: execute only the current stage, stop on failed gates, retain evidence.
Expected outputs: verified app, DMG, tag, GitHub Release, public download verification.
Validation commands: `./scripts/topconf-release-pipeline.sh validate`.
Stop conditions: dirty tree, failed invariant, missing confirmation for merge/tag/publish.
Evidence to retain: all reports under `.build/reports/`.

## 2. Product invariants
Objective: Preserve TopConf product behavior from implementation through release.
Prerequisites: `AGENTS.md`, README, source tests.
Inputs: supported categories, rank policy, tracking limit, deadline rules.
Actions: validate contracts in `topconf-release-contracts.md`.
Expected outputs: product behavior is represented by tests and gates.
Validation commands: `./scripts/topconf-release-pipeline.sh validate`.
Stop conditions: missing required category, exposed Unranked filter, stale tracked rows, invalid deadline behavior.
Evidence to retain: stage validation report.

## 3. Supported environment
Objective: Verify local machine can build, package, and optionally publish.
Prerequisites: macOS, Xcode, Git.
Inputs: Xcode path, project, Homebrew/gh availability.
Actions: run doctor in local or publication mode.
Expected outputs: environment report.
Validation commands: `./scripts/topconf-doctor.sh`; publication: `./scripts/topconf-doctor.sh --mode publication`.
Stop conditions: missing Xcode/project/Git; missing `gh` or auth in publication mode.
Evidence to retain: `environment-report.txt`.

## 4. Repository layout
Objective: Confirm expected project files exist.
Prerequisites: repository root.
Inputs: `TopConf.xcodeproj`, `TopConf/`, tests, docs, assets.
Actions: inspect file list and project.
Expected outputs: layout matches native macOS app.
Validation commands: `find . -maxdepth 3 -type f | sort`; `xcodebuild -list -project TopConf.xcodeproj`.
Stop conditions: missing target, scheme, source, tests, or release docs.
Evidence to retain: environment report and terminal output.

## 5. Branch strategy
Objective: Keep development and release branches deterministic.
Prerequisites: `dev`, `main`, `origin`.
Inputs: branch graph and remotes.
Actions: develop on `dev`; merge to `main` using normal merge commits; never force-push.
Expected outputs: `dev` pushed, `main` pushed, release tag on final `main`.
Validation commands: `git branch -vv`; `git rev-list --left-right --count dev...origin/dev`; same for main.
Stop conditions: unexpected divergence, dirty tree, missing remote.
Evidence to retain: `git-release-report.txt`.

## 6. Versioning strategy
Objective: Ensure app metadata, docs, tag, DMG, and GitHub Release use one semver.
Prerequisites: selected version and build number.
Inputs: `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`, README, release notes.
Actions: update metadata and docs before release build.
Expected outputs: version metadata matches requested release.
Validation commands: `./scripts/topconf-prepare-version.sh --version <version> --build-number <build>`.
Stop conditions: stale version references, wrong build number, mismatched bundle metadata.
Evidence to retain: `version-report.txt`.

## 7. Implementation dependency graph
Objective: Preserve intended architecture.
Prerequisites: source tree.
Inputs: App, Domain, Data, Features, Notifications, Shared.
Actions: keep Domain independent; inject concrete dependencies from App.
Expected outputs: no forbidden framework imports in Domain.
Validation commands: `./scripts/topconf-validate-stage.sh --stage domain`; `--stage integration`.
Stop conditions: Domain imports UI/persistence/network/notification frameworks.
Evidence to retain: stage validation report.

## 8. Domain model
Objective: Keep tracking, sorting, searching, countdown, and deadline rules pure.
Prerequisites: domain tests.
Inputs: conference, edition, deadline, tracked conference models.
Actions: enforce tracking limit in domain service and deadline selection in domain service.
Expected outputs: deterministic domain behavior with fixed clocks.
Validation commands: `./scripts/topconf-validate-stage.sh --stage domain`.
Stop conditions: direct wall-clock use in business logic, scattered tracking limit.
Evidence to retain: stage validation report.

## 9. Catalog ingestion
Objective: Ingest structured upstream data safely.
Prerequisites: Yams package and remote source policy.
Inputs: ccfddl YAML records.
Actions: parse array-root and dictionary-root YAML; isolate malformed records.
Expected outputs: accepted catalog or explicit rejection.
Validation commands: `./scripts/topconf-validate-stage.sh --stage parser`; `--stage catalog`.
Stop conditions: malformed root accepted incorrectly, whole batch lost due one bad record.
Evidence to retain: parser/catalog validation evidence.

## 10. Category policy
Objective: Load exactly supported categories and report unsupported ones.
Prerequisites: category mapper.
Inputs: AI, CG, HI, MX source directories.
Actions: preserve upstream category ID; exclude unsupported KDD/DB without Emerging fallback.
Expected outputs: supported catalog coverage and unsupported diagnostics.
Validation commands: `./scripts/topconf-validate-stage.sh --stage catalog`.
Stop conditions: missing supported directory, fallback category mapping.
Evidence to retain: catalog report.

## 11. Rank policy
Objective: Expose only supported user rank filters.
Prerequisites: parser and management UI.
Inputs: upstream CCF rank data.
Actions: parse A/B/C; handle missing/unsupported as unknown data states; show only A/B/C filters.
Expected outputs: no visible Unranked filter.
Validation commands: `./scripts/topconf-validate-stage.sh --stage parser`; `--stage ui`.
Stop conditions: visible Unranked button or parser crash on missing rank.
Evidence to retain: UI and parser evidence.

## 12. Timezone and deadline model
Objective: Preserve exact deadline semantics.
Prerequisites: timezone parser and deadline service.
Inputs: AoE, UTC, offsets, PT, IANA identifiers.
Actions: reject invalid timezones; select nearest valid future deadline; render Beijing time.
Expected outputs: deterministic deadline display and sorting.
Validation commands: `./scripts/topconf-validate-stage.sh --stage timezone`; `--stage domain`.
Stop conditions: silent timezone fallback, source-order dependent deadline selection.
Evidence to retain: timezone/domain reports.

## 13. Persistence model
Objective: Persist catalogs, tracked conferences, and reminders without embedding business policy.
Prerequisites: SwiftData repositories.
Inputs: entities and repository protocols.
Actions: keep repositories consistent and policy decisions in services/composition.
Expected outputs: reproducible persistence with in-memory test containers.
Validation commands: `./scripts/topconf-validate-stage.sh --stage persistence`.
Stop conditions: duplicate tracked rows, destructive catalog replacement.
Evidence to retain: persistence report.

## 14. Reconciliation lifecycle
Objective: Remove definitive orphan tracked rows only when safe.
Prerequisites: accepted catalog outcome.
Inputs: tracked rows, accepted catalog IDs, refresh state.
Actions: after complete accepted refresh or accepted persisted startup catalog, delete absent tracked IDs.
Expected outputs: orphans do not render or count.
Validation commands: `./scripts/topconf-validate-stage.sh --stage reconciliation`.
Stop conditions: cleanup on failed/rejected/partial/cache/seed path; valid TBD conference removed.
Evidence to retain: reconciliation report.

## 15. Reminder lifecycle
Objective: Keep notification state synchronized with tracked state.
Prerequisites: notification abstraction.
Inputs: reminder rules, deadline IDs, offsets.
Actions: use deterministic IDs; cancel reminders for removed orphans; never schedule in tests.
Expected outputs: no duplicate or stale pending notifications.
Validation commands: `./scripts/topconf-validate-stage.sh --stage reminders`.
Stop conditions: real notifications in tests, nondeterministic identifiers.
Evidence to retain: reminder report.

## 16. Application composition root
Objective: Build concrete dependencies in one production root.
Prerequisites: App layer.
Inputs: repositories, sync, notification scheduler, clocks.
Actions: inject protocols into features; isolate test launch arguments.
Expected outputs: production bootstrap starts at 0/10 tracked and refreshes safely.
Validation commands: `./scripts/topconf-validate-stage.sh --stage integration`.
Stop conditions: test fixture leaking into production, duplicate app roots.
Evidence to retain: integration report.

## 17. View-model publication order
Objective: Publish only reconciled, resolvable tracked rows.
Prerequisites: accepted catalog and repository state.
Inputs: tracked list and catalog repository.
Actions: reconcile before publication; do not create placeholders for missing IDs.
Expected outputs: no `Source unavailable` orphan rows.
Validation commands: `./scripts/topconf-validate-stage.sh --stage viewmodels`.
Stop conditions: unresolved tracked ID renders or counts.
Evidence to retain: view-model report.

## 18. Onboarding and management UI
Objective: Keep discovery useful and rank policy visible.
Prerequisites: management view models and UI tests.
Inputs: search query, category filters, rank filters.
Actions: route onboarding to management/discovery; expose A/B/C only.
Expected outputs: users can search, filter, and track up to 10.
Validation commands: `./scripts/topconf-validate-stage.sh --stage ui`.
Stop conditions: missing supported filter, Unranked visible, search regression.
Evidence to retain: UI report.

## 19. Menu-bar launcher
Objective: Preserve native accessory menu-bar behavior.
Prerequisites: AppKit launcher implementation.
Inputs: NSStatusItem, NSPanel, global hotkey.
Actions: use template calendar image; no visible title; keep accessibility, menu, hotkey, Dock hidden.
Expected outputs: calendar menu-bar item and launcher behavior.
Validation commands: `./scripts/topconf-validate-stage.sh --stage launcher`.
Stop conditions: visible text title, non-template image, broken Show/Quit/hotkey.
Evidence to retain: launcher report.

## 20. Asset pipeline
Objective: Ensure app and menu-bar icons compile into Release app.
Prerequisites: asset catalog.
Inputs: AppIcon PNGs/vector source, MenuBarCalendar template image.
Actions: keep source vector files and generated catalog variants.
Expected outputs: `AppIcon.icns`, `Assets.car` with `MenuBarCalendar` template.
Validation commands: `./scripts/topconf-validate-stage.sh --stage assets`; `xcrun assetutil --info <Assets.car>`.
Stop conditions: missing assets or old icon references.
Evidence to retain: asset report.

## 21. Test strategy
Objective: Run focused gates before broad integration.
Prerequisites: Xcode and tests.
Inputs: unit, UI, app-composition, parser, repository tests.
Actions: run focused stage tests, then shared-scheme tests before release.
Expected outputs: tests pass without network/notifications/browser side effects.
Validation commands: `xcodebuild test -project TopConf.xcodeproj -scheme TopConf -destination 'platform=macOS' -derivedDataPath .build/DerivedData`.
Stop conditions: failing required test, skipped required test, real external side effect.
Evidence to retain: build/test logs.

## 22. Development acceptance gates
Objective: Stop invalid implementation before release prep.
Prerequisites: completed feature work.
Inputs: stage contracts.
Actions: run `validate`; inspect diff.
Expected outputs: all development gates pass.
Validation commands: `./scripts/topconf-release-pipeline.sh validate`; `git diff --check`.
Stop conditions: failed contract or unrelated changes.
Evidence to retain: validation reports.

## 23. Release preparation
Objective: Prepare a clean release candidate.
Prerequisites: development gates passed.
Inputs: semver, build number, release notes.
Actions: update metadata/docs; verify tree and release artifacts plan.
Expected outputs: releasable candidate on dev.
Validation commands: `./scripts/topconf-release-pipeline.sh prepare --version <version> --build-number <build>`.
Stop conditions: stale docs, false claims, wrong metadata.
Evidence to retain: version and docs reports.

## 24. Version metadata update
Objective: Align Xcode metadata.
Prerequisites: selected semver.
Inputs: `project.pbxproj`.
Actions: set marketing version and build number for app/test configs as needed.
Expected outputs: bundle metadata resolves to release version.
Validation commands: `./scripts/topconf-prepare-version.sh --version <version> --build-number <build>`.
Stop conditions: mismatched app Info.plist after build.
Evidence to retain: version report.

## 25. README update
Objective: Add public release docs without deleting project context.
Prerequisites: existing README.
Inputs: release version, distribution status.
Actions: preserve original README; add installation, privacy, distribution, version sections.
Expected outputs: accurate public docs.
Validation commands: `./scripts/topconf-prepare-docs.sh --version <version>`.
Stop conditions: replacing useful docs, false notarization claim.
Evidence to retain: docs report and diff.

## 26. Release notes preparation
Objective: Provide concise GitHub Release notes.
Prerequisites: version and changelog knowledge.
Inputs: `RELEASE_NOTES.md`.
Actions: state highlights, macOS requirement, signing/notarization limitations.
Expected outputs: notes file suitable for `gh release create --notes-file`.
Validation commands: `./scripts/topconf-prepare-docs.sh --version <version>`.
Stop conditions: missing notes or inaccurate distribution claims.
Evidence to retain: docs report.

## 27. Git release flow
Objective: Move release from dev to main safely.
Prerequisites: clean tree and pushed dev.
Inputs: `dev`, `main`, `origin`.
Actions: fetch, check divergence, merge with normal merge commit, push main.
Expected outputs: final main release commit.
Validation commands: `./scripts/topconf-merge-release.sh --confirm-merge`.
Stop conditions: missing confirmation, divergence, merge conflict.
Evidence to retain: git report and log.

## 28. Release build
Objective: Produce Release app from final release source.
Prerequisites: release metadata/docs complete.
Inputs: Xcode project and package graph.
Actions: clean DerivedData if requested; build Release.
Expected outputs: `.build/DerivedData/Build/Products/Release/TopConf.app`.
Validation commands: `./scripts/topconf-build.sh --configuration Release --clean`.
Stop conditions: build failure, package resolution failure, missing app bundle.
Evidence to retain: `build-report.txt`.

## 29. App bundle verification
Objective: Verify built app before packaging.
Prerequisites: Release app exists.
Inputs: app bundle.
Actions: inspect Info.plist, AppIcon, compiled assets, signature, launch.
Expected outputs: verified app bundle.
Validation commands: `codesign --verify --deep --strict --verbose=2 <app>`; `plutil -p <Info.plist>`.
Stop conditions: wrong version, missing icon, signature failure, launch failure.
Evidence to retain: build/package reports.

## 30. DMG packaging
Objective: Create installable disk image.
Prerequisites: verified Release app.
Inputs: app path, version, output dir.
Actions: stage app and Applications symlink; create UDZO DMG.
Expected outputs: `dist/TopConf-<version>.dmg`.
Validation commands: `./scripts/topconf-package-dmg.sh --version <version>`.
Stop conditions: missing app, missing symlink, hdiutil failure.
Evidence to retain: package report.

## 31. DMG and SHA verification
Objective: Prove artifact integrity before publishing.
Prerequisites: DMG and SHA sidecar.
Inputs: local artifacts.
Actions: verify SHA, hdiutil, mounted contents, mounted app signature.
Expected outputs: verified local artifacts.
Validation commands: `./scripts/topconf-verify-artifact.sh --version <version>`.
Stop conditions: SHA mismatch, DMG invalid, mounted app invalid.
Evidence to retain: package report and SHA file.

## 32. Tag creation
Objective: Mark the final main release commit.
Prerequisites: final main pushed and artifacts verified.
Inputs: version and main HEAD.
Actions: create annotated `v<version>` tag; push tag.
Expected outputs: tag points to final main.
Validation commands: `./scripts/topconf-create-tag.sh --version <version> --confirm-tag`.
Stop conditions: existing tag, wrong branch, missing confirmation.
Evidence to retain: `tag-report.txt`.

## 33. Git push verification
Objective: Confirm remotes match intended state.
Prerequisites: dev/main/tag pushed.
Inputs: branch and tag refs.
Actions: compare local and remote refs.
Expected outputs: no divergence.
Validation commands: `git branch -vv`; `git ls-remote --tags origin v<version>`.
Stop conditions: remote missing branch/tag or unexpected divergence.
Evidence to retain: git report.

## 34. GitHub CLI setup
Objective: Ensure publication tooling is ready.
Prerequisites: GitHub release requested.
Inputs: `gh`, auth state.
Actions: verify `gh` exists and is authenticated; never expose credentials.
Expected outputs: publication-capable environment.
Validation commands: `./scripts/topconf-doctor.sh --mode publication`.
Stop conditions: missing `gh`, unauthenticated `gh`.
Evidence to retain: environment report.

## 35. GitHub Release publication
Objective: Publish release assets.
Prerequisites: tag pushed, local artifacts verified, publication requested.
Inputs: DMG, SHA, release notes.
Actions: `gh release create` with tag verification; upload both assets.
Expected outputs: public release page with assets.
Validation commands: `./scripts/topconf-publish-release.sh --version <version> --confirm-publish`.
Stop conditions: missing confirmation, existing release without permission, upload failure.
Evidence to retain: publication report.

## 36. Public asset download verification
Objective: Verify public assets, not only local artifacts.
Prerequisites: GitHub Release exists.
Inputs: public release assets.
Actions: download to temp directory; verify SHA, DMG, mounted app metadata/signature.
Expected outputs: public verification report.
Validation commands: `./scripts/topconf-verify-public-release.sh --version <version>`.
Stop conditions: asset missing, SHA mismatch, DMG/signature failure.
Evidence to retain: public verification report.

## 37. Final acceptance checklist
Objective: Decide whether release is complete.
Prerequisites: all gates passed.
Inputs: reports, commits, tag, URL, artifacts.
Actions: confirm clean tree, branch push, tag target, release URL, public verification.
Expected outputs: final release report.
Validation commands: `git status --short`; `./scripts/topconf-release-pipeline.sh verify-public --version <version>`.
Stop conditions: any missing evidence.
Evidence to retain: `final-release-report.txt`.

## 38. Rollback procedure
Objective: Respond safely to a bad release.
Prerequisites: published release issue identified.
Inputs: affected tag/release/assets.
Actions: do not rewrite public history by default; mark release notes, publish patch, or withdraw release only with explicit user instruction.
Expected outputs: documented mitigation.
Validation commands: `gh release view v<version>`.
Stop conditions: request would force-push or rewrite tag without explicit approval.
Evidence to retain: incident notes.

## 39. Patch release procedure
Objective: Ship compatible fixes.
Prerequisites: verified defect and patch version.
Inputs: current main, dev fix branch or dev branch.
Actions: implement minimal fix, run all gates, bump patch version, release through full pipeline.
Expected outputs: `vX.Y.Z+1` patch release.
Validation commands: `./scripts/topconf-release-pipeline.sh full-release --version <patch> --build-number <n> --confirm-merge --confirm-tag --confirm-publish`.
Stop conditions: broad feature work or failed gates.
Evidence to retain: all reports.

## 40. Minor release procedure
Objective: Ship new compatible functionality.
Prerequisites: scoped product requirements and tests.
Inputs: new version, updated docs/contracts.
Actions: update contracts, implement, validate, bump minor version, release through full pipeline.
Expected outputs: `vX.Y.0` release.
Validation commands: full release pipeline.
Stop conditions: contract gaps, missing docs, failed public verification.
Evidence to retain: reports and updated contracts.

## 41. Historical failures encoded as preventive rules
Objective: Ensure known defects cannot recur.
Prerequisites: historical failure list.
Inputs: `topconf-preventive-rules.md`.
Actions: convert each failure into invariant, implementation location, test, and release gate.
Expected outputs: preventive rules are part of validation, not runtime repair.
Validation commands: `./scripts/topconf-release-pipeline.sh validate`.
Stop conditions: missing rule for known failure or unenforced rule.
Evidence to retain: preventive rules document and stage reports.
