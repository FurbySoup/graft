/**
 * Typed config loader.
 *
 * Reads a JSON config file and validates it against a small declarative
 * schema, returning a fully-typed object. Validation is total: every schema
 * key must be present with the declared scalar type, and the file may contain
 * no keys the schema does not declare. Both directions matter — a missing key
 * is a silent default waiting to happen, and an unknown key is usually a typo
 * or a stale option that would otherwise be ignored.
 *
 * The parsed value is narrowed from `unknown`; nothing here trusts the shape
 * of the JSON until it has been checked.
 */

import { readFileSync } from 'node:fs';

/** The scalar types a config field may hold. */
export type FieldTypeName = 'string' | 'number' | 'boolean';

/** Declares the expected type of one config key. */
export interface FieldSpec {
  readonly type: FieldTypeName;
}

/** A config schema: every expected key mapped to its field spec. */
export type ConfigSchema = Readonly<Record<string, FieldSpec>>;

/** The runtime type a single {@link FieldSpec} describes. */
type ValueOf<S extends FieldSpec> = S['type'] extends 'string'
  ? string
  : S['type'] extends 'number'
    ? number
    : S['type'] extends 'boolean'
      ? boolean
      : never;

/** The typed object a schema produces once validated. */
export type ConfigOf<S extends ConfigSchema> = {
  readonly [K in keyof S]: ValueOf<S[K]>;
};

/** Raised when a config file does not match its schema. */
export class ConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ConfigError';
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/**
 * Validate an already-parsed JSON value against `schema`.
 *
 * Throws {@link ConfigError} on a missing key, an unknown key, or a value
 * whose type does not match the declared field type.
 */
export function validateConfig<S extends ConfigSchema>(value: unknown, schema: S): ConfigOf<S> {
  if (!isRecord(value)) {
    throw new ConfigError('config must be a JSON object');
  }

  const result: Record<string, string | number | boolean> = {};
  for (const [key, spec] of Object.entries(schema)) {
    if (!Object.prototype.hasOwnProperty.call(value, key)) {
      throw new ConfigError(`missing key: ${key}`);
    }
    const field = value[key];
    // `typeof field` is a string; comparing it to a FieldTypeName covers all scalars.
    if (typeof field !== spec.type) {
      throw new ConfigError(`key ${key} must be a ${spec.type}, got ${typeof field}`);
    }
    result[key] = field as string | number | boolean;
  }

  for (const key of Object.keys(value)) {
    if (!Object.prototype.hasOwnProperty.call(schema, key)) {
      throw new ConfigError(`unknown key: ${key}`);
    }
  }

  return result as ConfigOf<S>;
}

/** Parse a JSON string and validate it against `schema`. */
export function parseConfig<S extends ConfigSchema>(source: string, schema: S): ConfigOf<S> {
  let parsed: unknown;
  try {
    parsed = JSON.parse(source);
  } catch (err: unknown) {
    const detail = err instanceof Error ? err.message : String(err);
    throw new ConfigError(`config is not valid JSON: ${detail}`);
  }
  return validateConfig(parsed, schema);
}

/** Read a JSON config file from `path` and validate it against `schema`. */
export function loadConfig<S extends ConfigSchema>(path: string, schema: S): ConfigOf<S> {
  return parseConfig(readFileSync(path, 'utf8'), schema);
}
