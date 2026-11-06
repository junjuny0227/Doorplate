import { useEffect, useRef } from 'react';
import { LOCALES, type Locale, localeInfo, type Messages } from '../i18n';
export function LanguageLinks({ locale }: { locale: Locale }) {
  return (
    <ul className="language-links">
      {LOCALES.map((l) => (
        <li key={l.code}>
          <a
            href={l.path}
            hrefLang={l.code}
            lang={l.code}
            aria-current={l.code === locale ? 'page' : undefined}
          >
            {l.name}
          </a>
        </li>
      ))}
    </ul>
  );
}
export function LanguageMenu({ locale, c }: { locale: Locale; c: Messages }) {
  const ref = useRef<HTMLDetailsElement>(null);
  useEffect(() => {
    const close = (event: Event) => {
      const menu = ref.current;
      if (
        menu?.open &&
        (event instanceof KeyboardEvent
          ? event.key === 'Escape'
          : !menu.contains(event.target as Node))
      )
        menu.open = false;
    };
    document.addEventListener('click', close);
    document.addEventListener('keydown', close);
    return () => {
      document.removeEventListener('click', close);
      document.removeEventListener('keydown', close);
    };
  }, []);
  return (
    <details className="language-menu" ref={ref}>
      <summary aria-label={`${c.ui.language}: ${localeInfo(locale).name}`}>
        {localeInfo(locale).name}
        <span aria-hidden="true">⌄</span>
      </summary>
      <div className="language-popover">
        <LanguageLinks locale={locale} />
      </div>
    </details>
  );
}
