import { defineProject } from 'vitest/config';

export default defineProject({
  test: {
    name: 'graft-judge',
    environment: 'node',
    include: ['src/**/*.test.ts'],
  },
});
