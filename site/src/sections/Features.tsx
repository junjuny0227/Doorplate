import type { Messages } from '../i18n';
export function Features({ c }: { c: Messages }) {
  return (
    <section id="features" className="section" aria-labelledby="features-title">
      <h2 id="features-title">{c.sections.features}</h2>
      <div className="features">
        {c.features.map((feature, i) => (
          <article className="card" key={feature.title}>
            <span className="feature-number" aria-hidden="true">
              {String(i + 1).padStart(2, '0')}
            </span>
            <h3>{feature.title}</h3>
            <p>{feature.body}</p>
          </article>
        ))}
      </div>
    </section>
  );
}
