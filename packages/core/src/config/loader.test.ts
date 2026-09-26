import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { ConfigError, loadConfig, parseConfig } from '../index.js';
import type { ConfigSchema } from '../index.js';

/** Schema for the `fixtures/valid.json` sample config. */
const SCHEMA = {
  ollamaEndpoint: { type: 'string' },
  doerModel: { type: 'string' },
  judgeModel: { type: 'string' },
  iterationCap: { type: 'number' },
  skillsEnabled: { type: 'boolean' },
} as const satisfies ConfigSchema;

const validFixture = fileURLToPath(new URL('./fixtures/valid.json', import.meta.url));

describe('typed config loader', () => {
  it('loads a valid fixture file into a typed object', () => {
    const config = loadConfig(validFixture, SCHEMA);
    // Field types are inferred from the schema, not asserted here with `any`.
    expect(config.ollamaEndpoint).toBe('http://localhost:11434');
    expect(config.doerModel).toBe('graft-doer:8k');
    expect(config.judgeModel).toBe('phi4-mini');
    expect(config.iterationCap).toBe(5);
    expect(config.skillsEnabled).toBe(true);
  });

  it('rejects a missing key', () => {
    const source = JSON.stringify({
      ollamaEndpoint: 'http://localhost:11434',
      doerModel: 'graft-doer:8k',
      judgeModel: 'phi4-mini',
      iterationCap: 5,
      // skillsEnabled omitted
    });
    expect(() => parseConfig(source, SCHEMA)).toThrow(ConfigError);
    expect(() => parseConfig(source, SCHEMA)).toThrow(/missing key: skillsEnabled/);
  });

  it('rejects an unknown key', () => {
    const source = JSON.stringify({
      ollamaEndpoint: 'http://localhost:11434',
      doerModel: 'graft-doer:8k',
      judgeModel: 'phi4-mini',
      iterationCap: 5,
      skillsEnabled: true,
      routerModel: 'unexpected',
    });
    expect(() => parseConfig(source, SCHEMA)).toThrow(ConfigError);
    expect(() => parseConfig(source, SCHEMA)).toThrow(/unknown key: routerModel/);
  });

  it('rejects a value of the wrong type', () => {
    const source = JSON.stringify({
      ollamaEndpoint: 'http://localhost:11434',
      doerModel: 'graft-doer:8k',
      judgeModel: 'phi4-mini',
      iterationCap: 'five',
      skillsEnabled: true,
    });
    expect(() => parseConfig(source, SCHEMA)).toThrow(/iterationCap must be a number/);
  });

  it('rejects a non-object config', () => {
    expect(() => parseConfig('[1, 2, 3]', SCHEMA)).toThrow(/must be a JSON object/);
  });

  it('rejects invalid JSON', () => {
    expect(() => parseConfig('{ not json', SCHEMA)).toThrow(/not valid JSON/);
  });
});
