# TopConf Release Blueprint

This is the concise Codex execution blueprint for the preventive, contract-driven TopConf release pipeline.

## Stage 00 — Environment readiness
Inputs: repository path, Xcode, Git, optional GitHub CLI.
Files involved: `TopConf.xcodeproj`, `.git`, scripts.
Commands: `./scripts/topconf-doctor.sh`.
Expected outputs: `environment-report.txt`.
Required tests: none.
Blocking failures: missing Xcode, project, Git, or publication tooling in publication mode.
Advance criteria: doctor completes.

## Stage 01 — Repository inspection
Inputs: current checkout.
Files involved: all tracked files, `.git`.
Commands: `git status`, `git branch -vv`, `git remote -v`, `git log --all --graph --decorate --oneline`.
Expected outputs: clean-state evidence.
Required tests: none.
Blocking failures: dirty tree, wrong branch, unexpected divergence.
Advance criteria: release branch strategy is understood.

## Stage 02 — Product contract verification
Inputs: product contracts.
Files involved: `docs/reference/topconf-release-contracts.md`.
Commands: `./scripts/topconf-release-pipeline.sh validate`.
Expected outputs: `stage-validation-report.txt`.
Required tests: stage validations.
Blocking failures: any failed contract.
Advance criteria: all contracts pass.

## Stage 03 — Domain and parser verification
Inputs: domain services and parser.
Files involved: `TopConf/Domain`, `TopConf/Data/Remote`, matching tests.
Commands: `./scripts/topconf-validate-stage.sh --stage domain`, `--stage parser`.
Expected outputs: parser/domain gate evidence.
Required tests: domain and parser tests.
Blocking failures: array-root, rank, category, or domain invariant failure.
Advance criteria: gates pass.

## Stage 04 — Timezone verification
Inputs: upstream deadline timezone data.
Files involved: parser and timezone tests.
Commands: `./scripts/topconf-validate-stage.sh --stage timezone`.
Expected outputs: timezone gate evidence.
Required tests: AoE, UTC, offsets, PT, IANA, invalid timezone tests.
Blocking failures: silent fallback or invalid timezone acceptance.
Advance criteria: timezone gate passes.

## Stage 05 — Catalog verification
Inputs: supported source directories.
Files involved: remote source, category mapper, parser tests.
Commands: `./scripts/topconf-validate-stage.sh --stage catalog`.
Expected outputs: catalog gate evidence.
Required tests: AI, CG, HI, MX loading and unsupported KDD behavior.
Blocking failures: incomplete supported category loading or fallback to Emerging.
Advance criteria: catalog gate passes.

## Stage 06 — Persistence and reconciliation verification
Inputs: accepted catalog, tracked rows, reminder state.
Files involved: repositories, synchronizer, dependency container, app-composition tests.
Commands: `./scripts/topconf-validate-stage.sh --stage persistence`, `--stage reconciliation`, `--stage reminders`.
Expected outputs: persistence/reconciliation/reminder evidence.
Required tests: repository tests, orphan cleanup tests, reminder cancellation tests.
Blocking failures: destructive cleanup on failed/cache/seed paths or orphan rows rendering/counting.
Advance criteria: gates pass.

## Stage 07 — UI verification
Inputs: view models and SwiftUI views.
Files involved: `TopConf/Features`, UI tests.
Commands: `./scripts/topconf-validate-stage.sh --stage viewmodels`, `--stage ui`.
Expected outputs: UI evidence.
Required tests: view-model and UI tests.
Blocking failures: Unranked visible, lost supported filters, stale orphan rows.
Advance criteria: UI gates pass.

## Stage 08 — Launcher and asset verification
Inputs: app/menu-bar assets and launcher code.
Files involved: `TopConf/App/Launcher`, `TopConf/Assets.xcassets`.
Commands: `./scripts/topconf-validate-stage.sh --stage launcher`, `--stage assets`.
Expected outputs: launcher/asset evidence.
Required tests: launcher panel tests, asset tests.
Blocking failures: visible menu-bar title, non-template image, missing icon assets.
Advance criteria: gates pass.

## Stage 09 — Integration validation
Inputs: composed app dependencies.
Files involved: `DependencyContainer`, `AppRootView`, integration tests.
Commands: `./scripts/topconf-validate-stage.sh --stage integration`.
Expected outputs: integration evidence.
Required tests: app-composition tests.
Blocking failures: incorrect bootstrap, publication before reconciliation.
Advance criteria: integration gate passes.

