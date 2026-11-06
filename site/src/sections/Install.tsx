import { RELEASES_URL, useContent } from '../content';
import { DownloadArrow } from '../icons';
import { CopyCommand } from './CopyCommand';

export function Install() {
  const C = useContent();
  return (
    <section className="section" id="install" aria-labelledby="install-title">
      <div className="section-head">
        <h2 id="install-title">{C.install.title}</h2>
        <p className="lead">{C.install.lead}</p>
      </div>
      <div className="install">
        <div>
          <h3 className="group-title">{C.install.downloads}</h3>
          <ul className="group files">
            {C.install.files.map((d) => (
              <li key={d.id} className="file-row">
                <div className="file-label">
                  <span>{d.label}</span>
                  <code>{d.file}</code>
                </div>
                <a className="button" href={d.url} aria-label={C.install.downloadFile(d.file)}>
                  <DownloadArrow />
                  {C.install.download}
                </a>
              </li>
            ))}
          </ul>
          <div className="footnote">
            <p>{C.install.zipNote}</p>
            <p>
              <a href={RELEASES_URL}>{C.install.allReleases}</a>
            </p>
          </div>
          <div className="footnote">
            <p>
              <strong>{C.install.brewTitle}</strong>
              {C.gap}
              {C.install.brewText}
            </p>
            <CopyCommand command={C.brew} />
          </div>
        </div>
        <div>
          <h3 className="group-title" id="first-launch">
            {C.install.firstLaunch}
          </h3>
          <ol className="group launch">
            {C.install.steps.map((s, i) => (
              <li key={s}>
                <span className="step-number small" aria-hidden="true">
                  {i + 1}
                </span>
                <p>{s}</p>
              </li>
            ))}
          </ol>
          <div className="footnote">
            <p>{C.install.macNote}</p>
            <CopyCommand command={C.install.quarantine} />
            <p>{C.install.quarantineExplanation}</p>
            <p>
              <a href={C.install.guideUrl}>{C.install.guide}</a>
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}
