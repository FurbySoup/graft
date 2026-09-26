# VERSIONS — every pin Graft depends on

**Human-owned** (SPEC §9 hard exclusion). Recorded 2026-09-25, Session 1 / Phase 0.
Change only through deliberate, standalone commits; a changed pin triggers a
RISK-REGISTER review.

## Host

| Item | Observed |
|---|---|
| OS | Ubuntu 26.04 LTS on WSL 2.6.3.0 (kernel 6.6.87.2-microsoft-standard-WSL2), systemd enabled |
| Workspace | `/home/mark/graft`, ext4 (`/dev/sdf`, ~937 GB free). `/mnt/c` at 95% — nothing stored there |
| GPU | RTX 4060 Ti, 8188 MiB, driver 591.86 (CUDA 13.1). **~1.4–1.8 GB is held by Windows before any model loads** |
| Nested repo note | `/home/mark` is itself a git repo with an allow-list `.gitignore` (`/*`); `graft/` is ignored by it, so this repo is independent |

## Toolchain

| Item | Version | Install method |
|---|---|---|
| Node | v22.23.1 (LTS) | system (`/usr/bin/node`) |
| pnpm | 12.6.0 | corepack 0.34.6, **user-level** shims: `corepack enable --install-directory ~/.local/bin pnpm` (system prefix not writable). `packageManager: pnpm@12.6.0` in `package.json` |
| TypeScript | 6.0.3 | workspace devDep, exact. TS 7.0.2 is `latest` but typescript-eslint 8.70.1 supports `<6.1` |
| vitest | 5.0.2 | workspace devDep, exact. pnpm 12's minimum-release-age policy auto-excluded vitest 5.0.2 / @vitest/{mocker,spy} (see `pnpm-workspace.yaml`) |
| eslint / typescript-eslint | 10.11.0 / 8.70.1 | workspace devDep, exact |
| @types/node | 22.20.4 | workspace devDep, exact (matches Node 22) |
| Python | 3.14.4 | system; venv at `sidecars/calibrate/.venv`, **no third-party packages** (PyPI not approved) |
| git | 2.53.0 | system |
| gh | **absent** | Phase 0.5 prerequisite (BACKLOG) |

## dsh (DeepSeek Harness)

| Item | Value |
|---|---|
| Package | `@deepseek-ai/dsh` **0.1.5-rc.3**, exact (`--save-exact`), root devDependency |
| Why this version | The `latest` dist-tag on 2026-09-25; installed and booted without issue, so `next` was not tried |
| Dist-tags observed 2026-09-25 | `latest` 0.1.5-rc.3 · `next` 0.1.7-rc.2 · `alpha` 0.1.7-alpha.2 |
| Transitive pinning | dsh's own `@deepseek-ai/*` deps use `^0.1.5-rc.3` ranges → **the committed `pnpm-lock.yaml` is the real pin**; always `pnpm install --frozen-lockfile`. Bundled Cordis: `@deepseek-ai/cordis` 4.0.2 (plugins pin the same) |
| Install scripts allowed | `@deepseek-ai/dsh-subprocess-local` (chmods node-pty helper), `node-pty` (linux-x64 prebuild), `koffi` (local prebuild). Denied: `@google/genai` (no-op), `protobufjs` (version warning). Reviewed 2026-09-25 |
| Entry point | `ops/scripts/dsh` only — sets `DSH_HOME=ops/dsh/home`, `DSH_TELEMETRY_DISABLED=1`, `DSH_TELEMETRY_MODE=DISABLED`, `GRAFT_REPO_ROOT`, `GRAFT_OLLAMA_KEY` |
| Session store | `data/dsh-sessions/<workspace-slug>/session-<uuid>/session.v3.jsonl.zstd` (zstd JSONL; stdlib `compression.zstd` reads it). Replay profile: `data/dsh-sessions/replay/` |
| Profiles | `graft` (Standard ≈ dsh-base + dsh-headless) at `ops/dsh/home/profiles/graft/`; `graft-replay` (frozen) at `ops/presets/graft-replay/`, symlinked into `ops/dsh/home/profiles/` |

