# Session 1 kickoff prompt (Phase 0 — Sandbox & scaffold)

Open Claude Code **in WSL2 Ubuntu at `~/graft`** (`/home/mark/graft`; from Windows,
`\\wsl.localhost\Ubuntu\home\mark\graft`) and paste everything below the line.

The folder is **not empty** — it already holds `CLAUDE.md`, `README.md`, `SPEC.md`,
`RISK-REGISTER.md`, `SESSION-1-PROMPT.md`, `SESSION-2-PROMPT.md`,
`graft-starter-v0.2.zip`, and `.claude/skills/minto-pyramid/`. Everything else in
the layout is yours to create.

Environment verified 2026-09-25 — do not re-derive it, but re-check anything you are
about to depend on, and record what you actually observe:

| Fact | Value |
|---|---|
| Workspace | `~/graft` on WSL ext4 (940 GB free). `/mnt/c` is at 95% — keep nothing large there |
| WSL | Ubuntu, WSL 2.6.3.0, systemd **enabled**, default user `mark` |
| Node / Python / git | v22.23.1 (LTS) · 3.14.4 with working `python3 -m venv` · present |
| GPU | RTX 4060 Ti, 8188 MiB, driver 591.86, visible to WSL via `nvidia-smi` |
| Present | `corepack`, `curl` |
| Missing | `pnpm` (via corepack), **Ollama — not installed, nothing on :11434**, `gh` |
| dsh on npm | `@deepseek-ai/dsh` exists — dist-tags on 2026-09-25: latest `0.1.5-rc.3`, next `0.1.7-rc.2`, alpha `0.1.7-alpha.2` |

---

We are initialising **Graft**. `CLAUDE.md` in this folder is your standing context —
read it first, then `SPEC.md` in full (it moves into `docs/` in task 2). This session
is **Phase 0 only** (SPEC §8): prerequisites, sandbox, scaffold, pins, smoke tests.
Do not build Phase 0.5 or Phase 1 components beyond empty package skeletons.

Use parallel subagents where SPEC §10 marks work safe to parallelise; serialise
everything it marks serial (git, installs, VERSIONS.md, environment changes).

## Tasks

1. **Prerequisites (serial — before anything else).**
   - `corepack enable` to provide pnpm; record the version it activates.
   - **Install Ollama inside WSL** — not on Windows; the workspace and its 940 GB
     live here. The official installer pipes a shell script from the network and
     registers a systemd service, so **ask Mark before running it** (CLAUDE.md
     boundary: no network beyond localhost model endpoints without approval).
     Afterwards confirm the service is up, `curl http://localhost:11434/api/tags`
     answers, and the model store sits on ext4 (`~/.ollama`), **never** under
     `/mnt/c`.
   - `gh` is absent. Phase 0 does not need it — note it as a Phase 0.5 prerequisite
     instead of installing it now.
   - Stop and report if any prerequisite fails. Never work around a missing
     prerequisite by changing what Phase 0 delivers.

2. **Repo init (serial).** `git init`; conventional commits; pnpm workspace; Python
   venv for `sidecars/calibrate`; `.gitignore` covering `data/`, venvs,
   `node_modules`. Move `SPEC.md` and `RISK-REGISTER.md` into `docs/`. Commit the
   starting files first, then delete `graft-starter-v0.2.zip` in its own commit — it
   is a byte-identical duplicate of the root markdown files, kept only until git
   history exists.

3. **dsh install & pin (serial).** Install `@deepseek-ai/dsh` into this workspace
   only. It is pre-1.0 and RC-tagged: **pin one exact version** — start with the
   `latest` tag unless it fails, and say so if you choose otherwise — never a range
   or a dist-tag. Record in `ops/VERSIONS.md`: exact version, the dist-tags you
   observe today, install method, Node version. Review dsh's safety notices and note
   any sandbox-relevant default you changed. Keep all dsh config under `ops/`,
   committed.

