# BACKLOG (fixture for ops/automation/tests/test-worker.sh)

current-phase: 0.5

## Phase 0.5

### F-01 · Human-only item comes first but is skipped
- status: open
- phase: 0.5
- executor: human
- owner-only: yes
- depends: —
- dod: n/a

### F-02 · Worker item whose dependency is not done
- status: open
- phase: 0.5
- executor: worker
- owner-only: no
- depends: F-05
- dod: n/a
- dod-cmd: true

### F-03 · Worker item already claimed by an existing branch
- status: open
- phase: 0.5
- executor: worker
- owner-only: no
- depends: —
- dod: n/a
- dod-cmd: true

### F-04 · First eligible worker item
- status: open
- phase: 0.5
- executor: worker
- owner-only: no
- depends: F-06
- dod: n/a
- dod-cmd: true

### F-05 · An unfinished dependency (later phase)
- status: open
- phase: 1
- executor: worker
- owner-only: no
- depends: —
- dod: n/a
- dod-cmd: true

### F-06 · A finished dependency
- status: done
- phase: 0.5
- executor: session
- owner-only: no
- depends: —
- dod: n/a

## Phase 1

### F-07 · Worker item from a later phase
- status: open
- phase: 1
- executor: worker
- owner-only: no
- depends: —
- dod: n/a
- dod-cmd: true
