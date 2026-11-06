import { useContent } from '../content';
import { SymbolTile } from '../icons';

// Repot's System Settings–style grouped list (the Tools pattern), one row per feature.
export function Features() {
  const C = useContent();
  return (
    <section className="section" id="features" aria-labelledby="features-title">
      <div className="section-head">
        <h2 id="features-title">{C.features.title}</h2>
      </div>
      <ul className="group features">
        {C.features.items.map((f) => (
          <li key={f.key} className="feature-row">
            <SymbolTile name={f.key} />
            <div>
              <h3>{f.title}</h3>
              <p>{f.text}</p>
            </div>
          </li>
        ))}
      </ul>
    </section>
  );
}
