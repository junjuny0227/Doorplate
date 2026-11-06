import type { Locale, Messages } from '../i18n';
import { BREW, downloadUrl, REPO } from '../version';
import { CopyCommand } from './CopyCommand';
export function Install({ c, locale }: { c: Messages; locale: Locale }) {
  return (
    <section className="section" id="install" aria-labelledby="install-title">
      <h2 id="install-title">{c.sections.install}</h2>
      <p className="lead">{c.ui.requirements}</p>
      <div className="install">
        <div>
          <h3>Homebrew</h3>
          <CopyCommand command={BREW} c={c} />
          <div className="card download-card">
            <h3>Doorplate-{__APP_VERSION__}.zip</h3>
            <p>{c.ui.installNote}</p>
            <a className="button primary" href={downloadUrl(__APP_VERSION__)}>
              {c.ui.download}
            </a>
            <a href={`${downloadUrl(__APP_VERSION__)}.sha256`}>SHA-256</a>
          </div>
          <p className="footnote">
            <a href={`${REPO}/blob/main/README${locale === 'en' ? '' : `.${locale}`}.md`}>
              {c.ui.readme} ↗
            </a>
          </p>
        </div>
        <div>
          <h3>{c.ui.first}</h3>
          <p className="first-intro">{c.firstOpen.intro}</p>
          <ol className="launch">
            {c.firstOpen.steps.map((step, i) => (
              <li key={step}>
                <span className="step-number" aria-hidden="true">
                  {i + 1}
                </span>
                <p>{step}</p>
              </li>
            ))}
          </ol>
        </div>
      </div>
      <details className="terminal-alternative">
        <summary>{c.ui.quarantine}</summary>
        <CopyCommand command="xattr -dr com.apple.quarantine /Applications/Doorplate.app" c={c} />
        <p className="footnote">{c.firstOpen.quarantineExplanation}</p>
      </details>
    </section>
  );
}
