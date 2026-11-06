// Everything the site shows, for one locale. Sentences come from ./locales/<locale>.json;
// links, product and stack names, and terminal commands stay here because they are not translated.
// Facts come from README.md and the MVP spec only. Same shape as Repot's site (apps/site/src/content.ts).
import { createContext, useContext } from 'react';
import { BASE, format, type Locale, messagesFor } from './i18n';
import type { FeatureKey, PrincipleKey, StackKey } from './icons';
import { BREW, downloadUrl, REPO } from './version';

export const VERSION: string = __APP_VERSION__;
export const RELEASE_URL = `${REPO}/releases/tag/v${VERSION}`;
export const RELEASES_URL = `${REPO}/releases`;
export const QUARANTINE = 'xattr -dr com.apple.quarantine /Applications/Doorplate.app';
export const ICON = `${BASE}generated/AppIcon.svg`;

export function content(locale: Locale) {
  const m = messagesFor(locale);
  const features: FeatureKey[] = [
    'names',
    'docker',
    'noise',
    'system',
    'stop',
    'live',
    'updates',
    'languages',
  ];
  const principles: PrincipleKey[] = ['local', 'admin', 'network', 'telemetry'];
  const stacks: [StackKey, string][] = [
    ['node', 'Node'],
    ['jvm', 'JVM'],
    ['rust', 'Rust'],
    ['python', 'Python'],
    ['ruby', 'Ruby'],
    ['docker', 'Docker'],
  ];
  const zip = `Doorplate-${VERSION}.zip`;
  return {
    locale,
    // Space between sentences: Japanese and Chinese run sentences together after 。
    gap: locale === 'ja' || locale === 'zh-Hans' ? '' : ' ',
    name: 'Doorplate',
    tagline: m.tagline,
    pitch: m.pitch,
    skip: m.skip,
    nav: [
      { href: '#how', label: m.nav.how },
      { href: '#features', label: m.nav.features },
      { href: '#principles', label: m.nav.principles },
      { href: '#tools', label: m.nav.tools },
      { href: '#install', label: m.nav.install },
    ],
    github: 'GitHub',
    sectionsNav: m.sectionsNav,
    projectNav: m.projectNav,
    backToTop: m.backToTop,
    language: m.language,
    copy: m.copy,
    brew: BREW,

    hero: {
      ...m.hero,
      downloadUrl: downloadUrl(VERSION),
      version: format(m.hero.version, { version: VERSION }),
    },

    how: {
      title: m.how.title,
      lead: m.how.lead,
      steps: [m.how.steps.open, m.how.steps.read, m.how.steps.act],
      screenshotAlt: m.how.screenshotAlt,
      dockerAlt: m.how.dockerAlt,
    },

    features: {
      title: m.features.title,
      items: features.map((key) => ({ key, ...m.features.items[key] })),
    },

    principles: {
      title: m.principles.title,
      items: principles.map((key) => ({ key, ...m.principles.items[key] })),
    },

    tools: {
      title: m.tools.title,
      groups: stacks.map(([key, name]) => ({ key, name, servers: m.tools.servers[key] })),
      note: m.tools.note,
    },

    install: {
      ...m.install,
      files: [
        { id: 'zip', label: m.install.universal, file: zip, url: downloadUrl(VERSION) },
        {
          id: 'sha256',
          label: m.install.checksum,
          file: `${zip}.sha256`,
          url: `${downloadUrl(VERSION)}.sha256`,
        },
      ],
      downloadFile: (file: string) => format(m.install.downloadFile, { file }),
      quarantine: QUARANTINE,
      guideUrl: `${REPO}/blob/main/README${locale === 'en' ? '' : `.${locale}`}.md`,
    },

    footer: {
      summary: m.footer.summary,
      links: [
        { href: REPO, label: 'GitHub' },
        { href: RELEASES_URL, label: m.footer.links.releases },
        { href: `${REPO}/blob/main/LICENSE`, label: m.footer.links.license },
      ],
      languages: m.footer.languages,
      translate: {
        href: `${REPO}/issues/new?title=${encodeURIComponent('Translation: ')}`,
        label: m.footer.translate,
      },
    },
  };
}

export type Content = ReturnType<typeof content>;
export const ContentContext = createContext<Content>(content('en'));
export const useContent = (): Content => useContext(ContentContext);
