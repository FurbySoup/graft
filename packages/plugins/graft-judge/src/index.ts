/**
 * graft-judge — Cordis plugin for DeepSeek Harness (dsh).
 *
 * Phase 0: stub — logs mount/unmount only. No other behaviour.
 *
 * Shape follows the dsh module-namespace plugin convention (`export const name`
 * + `export function apply(ctx, config)`), as used by e.g.
 * @deepseek-ai/dsh-session-title-first-prompt-llm and dsh-goal-round-driver.
 * No `inject` (only the built-in logger is used) and no `Config` (no options yet).
 */
import type { Context } from '@deepseek-ai/cordis';

export const name = 'graft-judge';

export function apply(ctx: Context): void {
  const logger = ctx.logger(name);
  logger.info('mounted');
  ctx.effect(() => () => {
    logger.info('unmounted');
  }, name + '.lifecycle');
}