### Divergences from SPEC (flagged at close-out)

1. **Presets → profiles.** dsh 0.1.5-rc.3 has no "Minimal/Standard presets". Standard ≈
   profile `graft`. Minimal ≈ `graft-replay`, inlined verbatim from the shipped
   `sdk-minimal` tree — an SDK/JSON-RPC surface (model chosen by the client), **not** a
   one-shot CLI and **without** dsh's skills plugin. Phase 2's replay driver must be an
   SDK client, and skill injection there is graft-trust's job.
2. **Upstream minimal is `danger-full-access`;** graft-replay runs `workspace-write`.

### Defaults changed (and why)

| Row / setting | Shipped default | Graft | Reason |
|---|---|---|---|
| `session-telemetry-otel` | `FEEDBACK_ONLY` → `https://harness-telemetry.deepseeksvc.com/v1/logs` | disabled (row + env) | No network beyond localhost (CLAUDE.md boundary; approved 2026-09-25) |
| `web`, `web-search-deepseek`, `web-fetch-http`, `tool-web` | enabled; fetch without per-call approval | disabled | SPEC §7 bans live-web; no network |
| `session-log-deepseek`, `plugin-package-inventory-deepseek` | mounted (enrich official DeepSeek API requests; session-log upload) | disabled | No upload path |
| `llm-deepseek` (+ `deepseek-llm-api-extensions` in replay) | mounted; default model `deepseek-official/deepseek-flash` | disabled | No cloud model at runtime |
| `session-title-llm` | LLM titles each session | disabled | Every model request in a log should be task work |
| `agent-instructions` | injects CLAUDE.md / AGENTS.md found walking up from the workspace | **disabled** | Observed injecting Graft's own CLAUDE.md (~4K tokens) into the doer's context, which then ignored the task. Ambient instructions are an uncontrolled episode variable |
| `agent-default-model` | `deepseek-official` / `deepseek-flash` | `ollama-local` / `graft-doer:8k` | Local doer |
| `llm-pi-ai` | dormant | one route `ollama-local` → `http://localhost:11434/v1`, `openai-completions`, `apiKeyEnv: GRAFT_OLLAMA_KEY` | pi-ai refuses keyless routes (`No API key for provider`); the key is a fixed non-secret placeholder — Ollama on localhost has no auth |
| `session-persistence-jsonl` root | `$DSH_HOME/sessions` | `data/dsh-sessions` (gitignored) | Durable data out of the config tree |
| Model-facing tools (19 rows: `tool-jobs`, `tool-skill`, `goal`, `goal-round-driver`, `command-goal`, `tool-goal`, `tool-ralph`, `plan-mode`, `subagent`, `subagent-spawn-in-process`, `subagent-fork-in-process`, `tool-subagent-control`, `tool-subagent-list-agents`, `tool-subagent`, `tool-subagent-fork`, `workflow-worker-thread`, `tool-workflow`, `tool-todo`, `attachment-local`) | mounted: 23 tools | **disabled**: 6 tools remain (`bash`, `read`, `write`, `edit`, `glob`, `grep`) | R-01 context budget — see *Doer context budget* below. `tool-skill` is also context control: skills reach the doer only via graft-trust |
| sandbox / approval | `workspace-write` + `ask` | unchanged | Kept; the headless smoke completed under it |

### Profile hashes (drift check — `sha256sum`)

```
a9bd8127d91367249b6ce66ca6bf32c3e5196fe0f279234e3f240e5419916505  ops/presets/graft-replay/package.json
03d68ba5b34db6d4da4fe1b370f8f6174b684a200edd965490b87626fe56fc0e  ops/presets/graft-replay/cordis.patch.yml
c300dcf2ebc5f02062d6591268d29d3db6fe45e0cb138f5467276fe2ba06076e  ops/presets/graft-replay/cordis.yml
6cca69e1a228ede0e039a12b1cd3475fbf4d1ec6efe2647da2579286fc44c98f  ops/dsh/home/profiles/graft/cordis.patch.yml
47c6e11dc493f6016ba9b30ebf421821288db1e7348f0035f7b11d9aac86e974  ops/models/graft-doer.Modelfile
9a30e540c2894331c255ea5c039ec2ed3068a3271fd89a188ce69ebc5d7b8555  ops/models/graft-judge.Modelfile
3f800c832fff9a235e2c7968d06fd27488817c7c8f09b1b6dd6a62ca5b623ce5  ops/models/graft-embed.Modelfile
```

