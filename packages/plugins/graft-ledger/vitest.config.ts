import { defineProject } from 'vitest/config';

export default defineProject({
  test: {
    name: 'graft-ledger',
    environment: 'node',
    include: ['src/**/*.test.ts'],
  },
});
