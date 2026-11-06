import { ICON, RELEASE_URL, useContent } from '../content';
import { DownloadArrow, WarningTriangle } from '../icons';
import { CopyCommand } from './CopyCommand';
import { Screenshot } from './Screenshot';

export function Hero() {
  const C = useContent();
  return (
    <section className="hero" id="top" aria-labelledby="hero-title">
      <img className="hero-icon" src={ICON} alt="" width={128} height={128} />
      <h1 id="hero-title">{C.name}</h1>
      <p className="tagline">
        <strong>{C.tagline}</strong>
        {C.gap}
        {C.pitch}
      </p>
      <div className="downloads">
        <div className="button-row">
          <a className="button primary large" href={C.hero.downloadUrl}>
            <DownloadArrow />
            {C.hero.download}
          </a>
        </div>
        <p className="hint">{C.hero.fileHint}</p>
        <div className="hero-brew">
          <p className="download-title">{C.hero.brew}</p>
          <CopyCommand command={C.brew} />
        </div>
      </div>
      <p className="meta">
        <span>{C.hero.version}</span>
        <span aria-hidden="true">·</span>
        <a href="#install">{C.hero.otherDownloads}</a>
        <span aria-hidden="true">·</span>
        <a href={RELEASE_URL}>{C.hero.releaseNotes}</a>
      </p>
      <p className="beta">
        <WarningTriangle />
        <span>
          <strong>{C.hero.beta}</strong>
          {C.gap}
          {C.hero.betaNote}
          {C.gap}
          <a href="#first-launch">{C.hero.howToOpen}</a>
        </span>
      </p>
      <div className="hero-shot">
        <Screenshot name="menu" alt={C.hero.screenshotAlt} eager />
      </div>
    </section>
  );
}
