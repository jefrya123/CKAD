---
phase: 07-testing-ci-distribution-docs
plan: 02
subsystem: distribution
tags: [install, bash, curl-pipe-sh, shellcheck, kind, yq, jq, bats]

requires:
  - phase: 07-testing-ci-distribution-docs-01
    provides: unit test infrastructure (bats-core, test/unit/)

provides:
  - curl-pipe-sh install script (scripts/install.sh) for end users
  - dev-setup.sh with Fedora/RHEL support and version summary

affects:
  - users trying to install ckad-drill on a fresh machine
  - contributors setting up the dev environment

tech-stack:
  added: []
  patterns:
    - "OS/arch detection via uname for cross-platform binary downloads"
    - "Prefer ~/.local/bin over /usr/local/bin — no sudo for user tools"
    - "Idempotent install: git pull on existing clone, skip installed deps"

key-files:
  created:
    - scripts/install.sh
  modified:
    - scripts/dev-setup.sh

key-decisions:
  - "Use ~/.local/share/ckad-drill for repo clone, symlink to ~/.local/bin/ckad-drill"
  - "kind v0.25.0, yq v4.44.6, jq 1.7.1 pinned in install.sh for reproducibility"
  - "dnf fallback added before npm for bats-core on Fedora/RHEL"
  - "Version summary printed at end of dev-setup.sh including bats-helper git SHA"

requirements-completed: [DIST-01, DIST-02]

duration: 2min
completed: 2026-03-01
---

# Phase 7 Plan 02: Distribution Scripts Summary

**curl-pipe-sh install.sh with OS/arch detection for Linux+macOS, pinned kind/yq/jq versions, no-sudo install to ~/.local/bin; dev-setup.sh extended with dnf support and version summary**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-03-01T03:37:38Z
- **Completed:** 2026-03-01T03:39:02Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Created scripts/install.sh: full curl-pipe-sh installer with bash version check, Docker/kubectl preflight, optional kind/yq/jq install to ~/.local/bin, repo clone + symlink, color output when terminal attached
- Updated scripts/dev-setup.sh: added dnf (Fedora/RHEL) fallback for bats-core and shellcheck, added installed-versions summary at end showing tool versions and bats-helper git commit hashes
- Both scripts pass shellcheck with zero warnings

## Task Commits

Each task was committed atomically:

1. **Task 1: Create install.sh for curl-pipe-sh installation** - `a39d50d` (feat)
2. **Task 2: Audit and update dev-setup.sh** - `7c0a3b8` (chore)

**Plan metadata:** `(pending final commit)`

## Files Created/Modified

- `scripts/install.sh` - User-facing install script: detects OS/arch, checks Docker+kubectl, installs kind/yq/jq if missing, clones repo, creates symlink
- `scripts/dev-setup.sh` - Developer setup: added dnf support for Fedora/RHEL, added version summary with bats-helper SHA fingerprints

## Decisions Made

- `~/.local/share/ckad-drill` as install location (configurable via CKAD_DRILL_HOME env var)
- Pinned exact versions: kind v0.25.0, yq v4.44.6, jq 1.7.1 — reproducible for users
- dnf fallback added before npm in dev-setup.sh (apt-get first, then dnf, then npm, then git clone as last resort)
- `GITHUB_REPO` variable at top of install.sh for easy customization when repo is published

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- DIST-01 and DIST-02 requirements satisfied
- install.sh will need GITHUB_REPO updated once repo is published to GitHub
- Both scripts ready for CI/CD integration or manual distribution

---
*Phase: 07-testing-ci-distribution-docs*
*Completed: 2026-03-01*