## Ollama

| Item | Value |
|---|---|
| Version | 0.34.4 (official `install.sh`, sha256 `25f64b810b947145095956533e1bdf56eacea2673c55a7e586be4515fc882c9f`, run by Mark with sudo; `zstd` apt-installed first) |
| Service | systemd `ollama.service`, user `ollama`, `/usr/local/bin/ollama`, `http://localhost:11434` |
| Model store | `/usr/share/ollama/.ollama` (ext4 root fs — **not** `~/.ollama` as the session prompt said, and never `/mnt/c`). The installer's default; left as-is |

## Models

| Role | Tag | Digest (`/api/tags`) | Details |
|---|---|---|---|
| **Doer** | `graft-doer:8k` | `54b8706e8f301806ed02a6b77414e3d81ed6cd0084d0615e1fba242065877aff` | `ops/models/graft-doer.Modelfile`: `FROM qwen3:8b` + `num_ctx 8192` |
| Doer base | `qwen3:8b` | `500a1f067a9f782620b40bee6f7b0c89e17ae61f686b92c24933e4ca4b2b8b41` | qwen3, 8.2B, Q4_K_M, text-only (5.23 GB blob) |
| Judge v1 | `phi4-mini:latest` | `78fad5d182a7c33065e153a5f8ba210754207ba9d91973f57dffa7f487363753` | phi3 family, 3.8B, Q4_K_M — decorrelated from Qwen |
| Embeddings | `qwen3-embedding:0.6b` | `ac6da0dfba84a81fdbfbaf330198c33cd77c4cdfc53e8bc50eb581914a15621d` | 596M, Q8_0, 1024-dim |
| **Judge** | `graft-judge:cpu` | `1feee68b0fadd71003fb33f1bd6e73d6e9e0295e54e273ced3a805bfeafa967b` | `ops/models/graft-judge.Modelfile`: `FROM phi4-mini` + `num_gpu 0` (CPU-only) |
| **Embeddings** | `graft-embed:cpu` | `bf6e5ca4e70665a6d8a81145030b7eeeae658e75b2aff32ff3a55f51607163c9` | `ops/models/graft-embed.Modelfile`: `FROM qwen3-embedding:0.6b` + `num_gpu 0` (CPU-only) |
| (rejected) | `qwen3.5:9b` | `6488c96fa5faab64bb65cbd30d4289e20e6130ef535a93ef9a49f42eda893ea7` | Still pulled (6.6 GB) for re-evaluation; not used |

### CPU pins: judge and embeddings (R-02, 2026-09-26)

The stock `qwen3-embedding:0.6b` loads 2.2 GiB fully into VRAM by default, and nothing
stopped `phi4-mini` doing the same; SPEC §5 makes the doer the sole VRAM resident. The
derived `:cpu` tags bake in `num_gpu 0`, so placement no longer depends on each caller
passing an option. **Use `graft-judge:cpu` and `graft-embed:cpu`, never the base tags.**
Verified after loading both: `/api/ps` → `graft-judge:cpu` size 3.09 GB `size_vram` 0;
`graft-embed:cpu` size 2.37 GB `size_vram` 0; `nvidia-smi` unchanged at 1632 MiB (Windows
baseline); embed dim 1024.

### Substitution: doer `qwen3.5:9b` → `qwen3:8b` (as `graft-doer:8k`)

SPEC §5 intent is an 8–9B Qwen, **text-only**, Q4_K_M, sole GPU resident. `qwen3.5:9b`
exists (9.7B Q4_K_M, requires Ollama ≥0.17.1) but fails two of those:
- **Not text-only.** `ollama show` reports capabilities `completion, vision, tools,
  thinking`; 14 vision tensors are bundled in the single GGUF (no separate projector layer).
