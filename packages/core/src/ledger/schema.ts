/**
 * Row types for the Graft ledger (`data/ledger.sqlite`), SPEC §3.3.
 *
 * The ledger is append-only: corrections are new rows, never updates
 * (enforced by triggers in `migrations/0001_init.sql`). These interfaces
 * describe rows as SQLite returns them, so booleans are `0 | 1` and
 * timestamps are ISO-8601 strings.
 */

/** SQLite has no boolean type; booleans are stored and read as 0/1. */
export type SqliteBool = 0 | 1;

/** ISO-8601 UTC timestamp string. */
export type IsoTimestamp = string;

/** Verification tier, SPEC §3.2: 1 = deterministic checker, 2 = judge model. */
export type VerdictTier = 1 | 2;

/**
 * Verdict values, SPEC §3.2. Tier 1 emits pass/fail/not_applicable;
 * tier 2 emits pass/fail/unclear.
 */
export type VerdictValue = 'pass' | 'fail' | 'unclear' | 'not_applicable';

/** Who produced an outcome label, SPEC §3.3. */
export type OutcomeSource = 'deterministic' | 'judge' | 'human';

/** Which calibrated decision a calib_log row belongs to, SPEC §3.3 / §3.6. */
export type CalibContext = 'judge' | 'router';

/** One agent episode (a dsh session run on a task), SPEC §3.3. */
export interface EpisodeRow {
  readonly id: string;
  readonly session_id: string;
  readonly ts: IsoTimestamp;
  readonly task_type: string;
  readonly domain: string;
  /** Named `preset` per SPEC; dsh itself calls these "profiles". */
  readonly preset: string;
  readonly doer_model: string;
  /** 0 = ablation arm (graft-trust bypass), SPEC §6.5. */
  readonly skills_enabled: SqliteBool;
  readonly outcome_final: string | null;
}

/** A skill section that was in context for an episode (`skill_injected`), SPEC §3.1. */
export interface InjectionRow {
  readonly episode_id: string;
  readonly skill_id: string;
  /** Skill version = git SHA, SPEC §3.1. */
  readonly version: string;
  readonly section_id: string;
}

/** A tier-1 or tier-2 verdict on an episode, SPEC §3.2. */
export interface VerdictRow {
  readonly id: string;
  readonly episode_id: string;
  readonly tier: VerdictTier;
  readonly verdict: VerdictValue;
  /**
   * Raw choice-token confidence (tier 2): exp(logprob) of the chosen verdict token,
   * so always in [0, 1]. An input, not a truth (CLAUDE.md principle 5).
   */
  readonly raw_conf: number | null;
  /** Calibrated probability from `data/calibration/judge.json`, SPEC §3.2. */
  readonly p_correct: number | null;
  /** Judge model identifier (tier 2 only). */
  readonly judge_model: string | null;
}

/** A judge blame citing a skill section, SPEC §3.2 / §3.3 and CLAUDE.md principle 9. */
export interface BlameRow {
  readonly verdict_id: string;
  readonly section_id: string;
  readonly quote: string;
  /** 1 only if the quote was mechanically found in the trace. */
  readonly quote_validated: SqliteBool;
}

/** A labelled outcome for an episode, SPEC §3.3. */
export interface OutcomeRow {
  readonly episode_id: string;
  readonly source: OutcomeSource;
  readonly label: string;
  readonly ts: IsoTimestamp;
}

/** A raw-confidence / observed-outcome pair for calibration fitting, SPEC §3.3 / §3.6. */
export interface CalibLogRow {
  readonly id: number;
  readonly ts: IsoTimestamp;
  readonly context: CalibContext;
  readonly raw_conf: number;
  /** Observed correctness: 1 = the calibrated decision was correct. */
  readonly outcome: SqliteBool;
}

/** A skill merge produced by consolidation; feeds dashboard annotations, SPEC §3.3 / §3.8. */
export interface MergeRow {
  readonly id: number;
  readonly ts: IsoTimestamp;
  readonly skill_id: string;
  readonly from_sha: string;
  readonly to_sha: string;
  /** Reference to the graft-stats verdict that gated this merge, SPEC §6.2. */
  readonly stats_verdict_ref: string;
  readonly reverted: SqliteBool;
}

/** All ledger tables, in dependency order. */
export const LEDGER_TABLES = [
  'episodes',
  'injections',
  'verdicts',
  'blames',
  'outcomes',
  'calib_log',
  'merges',
] as const;

export type LedgerTable = (typeof LEDGER_TABLES)[number];

/** Maps each ledger table to its row type. */
export interface LedgerRowByTable {
  readonly episodes: EpisodeRow;
  readonly injections: InjectionRow;
  readonly verdicts: VerdictRow;
  readonly blames: BlameRow;
  readonly outcomes: OutcomeRow;
  readonly calib_log: CalibLogRow;
  readonly merges: MergeRow;
}
