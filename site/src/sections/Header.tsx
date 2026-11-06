import { BASE, type Locale, type Messages } from '../i18n';
import { REPO } from '../version';
import { LanguageMenu } from './LanguageMenu';
export function Header({ locale, c }: { locale: Locale; c: Messages }) {
  return (
    <header className="site-header">
      <a className="skip-link" href="#main">
        {c.ui.skip}
      </a>
      <div className="bar">
        <a className="brand" href="#top">
          <img src={`${BASE}generated/AppIcon.svg`} width={32} height={32} alt="" />
          Doorplate
        </a>
        <nav aria-label="Doorplate">
          <ul>
            <li className="section-link">
              <a href="#features">{c.sections.features}</a>
            </li>
            <li className="section-link">
              <a href="#install">{c.sections.install}</a>
            </li>
            <li>
              <LanguageMenu locale={locale} c={c} />
            </li>
            <li>
              <a href={REPO}>GitHub ↗</a>
            </li>
          </ul>
        </nav>
      </div>
    </header>
  );
}
