import { BASE, type Locale, type Messages } from '../i18n';
import { REPO } from '../version';
import { LanguageLinks } from './LanguageMenu';
export function Footer({ c, locale }: { c: Messages; locale: Locale }) {
  return (
    <footer className="site-footer">
      <div className="bar">
        <div className="footer-brand">
          <img src={`${BASE}generated/AppIcon.svg`} width={32} height={32} alt="" />
          <span>
            <strong>Doorplate</strong>
            <br />
            <a href={`${REPO}/blob/main/LICENSE`}>Apache-2.0</a>
          </span>
        </div>
        <nav aria-label="Doorplate links">
          <ul>
            <li>
              <a href={REPO}>GitHub</a>
            </li>
            <li>
              <a href={`${REPO}/releases`}>{c.ui.releases}</a>
            </li>
            <li>
              <a href={`${REPO}/blob/main/docs/specs/2026-11-04-doorplate-mvp-design.md`}>
                {c.ui.design}
              </a>
            </li>
          </ul>
        </nav>
      </div>
      <div className="bar footer-languages">
        <nav aria-label={c.ui.language}>
          <LanguageLinks locale={locale} />
        </nav>
      </div>
    </footer>
  );
}
