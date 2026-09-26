import { DatabaseSync } from 'node:sqlite';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { LEDGER_TABLES, migrate, openLedger } from '../index.js';
import type { EpisodeRow, InjectionRow, LedgerTable } from '../index.js';

const episode: EpisodeRow = {
  id: 'ep-1',
  session_id: 'sess-1',
  ts: '2026-09-25T00:00:00.000Z',
  task_type: 'kata',
  domain: 'ts-kata',
  preset: 'graft-replay',
  doer_model: 'qwen3.5:9b',
  skills_enabled: 1,
  outcome_final: null,
};

const injection: InjectionRow = {
  episode_id: 'ep-1',
  skill_id: 'skill-a',
  version: 'abc123',
  section_id: 'S1',
};

function insertEpisode(db: DatabaseSync, row: EpisodeRow): void {
  db.prepare(
    `INSERT INTO episodes (id, session_id, ts, task_type, domain, preset, doer_model, skills_enabled, outcome_final)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  ).run(
    row.id,
    row.session_id,
    row.ts,
    row.task_type,
    row.domain,
    row.preset,
    row.doer_model,
    row.skills_enabled,
    row.outcome_final,
  );
}

function tableNames(db: DatabaseSync): string[] {
  return db
    .prepare("SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name")
    .all()
    .map((r) => String(r['name']));
}

/**
 * Insert one valid row into every ledger table, respecting foreign keys, so
 * that BEFORE UPDATE / BEFORE DELETE triggers have a row to fire on. (An
 * UPDATE/DELETE matching zero rows would fire no trigger and vacuously "pass".)
 */
function seedLedger(db: DatabaseSync): void {
  insertEpisode(db, episode);
  db.prepare(
    'INSERT INTO injections (episode_id, skill_id, version, section_id) VALUES (?, ?, ?, ?)',
  ).run('ep-1', 'skill-a', 'abc123', 'S1');
  db.prepare(
    'INSERT INTO verdicts (id, episode_id, tier, verdict, raw_conf, p_correct, judge_model) VALUES (?, ?, ?, ?, ?, ?, ?)',
  ).run('v-1', 'ep-1', 2, 'pass', 0.9, 0.8, 'phi4-mini');
  db.prepare(
    'INSERT INTO blames (verdict_id, section_id, quote, quote_validated) VALUES (?, ?, ?, ?)',
  ).run('v-1', 'S1', 'a quoted trace line', 1);
  db.prepare('INSERT INTO outcomes (episode_id, source, label, ts) VALUES (?, ?, ?, ?)').run(
    'ep-1',
    'judge',
    'pass',
    '2026-09-25T00:00:00.000Z',
  );
  db.prepare('INSERT INTO calib_log (ts, context, raw_conf, outcome) VALUES (?, ?, ?, ?)').run(
    '2026-09-25T00:00:00.000Z',
    'judge',
    0.9,
    1,
  );
  db.prepare(
    'INSERT INTO merges (ts, skill_id, from_sha, to_sha, stats_verdict_ref, reverted) VALUES (?, ?, ?, ?, ?, ?)',
  ).run('2026-09-25T00:00:00.000Z', 'skill-a', 'aaa111', 'bbb222', 'stats-1', 0);
}

/**
 * Per-table append-only fixtures. `selfUpdate` is a no-op assignment (col = col)
 * so the UPDATE is otherwise valid — only the trigger should abort it.
 */
const APPEND_ONLY_TABLES: ReadonlyArray<{ readonly table: LedgerTable; readonly selfUpdate: string }> = [
  { table: 'episodes', selfUpdate: 'session_id = session_id' },
  { table: 'injections', selfUpdate: 'skill_id = skill_id' },
  { table: 'verdicts', selfUpdate: 'tier = tier' },
  { table: 'blames', selfUpdate: 'quote = quote' },
  { table: 'outcomes', selfUpdate: 'label = label' },
  { table: 'calib_log', selfUpdate: 'context = context' },
  { table: 'merges', selfUpdate: 'skill_id = skill_id' },
];

describe('ledger migrations', () => {
  let db: DatabaseSync;

  beforeEach(() => {
    db = openLedger(':memory:');
  });

  afterEach(() => {
    db.close();
  });

  it('creates all ledger tables and schema_migrations', () => {
    const names = tableNames(db);
    for (const table of LEDGER_TABLES) expect(names).toContain(table);
    expect(names).toContain('schema_migrations');
    expect(LEDGER_TABLES).toHaveLength(7);
  });

  it('migration is idempotent', () => {
    const fresh = new DatabaseSync(':memory:');
    try {
      expect(migrate(fresh).applied).toEqual([1]);
      expect(migrate(fresh).applied).toEqual([]);
      const count = fresh.prepare('SELECT COUNT(*) AS n FROM schema_migrations').get();
      expect(count?.['n']).toBe(1);
    } finally {
      fresh.close();
    }
  });

  it('accepts an episode and an injection', () => {
    insertEpisode(db, episode);
    db.prepare(
      'INSERT INTO injections (episode_id, skill_id, version, section_id) VALUES (?, ?, ?, ?)',
    ).run(injection.episode_id, injection.skill_id, injection.version, injection.section_id);
    const row = db.prepare('SELECT * FROM injections WHERE episode_id = ?').get('ep-1');
    expect(row).toEqual({ ...injection });
  });

  it('enforces foreign keys', () => {
    expect(() =>
      db
        .prepare('INSERT INTO injections (episode_id, skill_id, version, section_id) VALUES (?, ?, ?, ?)')
        .run('missing', 'skill-a', 'abc123', 'S1'),
    ).toThrow(/FOREIGN KEY/);
  });

  for (const { table, selfUpdate } of APPEND_ONLY_TABLES) {
    it(`rejects UPDATE on ${table} (append-only)`, () => {
      seedLedger(db);
      expect(() => db.exec(`UPDATE ${table} SET ${selfUpdate}`)).toThrow(
        `ledger is append-only: ${table}`,
      );
    });

    it(`rejects DELETE on ${table} (append-only)`, () => {
      seedLedger(db);
      expect(() => db.exec(`DELETE FROM ${table}`)).toThrow(`ledger is append-only: ${table}`);
    });
  }

  it('rejects an invalid outcome source', () => {
    insertEpisode(db, episode);
    expect(() =>
      db
        .prepare('INSERT INTO outcomes (episode_id, source, label, ts) VALUES (?, ?, ?, ?)')
        .run('ep-1', 'vibes', 'pass', '2026-09-25T00:00:00.000Z'),
    ).toThrow(/CHECK constraint failed/);
  });
});
