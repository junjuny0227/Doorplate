// Sync the site next to the Sparkle feed. Never remove or write appcast.xml.
import { execFileSync } from 'node:child_process';
import { cpSync, lstatSync, readdirSync, realpathSync, rmSync } from 'node:fs';
import { resolve } from 'node:path';

const [sourceArg, pagesArg] = process.argv.slice(2);
if (!sourceArg || !pagesArg) throw new Error('Usage: stage-pages.mjs <dist> <gh-pages worktree>');
const source = realpathSync(resolve(sourceArg));
const pages = realpathSync(resolve(pagesArg));
if (source === pages || source.startsWith(`${pages}/`) || pages.startsWith(`${source}/`)) {
  throw new Error('Source and Pages worktree must not overlap');
}
const git = (...args) => execFileSync('git', ['-C', pages, ...args], { encoding: 'utf8' });
if (resolve(git('rev-parse', '--show-toplevel').trim()) !== pages)
  throw new Error('Not a worktree root');
if (!lstatSync(`${pages}/appcast.xml`).isFile())
  throw new Error('The existing appcast must be a regular file');
const entries = readdirSync(source);
if (
  entries.includes('appcast.xml') ||
  entries.includes('.git') ||
  !entries.includes('index.html') ||
  !entries.includes('.nojekyll')
) {
  throw new Error('Invalid site output; refusing to deploy');
}
const before = git('hash-object', '--no-filters', 'appcast.xml').trim();
const tracked = git('ls-files', '-z')
  .split('\0')
  .filter((p) => p && p !== 'appcast.xml');
for (const entry of readdirSync(pages)) {
  if (entry !== '.git' && entry !== 'appcast.xml')
    rmSync(`${pages}/${entry}`, { recursive: true, force: true });
}
for (const entry of entries) cpSync(`${source}/${entry}`, `${pages}/${entry}`, { recursive: true });
const after = git('hash-object', '--no-filters', 'appcast.xml').trim();
if (before !== after) throw new Error('Appcast changed; refusing to stage');
// Explicit paths include removed old site files, never the appcast or whole worktree.
const paths = [...new Set([...tracked, ...entries])];
git('add', '--', ...paths);
if (git('diff', '--cached', '--name-only', '--', 'appcast.xml').trim())
  throw new Error('Appcast was staged unexpectedly');
console.log(`Appcast preserved: ${before}`);
