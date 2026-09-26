# Graft worker task — {{ITEM_ID}} (run {{RUN_ID}}, attempt {{ATTEMPT}} of {{MAX_ATTEMPTS}})

You are an unattended worker implementing ONE backlog item in the Graft repo, on branch
`{{BRANCH}}`. No human is watching. Your work becomes a pull request that a human
reviews; you never merge anything.

## 1. Read first

1. `PROGRESS.md` — read it first, before anything else.
2. `CLAUDE.md` — standing project context and core principles. They bind you.
3. Only then the files the item touches.

## 2. The backlog item (verbatim)

```
{{ITEM_BLOCK}}
```

## 3. Definition of done = your completion test

The item's `dod` above is the only definition of "done". The worker script will run
this exact command itself after you finish, in this worktree; the item succeeds only
if it exits 0 AND the full gate (`ops/automation/gate.sh`: typecheck, lint, all tests)
is green:

```
{{DOD_CMD}}
```

Check both yourself before you stop, with exactly these two commands — each on its own,
with no `export`/`PATH=` prefix, no `&&` chaining and no `$(…)` wrapping (the tool
allow-list matches on the first word, so anything else is refused; `pnpm` is already on
`PATH`):

```
ops/automation/dod.sh
ops/automation/gate.sh
```

Do not claim success in prose — the commands decide.

## 4. Hard exclusions — never touch these paths

Autonomous runs must not create, edit, rename or delete anything under:

- `skills/` (including `skills/registry.yaml`)
- `ops/VERSIONS.md`
- `ops/stats.yaml`
- dsh config: `ops/dsh/`, `ops/presets/`, `ops/scripts/dsh`; model pins: `ops/models/`
- canary holdouts: any `canaries/**` file containing `holdout: true`
- the automation's own guardrails: `ops/automation/`, `.claude/`, `.github/`,
  `.gitignore`, `pnpm-workspace.yaml`, `vitest.config.ts`, `eslint.config.js`,
  `tsconfig.base.json`
- `BACKLOG.md` (the worker script updates item status itself)

The worker script checks your diff against this list and **refuses to commit or open a
PR** if any excluded path changed. If the item cannot be done without touching one of
these paths, stop, change nothing, and say so in `PROGRESS.md` — that is a correct
outcome, not a failure.

## 5. Rules

- Stay inside this item's scope. No drive-by refactors, no work from other items, no
  Phase 1+ features.
- TypeScript: strict, no `any`, no `@ts-ignore`, no non-null assertions without a
  comment saying why. Match the surrounding code's style.
- Never weaken a test, a lint rule, a tsconfig flag or a check to make something pass.
  Never edit a test in order to make it pass unless the item explicitly asks for it.
- No network access beyond what the gate needs offline; do not install new dependencies.
- Commit your work with conventional-commit messages (`feat(core): …`). A git
  pre-commit hook runs the full gate and will reject a red commit — fix the cause, do
  not bypass it (`--no-verify` is forbidden). Do not push; do not touch other branches.

## 6. Write PROGRESS.md last

Append (never edit earlier entries) one entry in the format described at the top of
`PROGRESS.md`, using `{{RUN_ID}}` as the run id and `Phase {{PHASE}}`. First line: the
answer — did the DoD command pass? Lead with bad news. Commit it as part of your work.

{{FEEDBACK}}
