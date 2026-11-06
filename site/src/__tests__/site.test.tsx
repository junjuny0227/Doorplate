import { readFileSync } from 'node:fs';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { App } from '../App';
import { headTags, pageUrl } from '../head';
import { BASE, isLocale, LOCALES, messagesFor } from '../i18n';
import { BREW, downloadUrl, marketingVersion } from '../version';

function keys(value: unknown, prefix = ''): string[] {
  if (typeof value !== 'object' || value === null) return [prefix];
  return Object.entries(value)
    .flatMap(([key, child]) => keys(child, `${prefix}.${key}`))
    .sort();
}

describe('locale pages', () => {
  it('contains exactly the four app locales with complete, identical keys', () => {
    expect(LOCALES.map((l) => l.code)).toEqual(['en', 'ko', 'ja', 'zh-Hans']);
    for (const l of LOCALES) {
      const c = messagesFor(l.code);
      expect(keys(c)).toEqual(keys(messagesFor('en')));
      expect(c.features).toHaveLength(9);
      expect(c.firstOpen.steps).toHaveLength(3);
      expect(c.stacks.map(([stack]) => stack)).toEqual([
        'Node',
        'JVM',
        'Rust',
        'Python',
        'Ruby',
        'Docker',
      ]);
      expect(c.pitch).not.toContain('**');
    }
    expect(isLocale('zh-Hant')).toBe(false);
    expect(isLocale(undefined)).toBe(false);
  });
  for (const locale of LOCALES) {
    it(`renders all sections, download, image alternatives, and language links in ${locale.code}`, () => {
      const c = messagesFor(locale.code);
      const html = renderToStaticMarkup(<App locale={locale.code} />);
      expect(html).toContain('<main id="main">');
      expect(html).toContain('<header');
      expect(html).toContain('<footer');
      expect(html.match(/<h1 /g)).toHaveLength(1);
      expect(html.match(/<h2 /g)).toHaveLength(5);
      expect(html).toContain('href="#main"');
      expect(html).toContain(downloadUrl(__APP_VERSION__));
      expect(html).toContain(BREW);
      expect(html).toContain('role="status"');
      for (const image of ['menu', 'submenu', 'docker'])
        expect(html).toContain(`${BASE}generated/${image}.png`);
      expect(html).not.toContain('alt="undefined"');
      for (const l of LOCALES) expect(html).toContain(`href="${l.path}"`);
      expect(html).toContain('Apache-2.0');
      expect(html).toContain('scope="row"');
      expect(html).toContain(c.ui.first);
    });
    it(`emits localized static metadata and every alternate for ${locale.code}`, () => {
      const tags = headTags(locale.code);
      expect(tags).toContain(`<link rel="canonical" href="${pageUrl(locale.code)}"`);
      expect(tags).toContain('name="description"');
      expect(tags).toContain('<title>Doorplate');
      for (const l of LOCALES)
        expect(tags).toContain(`hreflang="${l.code}" href="${pageUrl(l.code)}"`);
      expect(tags).toContain(`hreflang="x-default" href="${pageUrl('en')}"`);
    });
  }
});

describe('release downloads', () => {
  it('reads the actual project version and uses the exact versioned zip', () => {
    const project = readFileSync(new URL('../../../project.yml', import.meta.url), 'utf8');
    expect(__APP_VERSION__).toBe(marketingVersion(project));
    expect(downloadUrl(__APP_VERSION__)).toBe(
      `https://github.com/junjuny0227/Doorplate/releases/download/v${__APP_VERSION__}/Doorplate-${__APP_VERSION__}.zip`,
    );
  });
  it('fails closed if the project has no valid marketing version', () => {
    expect(() => marketingVersion('name: Doorplate')).toThrow();
    expect(() => marketingVersion('    MARKETING_VERSION: invalid')).toThrow();
  });
});
