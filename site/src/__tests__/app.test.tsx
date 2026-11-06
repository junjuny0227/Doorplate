import { renderToStaticMarkup } from 'react-dom/server';
import { expect, test } from 'vitest';
import { App } from '../App';
import { VERSION } from '../content';
import { LOCALES, type Locale } from '../i18n';
import { LocaleSuggestion } from '../sections/LocaleSuggestion';
import { BREW } from '../version';

const render = (locale: Locale = 'en') =>
  renderToStaticMarkup(<App locale={locale} languages={['ko-KR']} />);
const codes = LOCALES.map((l) => l.code);

test('one h1, and every section is titled by an h2, in every language', () => {
  for (const code of codes) {
    const html = render(code);
    expect(html.match(/<h1[\s>]/g), code).toHaveLength(1);
    const sections = html.match(/<section[^>]*aria-labelledby="([^"]+)"/g) ?? [];
    expect(sections.length, code).toBe(6);
    for (const s of sections) {
      const id = s.match(/aria-labelledby="([^"]+)"/)![1];
      expect(html).toMatch(new RegExp(`<h[12] id="${id}"`));
    }
    expect(html).toContain('<main id="main">');
    expect(html).toContain('href="#main"');
  }
});

test('every image has alt text, and the three app captures are shown', () => {
  for (const code of codes) {
    const html = render(code);
    const imgs = html.match(/<img[^>]*>/g) ?? [];
    expect(imgs.length).toBeGreaterThan(0);
    for (const img of imgs) expect(img).toMatch(/ alt="/);
    for (const name of ['menu', 'submenu', 'docker'])
      expect(html).toContain(`src="/Doorplate/generated/${name}.png"`);
    expect(html).not.toContain('alt="undefined"');
  }
});

test("download links all point at the current version's release assets, in every language", () => {
  for (const code of codes) {
    const hrefs = [...render(code).matchAll(/href="([^"]*releases\/download[^"]*)"/g)].map(
      (m) => m[1],
    );
    expect(hrefs).toContain(
      `https://github.com/junjuny0227/Doorplate/releases/download/v${VERSION}/Doorplate-${VERSION}.zip`,
    );
    for (const h of hrefs)
      expect(
        h.startsWith(`https://github.com/junjuny0227/Doorplate/releases/download/v${VERSION}/`),
        `${code} ${h}`,
      ).toBe(true);
  }
});

test('every page links to every language, marks its own, and asks for translation help', () => {
  for (const { code } of LOCALES) {
    const html = render(code);
    for (const other of LOCALES)
      expect(html).toContain(`href="${other.path}" hrefLang="${other.code}" lang="${other.code}"`);
    expect(
      html.match(new RegExp(`hrefLang="${code}" lang="${code}" aria-current="page"`, 'g')),
    ).toHaveLength(2); // header menu and footer
    expect(html).toContain(
      'href="https://github.com/junjuny0227/Doorplate/issues/new?title=Translation%3A%20"',
    );
  }
});

test('pages render their own language and keep commands untranslated', () => {
  expect(render('ko')).toContain('설치와 첫 실행');
  expect(render('ja')).toContain('インストールと初回起動');
  expect(render('zh-Hans')).toContain('安装与首次启动');
  for (const code of codes) {
    const html = render(code);
    expect(html).toContain(BREW);
    expect(html).toContain('xattr -dr com.apple.quarantine /Applications/Doorplate.app');
    expect(html).toContain('Apache-2.0');
  }
});

test('no suggestion is part of the static page; the banner speaks the suggested language', () => {
  // The suggestion depends on the browser, so it appears only after the first client render.
  expect(render('en')).not.toContain('locale-suggestion');
  const banner = renderToStaticMarkup(<LocaleSuggestion locale="ko" onClose={() => {}} />);
  expect(banner).toContain('lang="ko"');
  expect(banner).toContain('이 페이지는 한국어로도 볼 수 있습니다.');
  expect(banner).toContain('href="/Doorplate/ko/"');
  expect(banner).toContain('<button');
});
