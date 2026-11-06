import type { Messages } from '../i18n';
export function Tools({ c }: { c: Messages }) {
  return (
    <section className="section" aria-labelledby="tools-title">
      <h2 id="tools-title">{c.sections.stacks}</h2>
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th scope="col">{c.ui.stack}</th>
              <th scope="col">{c.ui.servers}</th>
            </tr>
          </thead>
          <tbody>
            {c.stacks.map(([stack, servers]) => (
              <tr key={stack}>
                <th scope="row">{stack}</th>
                <td>{servers}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="footnote">{c.stackNote}</p>
    </section>
  );
}
