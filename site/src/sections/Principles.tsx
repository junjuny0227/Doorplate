import type { Messages } from '../i18n';
export function Principles({ c }: { c: Messages }) {
  return (
    <section className="section" aria-labelledby="principles-title">
      <h2 id="principles-title">{c.sections.principles}</h2>
      <div className="principles">
        {c.principles.map((p) => (
          <article className="card" key={p.title}>
            <h3>{p.title}</h3>
            <p>{p.body}</p>
          </article>
        ))}
      </div>
    </section>
  );
}
