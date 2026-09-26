# ops/automation — the Phase 0.5 dev loop (SPEC §9)

**An unattended worker implements one backlog item per run and opens a PR; an independent
review pass comments on it; Mark merges. Nothing here ever merges or pushes to `main`.**

| File | Role |
|---|---|
| `worker.sh` | One cron run: pause? → lock → first eligible `BACKLOG.md` item → worktree on `auto/<id>` → claim → headless `claude -p` (≤5 attempts) → exclusion check → gate + DoD → push + PR, or mark `blocked` (no PR) |
| `review.sh` | For each open `auto/*` PR whose head has no graft review: fresh-context, read-only headless review → PR comment with `Verdict: looks-good` / `request-changes` |
| `task-prompt.md` / `review-prompt.md` | Prompt templates (worker / reviewer) |
| `gate.sh` | The single definition of green: typecheck, lint, TS tests, Python tests |
| `dod.sh` | Runs the claimed item's `dod-cmd` (`$GRAFT_DOD_CMD`) — the headless session's one-word self-check |
| `require-tests.sh` | `require-tests.sh "<name>" …` — green only if no TS test failed and each named test exists and passed; used by backlog `dod-cmd`s (a bare `vitest -t` filter that matches nothing proves nothing) |
| `exclusions.txt` | Hard-exclusion paths (SPEC §9 + the automation's own guardrails) |
| `lib.sh` | Shared functions (backlog parsing, exclusions, logging, timeouts) |
| `install-hooks.sh`, `githooks/`, `hooks/` | Commit gating (see Hooks) |
| `install-cron.sh` | Installs / removes the cron block |
| `tests/` | `test-worker.sh`, `test-hooks.sh` — stubbed, offline |
| `fixtures/` | Test backlog; the runaway test's impossible test |
| `pause` (gitignored) | Kill switch flag, managed by `ops/scripts/graft pause` / `graft resume` (see Pause): if present, both scripts log `paused` and exit 0 |

## How the worker chooses and finishes an item

- **Eligible** = first item top-to-bottom with `status: open`, `executor: worker`,
  `phase ≤ current-phase`, every `depends` item `done` on `main`, and no `auto/<id>`
  branch anywhere (the branch is the claim lock). It must also carry a `dod-cmd:` — a
  shell command the worker itself runs; items without one are skipped (logged).
- **Success** requires, in the worktree after the session: no excluded path changed,
  `gate.sh --install` green, and `dod-cmd` exit 0. Then the branch gets `status: done`,
  is pushed, and a PR is opened (body: answer-first summary, DoD, files touched, test
  tail, the item verbatim).
- **Blocked** = iteration cap (5 attempts), run deadline, or an exclusion violation.
  The red/excluded changes are saved to `data/automation/runs/<run>/abandoned.diff` and
  dropped; the branch gets `status: blocked` + reason and a PROGRESS note; it is pushed;
  **no PR**. Mark re-grooms it.
- Everything a run did is in `data/automation/runs/<run-id>/` (prompts, transcripts,
  verify output) and one line per event in `data/automation/runs.log`.

## Budget guard

| Guard | Default | Env |
|---|---|---|
| Attempts per item (iteration cap) | 5 | `WORKER_MAX_ATTEMPTS` |
| Wall clock per headless attempt | 1200 s | `WORKER_CLAUDE_TIMEOUT` |
| Wall clock per run (checked between attempts) | 7200 s | `WORKER_RUN_DEADLINE` |
| Hard kill of the whole cron invocation | 3 h worker / 1 h review | `timeout` in the cron line |
| Review per PR | 900 s | `REVIEW_CLAUDE_TIMEOUT` |
| Concurrency | one worker, one reviewer (`flock`) | — |

`claude -p` exposes no turn cap, so wall-clock time is the budget. Weekly quota review is
Mark's (SPEC §9 guardrails).

## Hooks

Two layers, both committed:

1. **Git pre-commit** (`githooks/pre-commit`, enabled per clone by `install-hooks.sh`,
   which sets `core.hooksPath=ops/automation/githooks`; worktrees share it): runs
   `gate.sh` and **rejects the commit if anything is red**. Applies to humans, the worker
   and the headless session alike. `--no-verify` is denied to the headless session.
2. **Claude Code PostToolUse** (`.claude/settings.json` → `hooks/post-edit.sh`): after
   every Edit/Write in `packages/*` or `sidecars/calibrate`, typechecks and tests the
   owning package and feeds failures back to the session (exit 2) so it fixes them
   before trying to commit.

Verified by `tests/test-hooks.sh` (a type-error commit is rejected, a clean one accepted;
the edit hook reports errors).

## Headless session permissions

`--permission-mode acceptEdits` with an explicit allow-list (read/edit tools, pnpm, tsc,
vitest, eslint, unittest, read-only git, `git add/commit`) and a deny-list (`git push`,
branch/reset/checkout/rebase/merge, `--no-verify`, `gh`, `curl`, `wget`, `ssh`, `sudo`,
WebFetch, WebSearch). Anything not allowed is refused in `-p` mode.

## Schedule

`install-cron.sh` (idempotent; `--remove` to uninstall) installs, in local time:
worker every 30 min 00:00–06:30; review at :15/:45 00:15–07:45. Many short runs, no
daemon. Pause without uninstalling: `ops/scripts/graft pause` (see Pause).

## Pause

**Run `ops/scripts/graft pause` to free the GPU and stop new project activity;
`ops/scripts/graft resume` to restart it.** From Windows, double-click the launchers in
[`ops/windows/`](../windows/README.md).

- **Pause blocks every new run and frees model memory.** It writes the flag file
  `ops/automation/pause` (since / reason / mode), unloads all Ollama models (VRAM and
  RAM) and prints GPU memory before → after. While the flag exists, `worker.sh` and
  `review.sh` log `paused` and exit 0 (cron keeps firing; each run exits immediately),
  and `ops/scripts/dsh` refuses to start with **exit 75**.
- **Soft vs hard only differs for a run already in progress:**

  | Mode | Command | In-flight worker/review run |
  |---|---|---|
  | Soft (default) | `graft pause [--reason "text"]` | Finishes its current attempt, then stops. Headless Claude uses cloud compute, so it costs only local CPU/RAM (builds, tests), not GPU |
  | Hard | `graft pause --hard [--reason "text"]` | Stopped now, cleanly: its claim is released and the item stays `open` |

- **Resume only removes the flag.** Models are not preloaded; Ollama loads one the next
  time Graft asks. The Ollama service itself stays up throughout — idle with no models
  it holds ~0 extra VRAM.
- **Check with `graft status`**: PAUSED/ACTIVE, running runs, loaded models, GPU memory,
  cron schedule. Exit 0 when active, 3 when paused.

A bare `touch ops/automation/pause` still blocks runs, but does not unload models or
record a reason — prefer `graft pause`.

## Known limits

- Parallel worker PRs each append to `PROGRESS.md`, so later PRs may need a trivial
  conflict resolution at merge time.
- The reviewer posts as the same GitHub account as the worker, so its verdict is a
  comment, not a formal "request changes" review.
