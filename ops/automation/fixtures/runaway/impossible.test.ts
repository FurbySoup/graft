// Runaway fixture (BACKLOG P05-RUNAWAY / P05-09). Impossible by construction: no
// change outside this file can make 1 + 1 equal 3, and this file, every vitest
// config and ops/automation/ are hard-excluded from worker edits. It lives outside
// the vitest projects, so `pnpm test` never collects it.
import { expect, test } from 'vitest';

test('impossible tautology', () => {
  expect(1 + 1).toBe(3);
});
