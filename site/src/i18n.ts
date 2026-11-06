// Dependency-free localization for the site: one JSON file per locale in ./locales,
// typed from en.json. Each locale is a static page; the URL, not the browser, picks it.
// Import attributes and extensions let vite.config.ts load this file natively too.
import en from './locales/en.json' with { type: 'json' };
import ja from './locales/ja.json' with { type: 'json' };
import ko from './locales/ko.json' with { type: 'json' };
import zhHans from './locales/zh-Hans.json' with { type: 'json' };

type Widen<T> = T extends string
  ? string
  : T extends readonly (infer U)[]
    ? Widen<U>[]
    : { [K in keyof T]: Widen<T[K]> };
/** Shape of every locale file. Missing keys in a locale file are a type error. */
export type Messages = Widen<typeof en>;

// Adding a language: add its JSON file and its page (<code>/index.html), import it here, and list it in LOCALES.
const MESSAGES = { en, ko, ja, 'zh-Hans': zhHans } satisfies Record<string, Messages>;
export type Locale = keyof typeof MESSAGES;

export const SITE_ORIGIN = 'https://junjuny0227.github.io';
export const BASE = '/Doorplate/';

/** Each language is named in itself. English is the default page at the site root. */
export const LOCALES: readonly { code: Locale; name: string; path: string }[] = [
  { code: 'en', name: 'English', path: BASE },
  { code: 'ko', name: '한국어', path: `${BASE}ko/` },
  { code: 'ja', name: '日本語', path: `${BASE}ja/` },
  { code: 'zh-Hans', name: '简体中文', path: `${BASE}zh-Hans/` },
];

export const isLocale = (value: unknown): value is Locale =>
  typeof value === 'string' && Object.hasOwn(MESSAGES, value);
export const messagesFor = (locale: Locale): Messages => MESSAGES[locale];
// biome-ignore lint/style/noNonNullAssertion: LOCALES lists every Locale (checked by i18n.test.ts).
export const localeInfo = (locale: Locale) => LOCALES.find((l) => l.code === locale)!;
