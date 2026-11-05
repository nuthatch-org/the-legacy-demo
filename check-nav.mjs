// The sidebar and the mobile bottom nav are kept by hand; this fails when they list different
// sections, which is how a page becomes unreachable on a phone.
import { readFileSync } from 'node:fs';

const html = readFileSync(new URL('./index.html', import.meta.url), 'utf8');
const hrefs = id => {
  const block = html.match(new RegExp(`<nav[^>]*id="${id}"[^>]*>([\\s\\S]*?)</nav>`))?.[1] ?? '';
  return [...block.matchAll(/href="([^"]+)"/g)].map(m => m[1]);
};
const side = hrefs('side-nav');
const bottom = hrefs('bottom-nav');
const sections = [...html.matchAll(/<section id="([^"]+)"/g)].map(m => '#' + m[1]);
const same = (a, b) => a.length === b.length && a.every((x, i) => x === b[i]);
if (!same(side, bottom) || !same(side, sections)) {
  console.error('nav mismatch', { side, bottom, sections });
  process.exit(1);
}
if (/—/.test(html)) {
  console.error('em dash in index.html');
  process.exit(1);
}
if (/font-size:\s*[0-9.]+px/.test(html)) {
  console.error('pixel font size in index.html');
  process.exit(1);
}
console.log(`nav ok: ${side.length} sections in both navigations`);
