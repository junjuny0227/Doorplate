import { type Locale, messagesFor } from './i18n';
import { Features } from './sections/Features';
import { Footer } from './sections/Footer';
import { Header } from './sections/Header';
import { Hero } from './sections/Hero';
import { Install } from './sections/Install';
import { Principles } from './sections/Principles';
import { Screenshot } from './sections/Screenshot';
import { Tools } from './sections/Tools';
export function App({ locale }: { locale: Locale }) {
  const c = messagesFor(locale);
  return (
    <>
      <Header locale={locale} c={c} />
      <main id="main">
        <Hero c={c} />
        <Features c={c} />
        <Screenshot c={c} />
        <Tools c={c} />
        <Principles c={c} />
        <Install c={c} locale={locale} />
      </main>
      <Footer c={c} locale={locale} />
    </>
  );
}