- **Not GPU-resident.** 12%/88% CPU/GPU split at `num_ctx` 8192 on this card.

Measured 2026-09-25, same prompt, `num_ctx` 8192, temperature 0, 3 warm runs each (raw
responses in `data/smoke/`):

| Model | Warm eval tok/s | Placement |
|---|---|---|
| qwen3.5:9b | 27.9 · 28.8 · 29.6 | 12% CPU / 88% GPU (spill) |
| qwen3:8b | 47.9 · 47.1 · 46.1 | 100% GPU |

(A cold first run of qwen3:8b measured 19.5 tok/s; cold runs are excluded.)

### Context-window pin: 8192

qwen3:8b residency by `num_ctx`: 8192 → 100% GPU (~47 tok/s) · 16384 → 20% CPU (23.5
tok/s) · 32768 → 41% CPU (16.5 tok/s). dsh calls Ollama's `/v1` endpoint, which cannot
pass `num_ctx` and loaded at **4096** by default — hence the derived `graft-doer:8k`.
**Consequence (Phase 0):** dsh's fixed prompt (system + tool schemas + runtime context)
measured ~6.0–6.6K tokens, leaving <2K for work; the smoke session compacted 7 times.
**Resolved by R-01** (below): first request now 2,043 tokens.

### Doer context budget (R-01, 2026-09-26)

**The doer's first request now costs 2,043 of 8,192 tokens (was 6,004), leaving ~6.1K
of working context.** Measured from Ollama's own `task.n_tokens` log line (journald) on
the same toy task (`"Create a file named answer.txt containing the text 42."`, run from
`data/smoke/r01-ws`), and cross-checked by capturing the request body through a
localhost logging proxy (`--patch` overlay; not committed):

| | Tools | Tool-schema chars | System-prompt chars | First request `task.n_tokens` | Requests in session |
|---|---|---|---|---|---|
| Before (Phase 0 profile) | 23 | 26,074 | 3,801 | **6,004** | 6,004 · 6,199 · 6,518 · 6,281 · 6,985 |
| After (19 rows disabled) | 6 | 7,789 | 1,558 | **2,043** | 2,043 · 2,242 · 2,536 · 3,133 |

Both runs exited 0 with `answer.txt` = `42`. The biggest single costs removed were the
`workflow` (4.2K chars), `subagent*` (2.8K), `list_agents`/`send_message`/`interrupt_agent`
(3.0K), goal tools (2.4K) and `todo_write` (1.4K) schemas, plus their system-prompt
sections. The remaining floor is dominated by the `bash` schema (3.4K chars).
`graft-replay` (sdk-minimal) was not re-measured: it has no one-shot CLI, so its prompt
size is measured when Phase 2's SDK replay driver exists.

### Doer output cap: pi-ai's fixed 4096-token reserve (R-01, 2026-09-26)

**Declaring the real 8192 window starved every response.** pi-ai 0.85.1
(`dist/api/simple-options.js`, `clampMaxTokensToContext`) caps output at
`contextWindow − estimated prompt − 4096` (`CONTEXT_SAFETY_TOKENS`, hard-coded). Observed
`max_completion_tokens`: **1** on Phase 0's 6K prompt (hence 7 compactions on a toy task),
~1,700 after the R-01 trim. The `graft` route now declares `contextWindow: 11264`
(= 8192 real − 1024 margin + 4096 reserve), so prompt + output ≤ 7,168 real tokens, and
`compaction-basic.thresholdRatio: 0.5` (5,632 estimated) replaces the default 0.8, which
against 11264 would sit above the real window. Observed after: `max_completion_tokens`
4,096 (the model cap) on the first request, falling as context grows.

### Thinking mode: ON, explicit (R-04, 2026-09-26)

