// Generates the Graft wordmark (light + dark) as static SVGs.
// Usage: node docs/assets/src/wordmark.mjs   (zero dependencies, deterministic)
import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const OUT = join(dirname(fileURLToPath(import.meta.url)), '..');
const FONT = 'system-ui,-apple-system,&quot;Segoe UI&quot;,Helvetica,Arial,sans-serif';

const THEMES = {
  light: { fg: '#1f2328', muted: '#59636e', stock: '#6e5a45', scion: '#1a7f37', band: '#9a6700' },
  dark: { fg: '#e6edf3', muted: '#9198a1', stock: '#b89f86', scion: '#3fb950', band: '#d29922' },
};

function svg(t) {
  // Motif: a rootstock stem cut at the top, a scion inserted into the cleft,
  // and a binding band at the union. Strokes only; no background fills.
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 160" width="800" height="160" role="img" aria-labelledby="t d">
<title id="t">Graft</title>
<desc id="d">Graft wordmark: a scion joined onto a rootstock, with the tagline "Skill self-improvement without self-corruption".</desc>
<g fill="none" stroke-linecap="round" stroke-linejoin="round">
<path d="M72 140V86" stroke="${t.stock}" stroke-width="10"/>
<path d="M60 146h24" stroke="${t.stock}" stroke-width="4"/>
<path d="M72 92L82 28" stroke="${t.scion}" stroke-width="6"/>
<path d="M80 42c14-12 28-12 36-4c-10 8-24 10-36 4z" stroke="${t.scion}" stroke-width="3"/>
<path d="M78 56c-12-10-24-10-30-4c8 7 20 9 30 4z" stroke="${t.scion}" stroke-width="3"/>
<path d="M63 90l18 6M63 99l18 6" stroke="${t.band}" stroke-width="3"/>
</g>
<text x="138" y="96" font-family="${FONT}" font-size="84" font-weight="700" letter-spacing="-1" fill="${t.fg}">graft</text>
<text x="141" y="138" font-family="${FONT}" font-size="22" fill="${t.muted}">Skill self-improvement without self-corruption</text>
</svg>
`;
}

for (const [name, theme] of Object.entries(THEMES)) {
  writeFileSync(join(OUT, `graft-wordmark-${name}.svg`), svg(theme));
}
