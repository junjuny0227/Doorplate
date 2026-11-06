import { copyFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const output = new URL('../public/generated/', import.meta.url);
mkdirSync(output, { recursive: true });
for (const [source, name] of [
  ['assets/AppIcon.svg', 'AppIcon.svg'],
  ['docs/images/menu.png', 'menu.png'],
  ['docs/images/submenu.png', 'submenu.png'],
  ['docs/images/docker.png', 'docker.png'],
]) {
  copyFileSync(new URL(`../../${source}`, import.meta.url), new URL(name, output));
}
writeFileSync(fileURLToPath(new URL('../public/.nojekyll', import.meta.url)), '');
