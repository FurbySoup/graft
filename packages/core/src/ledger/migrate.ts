import { readdirSync, readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import { fileURLToPath } from 'node:url';

/**
 * Package-level `migrations/` directory. This module lives at
 * `src/ledger/` (vitest) or `dist/ledger/` (built), both two levels below
 * the package root, so the same relative URL resolves in either case.
 */
const MIGRATIONS_DIR = fileURLToPath(new URL('../../migrations/', import.meta.url));

const MIGRATION_FILE = /^(\d{4})_[a-z0-9_]+\.sql$/;

interface MigrationFile {
  readonly version: number;
  readonly path: string;
}

function listMigrations(dir: string): MigrationFile[] {
  const files: MigrationFile[] = [];
  for (const name of readdirSync(dir)) {
    const match = MIGRATION_FILE.exec(name);
    const digits = match?.[1];
    if (digits === undefined) continue;
    files.push({ version: Number(digits), path: `${dir}${name}` });
  }
  files.sort((a, b) => a.version - b.version);
  for (let i = 1; i < files.length; i++) {
    const prev = files[i - 1];
    const cur = files[i];
    if (prev !== undefined && cur !== undefined && prev.version === cur.version) {
      throw new Error(`duplicate migration version ${String(cur.version)}`);
    }
  }
  return files;
}

function appliedVersions(db: DatabaseSync): Set<number> {
  const rows = db.prepare('SELECT version FROM schema_migrations').all();
  const versions = new Set<number>();
  for (const row of rows) {
    const version = row['version'];
    if (typeof version !== 'number') {
      throw new Error('schema_migrations.version is not an integer');
    }
    versions.add(version);
  }
  return versions;
}

/**
 * Apply every unapplied `migrations/NNNN_*.sql` file in version order.
 * Each migration runs in its own transaction and is recorded in
 * `schema_migrations`. Idempotent: re-running applies nothing.
 */
export function migrate(db: DatabaseSync): { applied: number[] } {
  db.exec(
    'CREATE TABLE IF NOT EXISTS schema_migrations (version INTEGER PRIMARY KEY, applied_at TEXT NOT NULL)',
  );
  const done = appliedVersions(db);
  const record = db.prepare('INSERT INTO schema_migrations (version, applied_at) VALUES (?, ?)');
  const applied: number[] = [];

  for (const migration of listMigrations(MIGRATIONS_DIR)) {
    if (done.has(migration.version)) continue;
    const sql = readFileSync(migration.path, 'utf8');
    db.exec('BEGIN IMMEDIATE');
    try {
      db.exec(sql);
      record.run(migration.version, new Date().toISOString());
      db.exec('COMMIT');
    } catch (err: unknown) {
      if (db.isTransaction) db.exec('ROLLBACK');
      throw err;
    }
    applied.push(migration.version);
  }
  return { applied };
}

/** Open (or create) a ledger database with foreign keys enforced, migrated to the latest schema. */
export function openLedger(path: string): DatabaseSync {
  const db = new DatabaseSync(path, { enableForeignKeyConstraints: true });
  try {
    migrate(db);
  } catch (err: unknown) {
    db.close();
    throw err;
  }
  return db;
}
