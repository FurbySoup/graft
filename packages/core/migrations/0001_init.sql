-- 0001_init: Graft ledger, SPEC §3.3.
-- Append-only: corrections are new rows, never updates. Every ledger table
-- carries BEFORE UPDATE / BEFORE DELETE triggers that abort.
-- Timestamps are ISO-8601 UTC TEXT; booleans are INTEGER 0/1.
-- raw_conf is a probability: exp(logprob) of the judge's chosen verdict token.

CREATE TABLE IF NOT EXISTS schema_migrations (
  version    INTEGER PRIMARY KEY,
  applied_at TEXT NOT NULL
);

-- `preset` keeps the SPEC name; dsh calls these "profiles".
CREATE TABLE episodes (
  id             TEXT PRIMARY KEY,
  session_id     TEXT NOT NULL,
  ts             TEXT NOT NULL,
  task_type      TEXT NOT NULL,
  domain         TEXT NOT NULL,
  preset         TEXT NOT NULL,
  doer_model     TEXT NOT NULL,
  skills_enabled INTEGER NOT NULL CHECK (skills_enabled IN (0, 1)),
  outcome_final  TEXT
);

CREATE TABLE injections (
  episode_id TEXT NOT NULL REFERENCES episodes(id),
  skill_id   TEXT NOT NULL,
  version    TEXT NOT NULL,
  section_id TEXT NOT NULL
);
CREATE INDEX idx_injections_episode_id ON injections(episode_id);

CREATE TABLE verdicts (
  id          TEXT PRIMARY KEY,
  episode_id  TEXT NOT NULL REFERENCES episodes(id),
  tier        INTEGER NOT NULL CHECK (tier IN (1, 2)),
  verdict     TEXT NOT NULL CHECK (
                (tier = 1 AND verdict IN ('pass', 'fail', 'not_applicable'))
                OR (tier = 2 AND verdict IN ('pass', 'fail', 'unclear'))
              ),
  raw_conf    REAL CHECK (raw_conf IS NULL OR (raw_conf >= 0 AND raw_conf <= 1)),
  p_correct   REAL CHECK (p_correct IS NULL OR (p_correct >= 0 AND p_correct <= 1)),
  judge_model TEXT
);
CREATE INDEX idx_verdicts_episode_id ON verdicts(episode_id);

CREATE TABLE blames (
  verdict_id      TEXT NOT NULL REFERENCES verdicts(id),
  section_id      TEXT NOT NULL,
  quote           TEXT NOT NULL,
  quote_validated INTEGER NOT NULL CHECK (quote_validated IN (0, 1))
);
CREATE INDEX idx_blames_verdict_id ON blames(verdict_id);

CREATE TABLE outcomes (
  episode_id TEXT NOT NULL REFERENCES episodes(id),
  source     TEXT NOT NULL CHECK (source IN ('deterministic', 'judge', 'human')),
  label      TEXT NOT NULL,
  ts         TEXT NOT NULL
);
CREATE INDEX idx_outcomes_episode_id ON outcomes(episode_id);

CREATE TABLE calib_log (
  id       INTEGER PRIMARY KEY,
  ts       TEXT NOT NULL,
  context  TEXT NOT NULL CHECK (context IN ('judge', 'router')),
  raw_conf REAL NOT NULL CHECK (raw_conf >= 0 AND raw_conf <= 1),
  outcome  INTEGER NOT NULL CHECK (outcome IN (0, 1))
);

CREATE TABLE merges (
  id                INTEGER PRIMARY KEY,
  ts                TEXT NOT NULL,
  skill_id          TEXT NOT NULL,
  from_sha          TEXT NOT NULL,
  to_sha            TEXT NOT NULL,
  stats_verdict_ref TEXT NOT NULL,
  reverted          INTEGER NOT NULL CHECK (reverted IN (0, 1))
);

-- Append-only enforcement.
CREATE TRIGGER episodes_no_update BEFORE UPDATE ON episodes
BEGIN SELECT RAISE(ABORT, 'ledger is append-only: episodes'); END;
CREATE TRIGGER episodes_no_delete BEFORE DELETE ON episodes
BEGIN SELECT RAISE(ABORT, 'ledger is append-only: episodes'); END;

CREATE TRIGGER injections_no_update BEFORE UPDATE ON injections
BEGIN SELECT RAISE(ABORT, 'ledger is append-only: injections'); END;
CREATE TRIGGER injections_no_delete BEFORE DELETE ON injections
BEGIN SELECT RAISE(ABORT, 'ledger is append-only: injections'); END;

CREATE TRIGGER verdicts_no_update BEFORE UPDATE ON verdicts
BEGIN SELECT RAISE(ABORT, 'ledger is append-only: verdicts'); END;
CREATE TRIGGER verdicts_no_delete BEFORE DELETE ON verdicts
BEGIN SELECT RAISE(ABORT, 'ledger is append-only: verdicts'); END;

CREATE TRIGGER blames_no_update BEFORE UPDATE ON blames
BEGIN SELECT RAISE(ABORT, 'ledger is append-only: blames'); END;
CREATE TRIGGER blames_no_delete BEFORE DELETE ON blames
BEGIN SELECT RAISE(ABORT, 'ledger is append-only: blames'); END;

CREATE TRIGGER outcomes_no_update BEFORE UPDATE ON outcomes
BEGIN SELECT RAISE(ABORT, 'ledger is append-only: outcomes'); END;
CREATE TRIGGER outcomes_no_delete BEFORE DELETE ON outcomes
BEGIN SELECT RAISE(ABORT, 'ledger is append-only: outcomes'); END;

CREATE TRIGGER calib_log_no_update BEFORE UPDATE ON calib_log
BEGIN SELECT RAISE(ABORT, 'ledger is append-only: calib_log'); END;
CREATE TRIGGER calib_log_no_delete BEFORE DELETE ON calib_log
BEGIN SELECT RAISE(ABORT, 'ledger is append-only: calib_log'); END;

CREATE TRIGGER merges_no_update BEFORE UPDATE ON merges
BEGIN SELECT RAISE(ABORT, 'ledger is append-only: merges'); END;
CREATE TRIGGER merges_no_delete BEFORE DELETE ON merges
BEGIN SELECT RAISE(ABORT, 'ledger is append-only: merges'); END;