4. **Model verification (serial — VRAM/disk contention).** With Ollama up, pull the
   SPEC §5 models. **Verify each tag exists before pulling**; tags move, and the SPEC
   names are intent rather than gospel — substitute per SPEC §5 intent (doer = 8–9B
   Qwen text-only Q4_K_M; judge = small non-Qwen, decorrelated family; embeddings =
   small Qwen), recording every substitution with its reason. Record exact tags **and
   digests** in `ops/VERSIONS.md`.

   Smoke-test each and report numbers: one doer generation (tokens/sec); one
   grammar-constrained JSON output from the judge **with logprobs captured**; one
   embedding call. Confirm the doer is fully GPU-resident on the 8188 MiB card with
   no spill, and the judge runs on CPU. **A doer under ~25 tok/s means VRAM spill
   (RISK-REGISTER #10) — report it rather than proceeding quietly.** Sequence models
   via `keep_alive`/unload; never co-resident.

5. **Scaffold (parallel-safe per package).** Create the layout from CLAUDE.md:
   `packages/core`, `packages/plugins/{graft-trust,graft-judge,graft-ledger}` (router
   deferred), `sidecars/calibrate` (calibration + graft-stats), `skills/`,
   `canaries/`, `ops/`, `docs/decisions/`. TypeScript strict everywhere (apply the
   strict-typescript-mode skill); each package gets a README stating its
   responsibility and its may/never rules from SPEC §3. `packages/core` gets the
   ledger schema (SPEC §3.3) as a typed module plus a SQLite migration; plugins are
   compilable stubs that log mount/unmount only.

6. **Frozen replay preset (serial — dsh config).** Duplicate dsh's Minimal preset
   into `ops/presets/graft-replay/`, pin its model to the doer, commit it. This
   preset must never drift; state that rule in its README.

7. **dsh smoke test (serial).** One Standard-mode toy task (e.g. "create hello.md
   with today's date") against the local doer through dsh headless. Confirm the
   session log captures the run; note the session store location in
   `ops/VERSIONS.md`.

8. **Skill Tree prior-art note (parallel-safe, READ-ONLY — nothing is imported).**
   Source: `/mnt/c/Users/Mark/Desktop/Solo Dev Projects/skill-tree/`. **Never write
   there, and never copy anything out of it into this repo** — not skills, canaries,
   code, configs, prompts, schemas or dashboards. Skill Tree is the failed first
   iteration of this project's ethos: it could not evidence skill improvement
   statistically, and its artefacts may carry the assumptions that caused that. It is
   reference material, not a parts bin. See CLAUDE.md, "Skill Tree — reference only".

   Deliverable: `docs/prior-art-skill-tree.md`, written in Graft's own terms — what
   was attempted, where the evidence chain broke, which design choices in SPEC exist
   because of it (independent judge, pre-registered statistics, deterministic
   canaries), and the pitfalls already paid for. Quote sparingly for analysis;
   reproduce no files. Its corpus (11 `*.skill.yaml`, 5 `claude-code/*.md`, 2
   `.claude/skills/` entries) is **not** Graft's seed — Graft's skills are authored
   fresh in Phase 1 or grown from its own verified episodes.

9. **Backlog seed (parallel-safe).** Create `BACKLOG.md` from SPEC §8–9: the Phase
   0.5 tasks (worker script, review-agent workflow, cron entry, runaway test) and the
   Phase 1 tasks, each small with a machine-checkable definition of done. Include
   `gh` installation as an explicit Phase 0.5 prerequisite item.

   Two things the backlog must get right, because both were wrong in earlier drafts:
   - **Phase 1 seeds 3 hand-authored skills**, at least 2 of them kata-facing.
     Nothing is imported from anywhere (task 8).
   - **The second task domain is undecided** (SPEC §7). Seed one backlog item for
     *choosing* it — score candidates against §7's criteria, write an ADR, decide
     before P3 entry — and **no items that assume any particular domain**. If you
     find a domain named as decided anywhere in the docs, treat that as a defect and
     flag it at close-out.

   Create `PROGRESS.md` with the read-first/write-last convention stated at the top.
   Copy `ops/stats.yaml` from SPEC §4.3 as the initial pre-registered statistics
   config and commit it **standalone**.

10. **Update CLAUDE.md (serial).** It currently describes a pre-Phase-0 tree and says
    so explicitly. Replace its **Current state** section with reality, and its
    **Commands** section with the real invocations you just established: install,
    typecheck, test-all, test-one-package, test-one-file, and the Python sidecar
    equivalents. These are the commands the Phase 0.5 hooks and worker loop execute,
    so a wrong one here breaks automation rather than merely annoying a human.

11. **Close-out (serial).** ADR-0001 in `docs/decisions/`: "Build on dsh, pinned,
    thin shims", with the alternatives considered. Clean commit history. Then report,
    applying the **minto-pyramid** skill (`.claude/skills/minto-pyramid/`): the Phase
    0 exit-criteria checklist from SPEC §8 with each item ticked or explicitly not;
    pins recorded; smoke tests with their numbers; every deviation from SPEC and why.
    Lead with whatever failed or is unticked.

## Boundaries for this session

- Nothing employer-related; no credentials anywhere in the workspace.
- Network use is limited to the Ollama installer (task 1, with approval), the npm
  registry, and `localhost:11434`. Anything else needs Mark's approval first.
- Write only inside `~/graft`. The Skill Tree step reads from `/mnt/c` and writes
  solely `docs/prior-art-skill-tree.md` — no copied artefacts, here or ever.
- No dsh plugins mounted into live config beyond stubs.
- If dsh diverges from what SPEC assumes (it is a pre-1.0 preview), prefer what you
  verify locally, record the divergence in `ops/VERSIONS.md`, and flag it at
  close-out rather than improvising silently.
