# TJ-44F: Frozen source, recovery and stacked-PR integration audit

**Audit date:** 2026-11-09  
**Primary:** `cube23games/Balloon_Burst` (public)  
**Intended private backup:** `cube23games/Balloon_Burst-backup` (not created yet when this document was authored)  
**Accepted QA commit:** `787b13dc35da2dc40c21ba81a18773bfd4c8a0a6`  
**Signed CI:** [build #75, run 42568021366](https://github.com/cube23games/Balloon_Burst/actions/runs/42568021366), status **success**.  
**Planned annotated checkpoint:** `tj44f-spiraling-device-verified`, targeting exactly the accepted QA commit. This is **not a Google Play release tag**.

## Historical origin
`Sinhuej/balloon_burst` is the original development repository, **not** the backup destination. The original commit hashes `b62d29426a886e495d4a135e50c61cd3f97be96f` and `5cd0d42a7e6e17d6144734b3a60ec32c862d5ce6` also exist in `cube23games/Balloon_Burst`. Shared history is confirmed, but this alone does not determine whether clone, fork, or import was used.

## Preflight inventory
Before adding the operations branch: **13 branches, 129 tag refs**. The source default branch is `accuracy-expose-v1`; `main` is the preserved baseline `60267594c9ad90e8e1e32be6d0a8b9c5d0fad7b6`. Adding `ops/tj44-backup-sync` increases the expected branch count to **14**; creating the annotated milestone increases expected tag count to **130**.

The private `cube23games/Scratchless-backup` exists and informed this procedure. It used an isolated bare sync repo, explicit branch/tag pushes, no force-push, no prune and remote-ref parity verification.

## Merge ancestry and target audit
All listed PRs remain **open drafts**, all target `main`, and each stage is a straight **ahead-only** descendant of its predecessor (confirmed using GitHub compare endpoints, zero commits behind for every adjacent pair). Despite being individually mergeable today, they include changes from preceding stages and should not be merged independently or out of sequence.

| Order | PR | Feature | Head commit | Commits ahead of previous stage |
|---:|---:|---|---|---:|
| 1 | #1 | TJ-44A — World 1 foundation | `34116cc1a922` | base |
| 2 | #2 | TJ-44B — playable Levels 1–2 | `5f9b09fa0794` | 19 |
| 3 | #3 | TJ-44C — lead Level 3 | `d9f3393d66cb` | 15 |
| 4 | #5 | TJ-44S — permanent APK signing | `029ef9171571` | 8 |
| 5 | #6 | TJ-44C1 — Endless Main Menu | `26ae0e9564f5` | 7 |
| 6 | #7 | TJ-44D — wind Level 4 | `7f44f76aacc0` | 10 |
| 7 | #8 | TJ-44D2 — wind tuning & telemetry | `220a48fb3775` | 5 |
| 8 | #9 | TJ-44E — ribbon Level 5 | `d00aa256d9a1` | 14 |
| 9 | #10 | TJ-44E1 — flexible ribbon visuals | `a9e646072536` | 8 |
| 10 | #11 | TJ-44F — mixed Level 6 | `787b13dc35da` | 15 |

GitHub issue #4 (Endless Main Menu) is **not a PR**. It remains open pending integration into `main`; the fix already passed Moto G QA in PR #6 and descendants.

## Backup process and acceptance gates
`tools/balloon_burst_safe_backup_sync.sh` on the isolated operations branch is the proposed owner-run Termux action:
1. Validate the active GitHub CLI login is `cube23games`, repository write permission and the exact signed CI #75 commit.
2. Create the backup with `private=true` (or validate the existing repo is private).
3. Fetch all primary branch/tag refs to `~/repo-backups/balloon-burst-safe-sync.git`, explicitly without destructive remote operations.
4. Create and push an **annotated, immutable-by-policy** Level 6 checkpoint tag to the primary, then push branches and tags separately to the private backup **without force**.
5. Compare **every** source/backup branch head and tag object hash (including annotated tag peeled refs); verify the checkpoint peels to the accepted commit on both remotes, and that backup default branch is `main`.
6. Retain the receipt in `~/repo-backups/BALLOON_BURST_BACKUP_VERIFY_*.txt`. No screenshot/password/key material required.

**Current status as documented:** script committed, but **repo creation, tag publication, ref sync and verification have not yet occurred**. An operator must execute the reviewed Termux script and capture successful receipt before reporting backup completed.

## Integration and release gates
After verified private backup:
- Select a controlled integration method (ordered PR merges **or** a carefully reviewed consolidated PR). Record the decision; do not merge all stacked changes independently.
- Run full Flutter tests and permanent-key signed CI on the exact integrated SHA.
- Test the integrated Android QA APK as an install-over-update with preserved coins, stars and unlocks; run Endless Main Menu, Level 6 mixed-hazard, Level 7 gate and performance sanity checks.
- Tag the **integrated** revision separately; never reuse or retarget `tj44f-spiraling-device-verified`.
- Keep signing keystore/password, Actions secrets and APK CI artifacts separately managed; a Git mirror backs up repository refs and objects, not external secrets or artifacts.
- Only then start TJ-44G — Level 7 Leadstorm.

This document makes no claim that unperformed backup or integration steps are complete.