**Thinking stays on, now sent explicitly as `reasoning_effort: "high"`.** Off is not
viable on this stack: with thinking off (`reasoning_effort: "none"`) and tools present,
qwen3 generated 76–116 completion tokens per request but Ollama's `/v1` delivered **no
content and no tool call**, and dsh aborted with `EMPTY_RESPONSE` (replayed directly
against `/v1` and `/api/chat` with `think:false`: same empty message; without tools the
same prompt returns normal text — so the output is lost in tool-call handling). k=3 per
arm, interleaved, slugify kata (task + 10-case hidden tier-1 test, stdlib), `graft`
profile after the R-01 fixes, all at T=1.0/top_p=1.0 (see R-06):

| Run | Exit | Wall s | Requests | Completion tokens | Reasoning chars | Final content non-empty | Tier-1 |
|---|---|---|---|---|---|---|---|
| on-1 | 0 | 195 | 7 | 6,093 | 21,873 | yes | PASS |
| on-2 | 0 | 62 | 2 | 2,002 | 7,841 | yes | PASS |
| on-3 | 0 | 131 | 5 | 4,244 | 16,427 | yes | PASS |
| off-1 | 1 | 9 | 2 | 192 | 0 | no (2/2 empty) | FAIL (no file) |
| off-2 | 1 | 8 | 2 | 167 | 0 | no (2/2 empty) | FAIL (no file) |
| off-3 | 1 | 7 | 2 | 168 | 0 | no (2/2 empty) | FAIL (no file) |

Cost of "on": 2.0–6.1K completion tokens and 1–3 min per kata, and reasoning counts
against each request's output cap. dsh re-sends earlier turns' reasoning in the
assistant message's `reasoning` field (seen in captured requests); whether Ollama's qwen3
template renders it back into the prompt was **not** measured — check before trusting
context-budget arithmetic on multi-turn episodes. Enforcement: `llm-pi-ai` route `reasoning: high`,
`compat.supportsReasoningEffort: true`, `supportsDeveloperRole: false` (keep `system`),
model `reasoningEfforts: {high: high}`.
Verified on the committed profile (2026-09-26, same kata, proxy overlay swapping only
`baseURL`): exit 0, tier-1 PASS, 83 s; `reasoning_effort: "high"` on all 3 requests;
`max_completion_tokens` 4096 → 3218 → 2910; Ollama `task.n_tokens` 2211 · 3729 · 4104;
sampler `temp = 1.000` (R-06 open).

### Smoke tests (2026-09-25)

| Test | Result |
|---|---|
| Doer generation | `graft-doer:8k` / qwen3:8b: ~47 tok/s warm, 100% GPU, 8192 ctx. qwen3 thinking mode is **on by default** via `/v1` (text arrives in a separate `reasoning` field; tight token caps yield empty `content`) |
| Judge JSON + logprobs | phi4-mini, `num_gpu 0` → 100% CPU, 13.8 tok/s, schema-constrained `/api/chat` `format` parsed OK, `logprobs` + `top_logprobs` present. **Finding:** logprobs are the *pre-grammar-mask* distribution — at the verdict position the top tokens were `incorrect` (p≈0.88) and `wrong`, and the sampled in-schema token `un`(clear) had p≈0.0001, contradicting the judge's own notes ("does not satisfy"). Raw verdict-token logprob under constrained decoding is not a usable `raw_conf` as-is |
| Embedding | qwen3-embedding:0.6b, CPU, 2 inputs, dim 1024, 2.27 s total |
| Co-residency | Models unloaded between tests via `keep_alive: 0`; never co-resident |
| dsh Standard headless | `ops/scripts/dsh --profile graft` "create hello.md with today's date" from `data/smoke/dsh-ws`: exit 0, `hello.md` written, session log captured (65 events: 5 tool calls/results, 7 compactions). Wall time 5m05s. **Output quality: would fail a tier-1 check** — content `Hello from Graft\n2026-09-25` with a literal backslash-n; the `date` call was over-escaped and the date was typed in |
| dsh replay profile | `graft-replay` composes (`--dump-config`) and boots/disconnects cleanly (exit 0). Not yet driven by an SDK client |