## Stage 10 — Version preparation
Inputs: semver and build number.
Files involved: Xcode project metadata.
Commands: `./scripts/topconf-prepare-version.sh --version <version> --build-number <build>`.
Expected outputs: `version-report.txt`.
Required tests: metadata inspection.
Blocking failures: version/build mismatch, minimum macOS mismatch, bundle ID mismatch.
Advance criteria: version gate passes.

## Stage 11 — Documentation preparation
Inputs: release version and distribution status.
Files involved: `README.md`, `RELEASE_NOTES.md`.
Commands: `./scripts/topconf-prepare-docs.sh --version <version>`.
Expected outputs: docs evidence.
Required tests: docs grep checks.
Blocking failures: false notarization/signing claim or missing release info.
Advance criteria: docs gate passes.

## Stage 12 — Git release preparation
Inputs: branch state and metadata.
Files involved: `.git`, release docs, project.
Commands: `./scripts/topconf-git-release-check.sh --version <version>`.
Expected outputs: `git-release-report.txt`.
Required tests: divergence and tag checks.
Blocking failures: dirty tree, branch divergence, conflicting tag/release.
Advance criteria: Git gate passes.

## Stage 13 — Release build
Inputs: clean release checkout.
Files involved: Xcode project, package graph, sources.
Commands: `./scripts/topconf-build.sh --configuration Release --clean`.
Expected outputs: `build-report.txt`, Release app.
Required tests: build succeeds.
Blocking failures: compile, signing, package resolution, asset warning that breaks bundle.
Advance criteria: Release app exists.

## Stage 14 — DMG packaging
Inputs: Release app.
Files involved: `dist/`, Release app.
Commands: `./scripts/topconf-package-dmg.sh --version <version>`.
Expected outputs: DMG and SHA sidecar.
Required tests: package verification.
Blocking failures: missing app, signature failure, malformed DMG.
Advance criteria: package script completes.

## Stage 15 — Release artifact verification
Inputs: DMG and SHA sidecar.
Files involved: `dist/TopConf-<version>.dmg`, `.sha256`.
Commands: `./scripts/topconf-verify-artifact.sh --version <version>`.
Expected outputs: artifact evidence.
Required tests: SHA, hdiutil, mounted app signature and metadata.
Blocking failures: any mismatch.
Advance criteria: artifact gate passes.

## Stage 16 — Merge and push
Inputs: confirmed dev release branch.
Files involved: Git branches.
Commands: `./scripts/topconf-merge-release.sh --confirm-merge`.
Expected outputs: pushed main merge commit.
Required tests: Git divergence checks.
Blocking failures: missing confirmation, dirty tree, divergence, merge conflict.
Advance criteria: main is pushed.

## Stage 17 — Tagging
Inputs: final main commit.
Files involved: Git tag namespace.
Commands: `./scripts/topconf-create-tag.sh --version <version> --confirm-tag`.
Expected outputs: annotated tag pushed.
Required tests: tag points to final main.
Blocking failures: missing confirmation, existing tag, wrong branch.
Advance criteria: tag is pushed.

## Stage 18 — GitHub publication
Inputs: pushed tag, verified artifacts, release notes.
Files involved: `dist/`, `RELEASE_NOTES.md`.
Commands: `./scripts/topconf-publish-release.sh --version <version> --confirm-publish`.
Expected outputs: GitHub Release with DMG and SHA.
Required tests: gh release metadata.
Blocking failures: missing `gh`, auth failure, existing release without permission.
Advance criteria: release view shows assets.

## Stage 19 — Public download verification
Inputs: public GitHub Release.
Files involved: downloaded temp assets.
Commands: `./scripts/topconf-verify-public-release.sh --version <version>`.
Expected outputs: `public-verification-report.txt`.
Required tests: public SHA, DMG, mounted app metadata, signature.
Blocking failures: asset missing, SHA mismatch, DMG/signature failure.
Advance criteria: public gate passes.

## Stage 20 — Final release report
Inputs: all retained reports.
Files involved: `.build/reports`.
Commands: `./scripts/topconf-release-pipeline.sh full-release ...`.
Expected outputs: `final-release-report.txt`.
Required tests: all previous gates.
Blocking failures: missing evidence.
Advance criteria: final report records release URL, tag, commits, artifacts, and warnings.
