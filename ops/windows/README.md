# ops/windows — pause Graft from Windows

**Double-click `graft-pause.cmd` before gaming; `graft-resume.cmd` after.** Pause frees
the GPU memory Graft's models were using and stops any new project activity until you
resume; nothing is lost or uninstalled.

| Launcher | Runs (inside WSL) | Use when |
|---|---|---|
| `graft-pause.cmd` | `graft pause --reason "gaming / GPU needed"` | Default. Lets a run already in progress finish its current attempt |
| `graft-pause-hard.cmd` | `graft pause --hard --reason "gaming / GPU needed"` | You want everything stopped now |
| `graft-resume.cmd` | `graft resume` | You are done with the GPU |
| `graft-status.cmd` | `graft status` | Check PAUSED/ACTIVE, running runs, loaded models, GPU memory |

Each is a one-line wrapper around
`wsl.exe -d Ubuntu -u mark -- /home/mark/graft/ops/scripts/graft <cmd>`; the window stays
open so you can read the output, then press any key to close it.

## What pause does

- **Frees the GPU (and model RAM) immediately.** All Ollama models are unloaded, and the
  output shows GPU memory before → after. With nothing loaded, expect roughly the idle
  baseline of ~1640 MiB of 8188 MiB, which is Windows' own use.
- **Blocks every new run.** It writes the flag file `ops/automation/pause`. The worker
  and review scripts see it and exit immediately; dsh runs refuse to start. Cron keeps
  firing on schedule (worker every 30 min 00:00–06:30, review :15/:45 00:15–07:45,
  UK time), but each run exits at once while paused.
- **Soft vs hard only matters for a run already in progress:**
  - *Soft* (`graft-pause.cmd`): it finishes its current attempt, then stops. That run's
    AI session uses cloud compute, not your GPU — it only costs some local CPU/RAM for
    builds and tests.
  - *Hard* (`graft-pause-hard.cmd`): it is stopped now, cleanly — its backlog item is
    released and stays open for a later run.

## What pause does not do

- **It does not stop the Ollama service.** Ollama stays running but idle; with no models
  loaded it holds ~0 extra VRAM, and it only loads a model when Graft asks — which Graft
  does not do while paused. Resume does not preload anything either.
- **It does not give WSL's own RAM back to Windows.** The `vmmem` / `VmmemWSL` process in
  Task Manager is WSL's memory as a whole. Pause frees memory *inside* WSL; Windows only
  gets it back through WSL's gradual memory reclaim, or through `wsl --shutdown` (below).

## Put the launchers on the Desktop or Start

The launchers live in the repo; make shortcuts to them rather than moving them.

1. In File Explorer, open `\\wsl.localhost\Ubuntu\home\mark\graft\ops\windows`.
2. Right-click `graft-pause.cmd` → **Show more options** (Windows 11) → **Send to** →
   **Desktop (create shortcut)**. Repeat for the others you want.
3. Optional: right-click the new Desktop shortcut → **Pin to Start**. If that entry is
   missing, copy the shortcut into
   `%APPDATA%\Microsoft\Windows\Start Menu\Programs` and it appears in Start.

If a window briefly shows `UNC paths are not supported. Defaulting to Windows
directory.`, that is harmless — the launcher does not depend on its working directory.

## Nuclear option: `wsl --shutdown`

Only if you need WSL's RAM back too, run from PowerShell or Command Prompt:

```
wsl --shutdown
```

Run `graft-pause-hard.cmd` first. `wsl --shutdown` frees everything, including `vmmem`,
but it:

- kills a running worker uncleanly (mid-attempt, claim not released) — the hard pause
  avoids that;
- stops cron and Ollama until WSL starts again (opening any WSL terminal restarts it).

The pause flag survives the shutdown, so after WSL restarts nothing runs until you
double-click `graft-resume.cmd`.
