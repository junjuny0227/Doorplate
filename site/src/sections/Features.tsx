import type { Messages } from '../i18n';
export function Features({ c }: { c: Messages }) {
  return (
    <section id="features" className="section" aria-labelledby="features-title">
      <h2 id="features-title">{c.sections.features}</h2>
      <div className="features">
        {c.features.slice(0, 6).map((feature, i) => (
          <article className="card" key={feature.title}>
            <span className="feature-number" aria-hidden="true">
              0{i + 1}
            </span>
            <h3>{feature.title}</h3>
            <p>{feature.body}</p>
          </article>
        ))}
      </div>
      <ul className="also">
        {c.features.slice(6).map((f) => (
          <li key={f.title}>
            <strong>{f.title}</strong> {f.body}
          </li>
        ))}
      </ul>
    </section>
  );
}
