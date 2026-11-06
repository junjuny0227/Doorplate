import { expect, test } from 'vitest';

// An undefined var(--x) silently resolves to nothing, so a renamed token would drop colors
// from the site without any build error.
const css = import.meta.glob<string>('../styles/*.css', {
  query: '?raw',
  import: 'default',
  eager: true,
});
const tokens = css['../styles/tokens.css'];
const site = css['../styles/site.css'];

const defined = (s: string) => new Set([...s.matchAll(/(--[\w-]+)\s*:/g)].map((m) => m[1]));
const used = (s: string) => new Set([...s.matchAll(/var\((--[\w-]+)/g)].map((m) => m[1]));

test('every CSS variable the site uses is defined', () => {
  const names = new Set(Object.values(css).flatMap((s) => [...defined(s)]));
  const missing = Object.values(css)
    .flatMap((s) => [...used(s)])
    .filter((n) => !names.has(n));
  expect(tokens).toBeTruthy();
  expect(missing).toEqual([]);
});

test("the site imports Repot's macOS tokens and keeps them intact", () => {
  expect(site).toContain('@import "./tokens.css"');
  expect(tokens).toContain("Mirrors Repot's macOS palette");
  // Repot's system palette, unchanged in the copy.
  for (const token of [
    '--accent: #007aff',
    '--window: #f5f5f5',
    '--window: #1e1e1e',
    '--group: #2a2a2a',
  ])
    expect(tokens).toContain(token);
});

test('header translucency has an opaque fallback and motion follows the system setting', () => {
  expect(site).toMatch(
    /prefers-reduced-transparency: reduce\)\s*\{\s*\.site-header\s*\{[^}]*backdrop-filter: none/,
  );
  expect(tokens).toMatch(/prefers-reduced-motion: reduce\)\s*\{\s*:root\s*\{\s*--motion: 0ms/);
  expect(site).toContain('@media (prefers-reduced-motion: no-preference)');
});
