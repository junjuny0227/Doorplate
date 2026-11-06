import { readFileSync } from 'node:fs';
import react from '@vitejs/plugin-react';
import { defineConfig, type Plugin } from 'vitest/config';
import { headTags, noscript } from './src/head.ts';
import { isLocale, LOCALES } from './src/i18n.ts';
import { marketingVersion } from './src/version.ts';

function localePages(): Plugin {
  return {
    name: 'doorplate-locale-pages',
    transformIndexHtml: {
      order: 'pre',
      handler(html) {
        const lang = html.match(/<html lang="([^"]+)"/)?.[1];
        if (!isLocale(lang)) throw new Error(`Unknown page language: ${lang}`);
        return html
          .replace('<!-- doorplate:head -->', headTags(lang))
          .replace('<!-- doorplate:noscript -->', noscript(lang));
      },
    },
  };
}

export default defineConfig({
  base: '/Doorplate/',
  define: {
    __APP_VERSION__: JSON.stringify(
      marketingVersion(readFileSync(new URL('../project.yml', import.meta.url), 'utf8')),
    ),
  },
  plugins: [react(), localePages()],
  build: {
    rollupOptions: {
      input: Object.fromEntries(
        LOCALES.map((l) => [l.code, l.code === 'en' ? 'index.html' : `${l.code}/index.html`]),
      ),
    },
  },
  server: { port: 1431, strictPort: true },
  preview: { port: 1431, strictPort: true },
});
