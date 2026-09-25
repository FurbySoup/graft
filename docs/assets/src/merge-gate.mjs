// Generates the animated merge-gate illustration (light + dark) as SVGs.
// Pure CSS @keyframes, 9 s loop, three 3 s scenarios. No script, no SMIL.
// Usage: node docs/assets/src/merge-gate.mjs   (zero dependencies, deterministic)
//
// Faithful to docs/SPEC.md §6.2 / ops/stats.yaml: an edit merges only if the
// exact permutation test on paired per-case pass-rate deltas is significant at
// alpha = 0.05 (Benjamini-Hochberg corrected) AND the median delta >= +10pp.
import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const OUT = join(dirname(fileURLToPath(import.meta.url)), '..');
const FONT = 'system-ui,-apple-system,&quot;Segoe UI&quot;,Helvetica,Arial,sans-serif';

const THEMES = {
  light: { fg: '#1f2328', muted: '#59636e', line: '#d1d9e0', pass: '#1a7f37', fail: '#cf222e', hl: '#0969da' },
  dark: { fg: '#e6edf3', muted: '#9198a1', line: '#3d444d', pass: '#3fb950', fail: '#f85149', hl: '#4493f8' },
};

const CYCLE = 9; // seconds
const SCENARIOS = [
  { label: 'Scenario 1 of 3 — significant, but Δ below the floor', p: true, d: false, chip: 'Significant only → reject' },
  { label: 'Scenario 2 of 3 — large Δ, but not significant', p: false, d: true, chip: 'Large Δ only → reject' },
  { label: 'Scenario 3 of 3 — significant AND Δ at or above the floor', p: true, d: true, chip: 'Both pass → merge' },
];

// Keyframes: hidden, fade in at `a`, hold, fade out ending at `b` (seconds).
const keyframes = new Map();
function kf(a, b) {
  const name = `k${Math.round(a * 10)}_${Math.round(b * 10)}`;
  if (!keyframes.has(name)) {
    const pc = (s) => `${+((s / CYCLE) * 100).toFixed(2)}%`;
    keyframes.set(
      name,
      `@keyframes ${name}{0%,${pc(a)}{opacity:0}${pc(a + 0.3)},${pc(b - 0.3)}{opacity:1}${pc(b)},100%{opacity:0}}`,
    );
  }
  return name;
}

function mark(ok, cx, cy, t) {
  const c = ok ? t.pass : t.fail;
  const glyph = ok
    ? `<path d="M${cx - 7} ${cy}l5 5l9-10" stroke="${c}" stroke-width="3" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`
    : `<path d="M${cx - 6} ${cy - 6}l12 12M${cx + 6} ${cy - 6}l-12 12" stroke="${c}" stroke-width="3" stroke-linecap="round"/>`;
  return `<circle cx="${cx}" cy="${cy}" r="15" fill="none" stroke="${c}" stroke-width="2"/>${glyph}<text x="${cx - 26}" y="${cy + 5}" text-anchor="end" font-size="14" font-weight="600" fill="${c}">${ok ? 'pass' : 'fail'}</text>`;
}

function svg(t) {
  keyframes.clear();
  const layers = [];
  SCENARIOS.forEach((s, i) => {
    const t0 = i * 3;
    const end = t0 + 2.9;
    const last = i === SCENARIOS.length - 1;
    const cls = (a) => `a ${kf(a, end)}${last ? '' : ' h'}`;
    const ok = s.p && s.d;
    const oc = ok ? t.pass : t.fail;
    layers.push(
      `<g class="${cls(t0 + 0.1)}"><text x="24" y="66" font-size="15" fill="${t.muted}">${s.label}</text>` +
        `<rect x="${24 + i * 254}" y="214" width="244" height="34" rx="17" fill="${t.hl}" fill-opacity="0.12" stroke="${t.hl}" stroke-width="2"/></g>`,
      `<g class="${cls(t0 + 0.5)}">${mark(s.p, 466, 111, t)}</g>`,
      `<g class="${cls(t0 + 1.1)}">${mark(s.d, 466, 175, t)}</g>`,
      `<g class="${cls(t0 + 1.7)}"><rect x="614" y="113" width="162" height="60" rx="10" fill="${oc}" fill-opacity="0.12" stroke="${oc}" stroke-width="2"/>` +
        `<text x="695" y="151" text-anchor="middle" font-size="22" font-weight="700" letter-spacing="1" fill="${oc}">${ok ? 'MERGE' : 'REJECT'}</text></g>`,
    );
  });

  const chips = SCENARIOS.map(
    (s, i) =>
      `<rect x="${24 + i * 254}" y="214" width="244" height="34" rx="17" fill="none" stroke="${t.line}"/>` +
      `<text x="${146 + i * 254}" y="236" text-anchor="middle" font-size="14" fill="${t.fg}">${s.chip}</text>`,
  ).join('');

  const css =
    `.a{animation-duration:${CYCLE}s;animation-iteration-count:infinite;animation-timing-function:ease-in-out}` +
    `.h{opacity:0}` +
    [...new Set(layers.map((l) => l.match(/class="a (k[\d_]+)/)[1]))].map((n) => `.${n}{animation-name:${n}}`).join('') +
    [...keyframes.values()].join('') +
    `@media (prefers-reduced-motion: reduce){*{animation:none !important}}`;

  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 300" width="800" height="300" role="img" aria-labelledby="t d">
<title id="t">Graft merge gate: both checks must pass</title>
<desc id="d">Design illustration of the planned merge gate, not yet implemented. A skill edit merges only if a permutation test on paired canary results is significant after Benjamini-Hochberg correction AND the median improvement is at least 10 percentage points. Three looping scenarios: significant but below the effect floor is rejected; a large effect that is not significant is rejected; only when both checks pass does the edit merge.</desc>
<style>${css}</style>
<g font-family="${FONT}">
<text x="24" y="36" font-size="19" font-weight="700" fill="${t.fg}">Merge gate — a skill edit merges only if BOTH checks pass</text>
<g fill="none" stroke="${t.line}" stroke-width="1.5">
<rect x="24" y="86" width="470" height="50" rx="8"/>
<rect x="24" y="150" width="470" height="50" rx="8"/>
<path d="M494 111h30l18 26M494 175h30l18-26M602 143h12"/>
<circle cx="572" cy="143" r="30"/>
</g>
<text x="42" y="117" font-size="16" fill="${t.fg}">Permutation test  p &lt; α (BH, α = 0.05)</text>
<text x="42" y="181" font-size="16" fill="${t.fg}">Median Δ ≥ +10pp  (effect floor)</text>
<text x="572" y="148" text-anchor="middle" font-size="14" font-weight="700" fill="${t.fg}">AND</text>
${chips}
${layers.join('\n')}
<text x="24" y="284" font-size="13" font-style="italic" fill="${t.muted}">Design illustration — gate not yet implemented</text>
</g>
</svg>
`;
}

for (const [name, theme] of Object.entries(THEMES)) {
  writeFileSync(join(OUT, `merge-gate-${name}.svg`), svg(theme));
}
