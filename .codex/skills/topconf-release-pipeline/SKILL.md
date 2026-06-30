# topconf-release-pipeline

## Purpose

Implement, validate, package, version, merge, tag, publish, and publicly verify TopConf releases using the canonical preventive SOP.

This is an end-to-end, preventive, contract-driven, stage-gated, build-to-release, publicly verified lifecycle skill. It is not a source-code repair loop.

## Activation Conditions

Use this skill when the user asks to:

* build TopConf;
* rebuild TopConf;
* reproduce TopConf;
* validate TopConf;
* prepare a release;
* update a version;
* package a DMG;
* merge dev into main;
* create a release tag;
* publish a GitHub Release;
* verify a published release;
* perform the entire TopConf release workflow.

## Required Execution Model

```text
READ SOP
→ READ BLUEPRINT
→ INSPECT CURRENT STATE
→ IDENTIFY CURRENT STAGE
→ EXECUTE ONLY THE CURRENT STAGE
→ RUN ITS GATES
→ RECORD EVIDENCE
→ ADVANCE
```

Before acting, read completely:

* `docs/reference/topconf-end-to-end-release-sop.md`
* `docs/reference/topconf-release-blueprint.md`
* `docs/reference/topconf-release-contracts.md`
* `docs/reference/topconf-preventive-rules.md`

## Core Rules

* The SOP is the source of truth.
* Historical fixes are preventive implementation constraints.
* Do not reproduce known incorrect approaches.
* Do not perform speculative source repair.
* Do not automatically mutate source code after failures.
* Do not continue after a failed gate.
* Do not publish from a dirty working tree.
* Do not force push.
* Do not rewrite a published tag.
* Do not tag before version metadata, documentation, build, and packaging are complete.
* Do not merge if `dev` and `main` have unexpected divergence.
* Do not claim notarization or Developer ID signing unless verified.
* Do not publish if DMG verification or SHA verification fails.
* Do not publish unless the user explicitly requests publication.
* Do not expose tokens, device codes, private keys, or credentials.
* Do not overwrite an existing GitHub Release without explicit permission.

## Stage Commands

Use the canonical entry point whenever possible:

```bash
./scripts/topconf-release-pipeline.sh validate
./scripts/topconf-release-pipeline.sh prepare --version 1.1.0 --build-number 2
./scripts/topconf-release-pipeline.sh build --configuration Release --clean
./scripts/topconf-release-pipeline.sh package --version 1.1.0
./scripts/topconf-release-pipeline.sh release-check --version 1.1.0
./scripts/topconf-release-pipeline.sh merge --version 1.1.0 --confirm-merge
./scripts/topconf-release-pipeline.sh tag --version 1.1.0 --confirm-tag
./scripts/topconf-release-pipeline.sh publish --version 1.1.0 --confirm-publish
./scripts/topconf-release-pipeline.sh verify-public --version 1.1.0
```

Full release requires explicit destructive-publication confirmations:

```bash
./scripts/topconf-release-pipeline.sh full-release \
  --version 1.1.0 \
  --build-number 2 \
  --confirm-merge \
  --confirm-tag \
  --confirm-publish
```

## Required Stage Report

After each stage report:

```text
Stage
Status
Files changed
Commands run
Contracts satisfied
Artifacts created
Evidence
Next stage
```

## Evidence

Generated reports belong under:

```text
.build/reports/
```

Do not include secrets in reports.
