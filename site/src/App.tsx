import { useEffect, useMemo, useState } from 'react';
import { ContentContext, content } from './content';
import { type Locale, STORAGE_KEY, suggestion } from './i18n';
import { Features } from './sections/Features';
import { Footer } from './sections/Footer';
import { Header } from './sections/Header';
import { Hero } from './sections/Hero';
import { HowItWorks } from './sections/HowItWorks';
import { Install } from './sections/Install';
import { LocaleSuggestion } from './sections/LocaleSuggestion';
import { Principles } from './sections/Principles';
import { Tools } from './sections/Tools';

function savedLocale(): string | null {
  try {
    return localStorage.getItem(STORAGE_KEY);
  } catch {
    return null; // Storage unavailable: behave as if nothing was chosen.
  }
}

export function App({
  locale = 'en',
  languages = globalThis.navigator?.languages,
}: {
  locale?: Locale;
  languages?: readonly string[];
}) {
  const c = useMemo(() => content(locale), [locale]);
  // Decided after the first paint: the static HTML never depends on the visitor's browser languages.
  const [suggested, setSuggested] = useState<Locale | null>(null);

  useEffect(() => {
    setSuggested(suggestion(locale, savedLocale(), languages ?? []));
  }, [locale, languages]);

  return (
    <ContentContext.Provider value={c}>
      <Header />
      {suggested !== null && (
        <LocaleSuggestion locale={suggested} onClose={() => setSuggested(null)} />
      )}
      <main id="main">
        <Hero />
        <HowItWorks />
        <Features />
        <Principles />
        <Tools />
        <Install />
      </main>
      <Footer />
    </ContentContext.Provider>
  );
}
