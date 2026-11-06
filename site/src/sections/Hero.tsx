import { BASE, type Messages } from '../i18n';
import { BREW, downloadUrl } from '../version';
import { CopyCommand } from './CopyCommand';
export function Hero({ c }: { c: Messages }) {
  return (
    <section className="hero" id="top" aria-labelledby="hero-title">
      <img
        className="hero-icon"
        src={`${BASE}generated/AppIcon.svg`}
        width={128}
        height={128}
        alt=""
      />
      <h1 id="hero-title">Doorplate</h1>
      <p className="tagline">{c.tagline}</p>
      <p className="pitch">{c.pitch}</p>
      <div className="downloads">
        <a className="button primary large" href={downloadUrl(__APP_VERSION__)}>
          <span aria-hidden="true">↓</span>
          {c.ui.download}
        </a>
        <CopyCommand command={BREW} c={c} />
      </div>
      <p className="meta">
        v{__APP_VERSION__} · {c.ui.requirements}
      </p>
      <p className="beta">
        <strong>{c.ui.beta}.</strong> {c.ui.betaNote} <a href="#install">{c.ui.first} →</a>
      </p>
      <figure className="hero-shot">
        <img
          src={`${BASE}generated/menu.png`}
          width={565}
          height={516}
          alt={c.screenshots.menuAlt}
          fetchPriority="high"
        />
      </figure>
    </section>
  );
}
