import { defineProject } from 'vitest/config';

export default defineProject({
  test: {
    name: 'graft-trust',
    environment: 'node',
    include: ['src/**/*.test.ts'],
  },
});
