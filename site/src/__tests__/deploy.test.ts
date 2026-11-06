import { execFileSync, spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';

const roots: string[] = [];
afterEach(() => {
  for (const root of roots.splice(0)) rmSync(root, { recursive: true, force: true });
});
function fixture() {
  const root = mkdtempSync(join(tmpdir(), 'doorplate-site-test-'));
  roots.push(root);
  const pages = join(root, 'pages');
  const dist = join(root, 'dist');
  mkdirSync(pages);
  mkdirSync(dist);
  const git = (...args: string[]) =>
    execFileSync('git', ['-C', pages, ...args], { encoding: 'utf8' });
  git('init', '-q');
  git('config', 'user.name', 'Site test');
  git('config', 'user.email', 'site@example.invalid');
  const appcast = Buffer.from('<?xml version="1.0"?>\r\n<rss>signed feed bytes</rss>\n');
  writeFileSync(join(pages, 'appcast.xml'), appcast);
  writeFileSync(join(pages, 'stale.html'), 'old site');
  git('add', '--', 'appcast.xml', 'stale.html');
  git('commit', '-qm', 'Initial feed');
  writeFileSync(join(dist, 'index.html'), '<h1>Doorplate</h1>');
  writeFileSync(join(dist, '.nojekyll'), '');
  mkdirSync(join(dist, 'ko'));
  writeFileSync(join(dist, 'ko/index.html'), '한국어');
  return { pages, dist, appcast, git };
}
const script = new URL('../../scripts/stage-pages.mjs', import.meta.url);
describe('LEGACY Pages deployment', () => {
  it('replaces the site, stages additions and deletions, and leaves feed bytes and git intact', () => {
    const { pages, dist, appcast, git } = fixture();
    execFileSync(process.execPath, [script.pathname, dist, pages]);
    expect(readFileSync(join(pages, 'appcast.xml'))).toEqual(appcast);
    expect(readFileSync(join(pages, 'index.html'), 'utf8')).toContain('Doorplate');
    expect(git('diff', '--cached', '--name-status')).toContain('D\tstale.html');
    expect(git('diff', '--cached', '--name-status')).toContain('A\tko/index.html');
    expect(git('diff', '--cached', '--name-only')).not.toContain('appcast.xml');
    git('commit', '-qm', 'Deploy site');
    execFileSync(process.execPath, [script.pathname, dist, pages]);
    expect(git('diff', '--cached', '--name-only')).toBe('');
  });
  it('rejects output containing an appcast without touching the existing site', () => {
    const { pages, dist, appcast } = fixture();
    writeFileSync(join(dist, 'appcast.xml'), 'bad feed');
    expect(spawnSync(process.execPath, [script.pathname, dist, pages]).status).not.toBe(0);
    expect(readFileSync(join(pages, 'appcast.xml'))).toEqual(appcast);
    expect(readFileSync(join(pages, 'stale.html'), 'utf8')).toBe('old site');
  });
  it('requires an existing appcast and never creates one', () => {
    const { pages, dist } = fixture();
    rmSync(join(pages, 'appcast.xml'));
    expect(spawnSync(process.execPath, [script.pathname, dist, pages]).status).not.toBe(0);
    expect(readFileSync(join(pages, 'stale.html'), 'utf8')).toBe('old site');
  });
  it('keeps the site and appcast workflows serialized without a Pages source change', () => {
    const pages = readFileSync(
      new URL('../../../.github/workflows/pages.yml', import.meta.url),
      'utf8',
    );
    const appcast = readFileSync(
      new URL('../../../.github/workflows/appcast.yml', import.meta.url),
      'utf8',
    );
    expect(pages).toContain('group: appcast-gh-pages');
    expect(appcast).toContain('group: appcast-gh-pages');
    expect(pages).toContain('pages/builds');
    expect(pages).not.toContain('actions/deploy-pages');
    expect(pages).not.toContain('actions/configure-pages');
  });
});
