import { useContent } from '../content';
import { Screenshot } from './Screenshot';

export function HowItWorks() {
  const C = useContent();
  return (
    <section className="section" id="how" aria-labelledby="how-title">
      <div className="section-head">
        <h2 id="how-title">{C.how.title}</h2>
        <p className="lead">{C.how.lead}</p>
      </div>
      <div className="how">
        <ol className="group steps">
          {C.how.steps.map((s, i) => (
            <li key={s.title} className="step">
              <span className="step-number" aria-hidden="true">
                {i + 1}
              </span>
              <div>
                <h3>{s.title}</h3>
                <p>{s.text}</p>
              </div>
            </li>
          ))}
        </ol>
        <div className="how-shots">
          <Screenshot name="submenu" alt={C.how.screenshotAlt} />
          <Screenshot name="docker" alt={C.how.dockerAlt} />
        </div>
      </div>
    </section>
  );
}
