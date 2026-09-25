import { DatabaseSync } from 'node:sqlite';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { LEDGER_TABLES, migrate, openLedger } from '../index.js';
import type { EpisodeRow, InjectionRow } from '../index.js';

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

  it('is idempotent', () => {
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

  it('rejects UPDATE (append-only)', () => {
    insertEpisode(db, episode);
    expect(() => db.exec("UPDATE episodes SET outcome_final = 'pass' WHERE id = 'ep-1'")).toThrow(
      'ledger is append-only: episodes',
    );
  });

  it('rejects DELETE (append-only)', () => {
    insertEpisode(db, episode);
    expect(() => db.exec("DELETE FROM episodes WHERE id = 'ep-1'")).toThrow(
      'ledger is append-only: episodes',
    );
  });

  it('rejects an invalid outcome source', () => {
    insertEpisode(db, episode);
    expect(() =>
      db
        .prepare('INSERT INTO outcomes (episode_id, source, label, ts) VALUES (?, ?, ?, ?)')
        .run('ep-1', 'vibes', 'pass', '2026-09-25T00:00:00.000Z'),
    ).toThrow(/CHECK constraint failed/);
  });
});
