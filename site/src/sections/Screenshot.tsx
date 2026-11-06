import { BASE, type Messages } from '../i18n';
export function Screenshot({ c }: { c: Messages }) {
  return (
    <section className="section" aria-labelledby="screenshots-title">
      <h2 id="screenshots-title">{c.sections.screenshots}</h2>
      <div className="screenshots">
        <figure>
          <div className="shot-stage">
            <img
              src={`${BASE}generated/submenu.png`}
              width={914}
              height={516}
              loading="lazy"
              alt={c.screenshots.serverAlt}
            />
          </div>
          <figcaption>{c.ui.serverCaption}</figcaption>
        </figure>
        <figure>
          <div className="shot-stage">
            <img
              src={`${BASE}generated/docker.png`}
              width={785}
              height={516}
              loading="lazy"
              alt={c.screenshots.dockerAlt}
            />
          </div>
          <figcaption>{c.ui.dockerCaption}</figcaption>
        </figure>
      </div>
    </section>
  );
}
