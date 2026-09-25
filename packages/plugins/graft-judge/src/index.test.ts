import { Context, type Message } from '@deepseek-ai/cordis';
import { describe, expect, it } from 'vitest';
import * as plugin from './index.js';

describe('graft-judge stub plugin', () => {
  it('logs on mount and on dispose', async () => {
    const root = new Context();
    const messages: Message[] = [];
    root.logger.exporter({
      export(message: Message): void {
        if (message.name === plugin.name) messages.push(message);
      },
    });

    const fiber = await root.plugin(plugin);
    expect(messages.map((m) => [m.type, m.args[0]])).toEqual([['info', 'mounted']]);

    await fiber.dispose();
    expect(messages.map((m) => [m.type, m.args[0]])).toEqual([
      ['info', 'mounted'],
      ['info', 'unmounted'],
    ]);
  });
});
