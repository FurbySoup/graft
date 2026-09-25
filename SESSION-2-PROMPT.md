# Session 2 kickoff prompt (Phase 0.5 — Dev automation loop)

Open Claude Code in WSL2 at `~/graft` and paste everything below the line — only
after the Phase 0 exit checklist in `docs/SPEC.md` §8 is fully ticked.

Environment verified 2026-09-25:

| Fact | Value |
|---|---|
| cron | installed and `active` — SPEC §9's scheduling assumption holds. systemd is also enabled, but stay on cron unless you record why not |
| `claude` CLI in WSL | 2.1.204 — the `claude -p` worker invocation works |
| `gh` in WSL | **missing.** Authenticated on the Windows side only (account `FurbySoup`, scopes `gist, read:org, repo, workflow`). WSL needs its own install and auth before tasks 1, 3 and 5 |
| GitHub remote | **Phase 0 creates a local repo only.** Create the remote and push `main` before attempting branch protection |

Two prerequisites, done first and reported if they fail: install and authenticate
`gh` inside WSL, and create/push the GitHub remote. Branch protection on a private
repo may need a paid plan — verify before relying on it, and if it is unavailable,
record the deviation and say plainly that the CI check is advisory rather than
enforced, instead of quietly proceeding as though `main` were protected.

---

We're building **Phase 0.5**: the backlog-driven worker loop from SPEC §9, so
that from this point on most implementation, testing, and results analysis runs
unattended, with Mark grooming the backlog and reviewing PRs. Read `CLAUDE.md`
and SPEC §8–10 first. Build nothing from Phase 1.

## Tasks

1. **Worker script (serial).** `ops/automation/worker.sh` (WSL2 bash):
   - Reads the top unclaimed item from `BACKLOG.md`; marks it claimed.
   - Creates a branch `auto/<item-id>`, then invokes Claude Code headless
     (`claude -p`) with `ops/automation/task-prompt.md` — a template that
     includes: the backlog item verbatim, the instruction to read `PROGRESS.md`
     first and append to it last, the hard-exclusion path list from SPEC §9, and
     the definition-of-done as the completion test.
   - Iteration cap: at most 5 fix cycles on failing checks, then stop, label the
     item `blocked`, and leave notes in `PROGRESS.md`.
   - On green checks: push branch, open a PR (gh CLI) whose body contains the
     backlog item, test output summary, and files touched. **Never merge.**
   - Per-run budget guard: hard wall-clock timeout; log start/end and exit
     status to `data/automation/runs.log` (gitignored).

2. **Commit gating hooks (serial).** Claude Code hook config in the repo so that
   after file edits, typecheck + tests for the touched package run automatically;
   configure so commits on red are rejected. Record the hook setup in
   `ops/automation/README.md`.

3. **Review agent (serial).** `ops/automation/review.sh`: for each open `auto/*`
   PR without a review comment, run a headless review pass — fresh context,
   review-specific prompt (`ops/automation/review-prompt.md`), no access to the
   worker's transcript — posting findings as a PR comment with a
   request-changes / looks-good verdict. Advisory only; merging stays human.

4. **Scheduling (serial).** Cron entries (document in `ops/automation/README.md`,
   include an install script): worker overnight on a repeating short cadence
   (many short runs, no always-on daemon), review pass following it. Include an
   easy on/off switch (`ops/automation/pause` flag file the scripts respect).

5. **Branch protection (serial).** Protect `main` on the GitHub repo (FurbySoup):
   PRs required, at least the CI check green. Add a minimal GitHub Actions
   workflow running typecheck + tests on PRs so the green-check requirement has
   teeth even outside the local hooks.

6. **Runaway test (serial — this is the Phase 0.5 exit test).** Add a
   deliberately impossible backlog item (e.g. "make this failing tautology test
   pass without editing the test"). Run the worker against it and verify: it
   stops at the iteration cap, marks the item `blocked`, opens no PR, and the
   run log shows a clean exit.

7. **Live test (serial).** Two trivial real backlog items (e.g. "add a typed
   config loader to packages/core with tests", "add ledger schema migration
   test") run end-to-end unattended: branch → green tests → PR → review comment.
   Mark merges by hand.

8. **Close-out.** Update `PROGRESS.md` and print: the Phase 0.5 exit-criteria
   checklist from SPEC §8 ticked or not, cron schedule installed, budget guard
   values chosen, and anything that deviated from SPEC §9.

## Boundaries for this session

- The worker's hard exclusions are non-negotiable and must be enforced in the
  task prompt template AND checked in the worker script (refuse to commit if
  the diff touches an excluded path): `skills/`, `skills/registry.yaml`,
  `ops/VERSIONS.md`, `ops/stats.yaml`, dsh config, canary holdouts.
- No autonomous merging anywhere, including "temporarily for testing".
- Nothing employer-related; no credentials; everything stays inside this repo.
