import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

// Use the built data and real rendering functions; no browser dependency.
const nodes = new Map();
function node(selector) {
  if (!nodes.has(selector)) nodes.set(selector, {
    innerHTML: '', value: '', classList: { toggle() {} },
    addEventListener() {}, setAttribute() {}, querySelector: node,
  });
  return nodes.get(selector);
}
const location = { hash: '#/' };
const context = vm.createContext({
  location, console, URLSearchParams, setTimeout,
  localStorage: { getItem() { return null; } },
  document: { querySelector: node, querySelectorAll: () => [], addEventListener() {}, body: node('body') },
  window: { addEventListener() {} }, fetch: () => new Promise(() => {}),
});
const run = code => vm.runInContext(code, context);
run(readFileSync(new URL('./app.js', import.meta.url), 'utf8'));
for (const file of ['app.js', 'style.css', 'index.html']) {
  assert.equal(readFileSync(new URL(`./${file}`, import.meta.url), 'utf8'), readFileSync(new URL(`./dist/${file}`, import.meta.url), 'utf8'), `served ${file} matches source`);
}
context.data = JSON.parse(readFileSync(new URL('./dist/data.json', import.meta.url), 'utf8'));
run('db = data; pageByRouteMap = new Map(db.pages.map(p => [p.route, p])); buildArtIndex(); render();');
const home = node('#main').innerHTML;
for (const kind of Object.keys(context.data.kinds)) {
  assert.ok(home.includes(`href="#/kind/${kind}"`), `home link: ${kind}`);
  location.hash = `#/kind/${kind}`;
  run('render()');
  const html = node('#main').innerHTML;
  const expected = run(`pagesByKind(${JSON.stringify(kind)})`);
  assert.ok(html.includes(`显示 ${expected.length} / ${expected.length} 条`), kind);
  const entryRoutes = [...html.matchAll(/<a class="entry" href="#([^"]+)"/g)].map(m => m[1]);
  assert.deepEqual(entryRoutes.sort(), Array.from(expected, p => p.route).sort(), `${kind}: only its entries`);
  assert.ok(html.includes('rail-group open'), `${kind}: active navigation`);
}
location.hash = '#/category/world';
run('render()');
assert.ok(node('#main').innerHTML.includes(`${run("entryPages().filter(p => p.category === 'world').length")} 条世界条目`), 'legacy category URL');
assert.equal(run("artFor({category:'gu',route:'/gu/no-card'})"), null);
assert.equal(run("entryType({category:'world',title:'东海'})"), '地域');
location.hash = '#/kind/path';
run("searchQuery = '暗道'; render()");
const searched = [...node('#main').innerHTML.matchAll(/<a class="entry" href="#([^"]+)"/g)].map(m => m[1]).sort();
const searchExpected = run("pagesByKind('path').filter(p => `${p.title} ${p.description} ${p.text}`.includes('暗道'))");
assert.deepEqual(searched, Array.from(searchExpected, p => p.route).sort());
console.log('PASS: 10 kind lists match built data; legacy URL, missing artwork, legacy world type and filtered search render.');
