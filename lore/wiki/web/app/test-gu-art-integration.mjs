import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const appDir = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(appDir, '../../../..');
const visualDir = path.join(repo, 'lore/visual');
const queueDir = path.join(visualDir, 'assets/gu');
const readJson = file => JSON.parse(readFileSync(file, 'utf8'));
const hash = file => createHash('sha256').update(readFileSync(file)).digest('hex');
const manifest = readJson(path.join(visualDir, 'wiki-gu-art.json'));
const queue = readJson(path.join(queueDir, 'continuous-delivery.json'));
const audit = readJson(path.join(queueDir, 'missing-art-audit.json'));
const data = readJson(path.join(appDir, 'dist/data.json'));
const manifestByRoute = new Map(manifest.items.map(item => [item.route, item]));
const queueByRoute = new Map(queue.items.map(item => [item.route, item]));
const pagesByRoute = new Map(data.pages.map(page => [page.route, page]));

const nodes = new Map();
function node(selector) {
  if (!nodes.has(selector)) nodes.set(selector, {
    innerHTML: '', value: '', classList: { toggle() {} },
    addEventListener() {}, setAttribute() {}, querySelector: node, querySelectorAll: () => [],
  });
  return nodes.get(selector);
}
const context = vm.createContext({
  console, URLSearchParams, setTimeout,
  localStorage: { getItem() { return null; } },
  document: { querySelector: node, querySelectorAll: () => [], addEventListener() {}, body: node('body') },
  window: { addEventListener() {}, scrollTo() {} },
  location: { hash: '#/' }, fetch: () => new Promise(() => {}),
});
vm.runInContext(readFileSync(path.join(appDir, 'app.js'), 'utf8'), context);
context.data = data;
vm.runInContext('db = data; pageByRouteMap = new Map(db.pages.map(p => [p.route, p])); buildArtIndex();', context);

assert.equal(manifest.items.length, 31, 'manifest has the 31 selected cards');
assert.equal(manifestByRoute.size, manifest.items.length, 'manifest routes are unique');
assert.equal(queue.items.filter(item => item.record).length, 31, 'delivery queue identifies 31 source cards');
assert.deepEqual([...manifestByRoute.keys()].sort(), queue.items.filter(item => item.record).map(item => item.route).sort(), 'manifest routes exactly match selected cards');

for (const item of manifest.items) {
  const queued = queueByRoute.get(item.route);
  assert.ok(queued?.record, `${item.route}: selected queue entry exists`);
  assert.ok(pagesByRoute.has(item.route), `${item.route}: built Wiki page exists`);
  assert.equal(typeof item.caption, 'string');
  assert.ok(item.caption.trim(), `${item.route}: caption is present`);

  const manifestPng = path.resolve(visualDir, item.file);
  const originalPng = path.join(queueDir, readJson(path.join(queueDir, queued.record)).file);
  assert.ok(manifestPng.startsWith(visualDir + path.sep), `${item.route}: file stays under lore/visual`);
  assert.ok(existsSync(manifestPng), `${item.route}: manifest PNG exists`);
  assert.equal(hash(manifestPng), item.sha256, `${item.route}: source PNG matches its pinned SHA-256`);
  assert.equal(hash(originalPng), item.sha256, `${item.route}: archived selected PNG matches its pinned SHA-256`);

  const expectedPath = `art/wiki-gu/${path.basename(item.file)}.webp`;
  const page = pagesByRoute.get(item.route);
  const selectedArt = vm.runInContext(`artFor(pageByRouteMap.get(${JSON.stringify(item.route)}))`, context);
  assert.equal(page.art?.path, expectedPath, `${item.route}: built page points at its dedicated WebP`);
  assert.equal(selectedArt?.path, expectedPath, `${item.route}: runtime artFor selects the dedicated WebP`);
  assert.equal(selectedArt?.caption, item.caption, `${item.route}: runtime artFor preserves the manifest caption`);
  assert.ok(existsSync(path.join(appDir, 'dist', expectedPath)), `${item.route}: built WebP exists`);
  const figure = vm.runInContext(`ibFigure(pageByRouteMap.get(${JSON.stringify(item.route)}))`, context);
  assert.ok(figure.includes(`<img src="${expectedPath}"`), `${item.route}: Wiki figure renders the dedicated image`);
  assert.ok(figure.includes(`<figcaption>${item.caption}</figcaption>`), `${item.route}: Wiki figure renders its caption`);
  assert.ok(figure.includes('蛊虫图鉴'), `${item.route}: figure is labeled as a Gu catalog image`);
  assert.ok(!figure.includes('codex-rank'), `${item.route}: Wiki illustration has no game rank badge`);
}

const recordsByRoute = new Map(manifest.items.map(item => [item.route, readJson(path.resolve(visualDir, item.record))]));
assert.match(recordsByRoute.get('/gu/heaven-atk-5-07-gu')?.evidence?.excerpt || '', /三百年/, 'Lifespan Gu keeps its 300-year evidence distinct');
assert.match(recordsByRoute.get('/gu/man-as-before-gu')?.prompt || '', /SIX-RANK/, 'Man-as-Before card remains the six-rank depiction');
assert.match(recordsByRoute.get('/gu/human-atk-5-02-gu')?.prompt || '', /changes with observer|observer-specific/i, 'Love Gu retains its observer-specific interpretation');
assert.match(recordsByRoute.get('/gu/luck-atk-5-01-gu')?.prompt || '', /invisible|intangible|cannot be seen/i, 'Fortune Rivaling Heaven retains the intangible-luck caveat');
assert.match(recordsByRoute.get('/gu/supreme-immortal-fetus-gu')?.prompt || '', /transition stage|nascent/i, 'Supreme Immortal Fetus retains the depicted stage');
assert.match(recordsByRoute.get('/gu/soul-atk-5-01-gu')?.prompt || '', /reconstructed intact living state/i, 'Soul Lantern reconstruction remains explicit');
assert.match(recordsByRoute.get('/gu/myriads-self-immortal-gu')?.inspection?.risks?.join(' ') || '', /5000|逐足计数|计数/, 'Myriad Self preserves the foot-count limitation');
for (const [route, pattern, note] of [
  ['/gu/heaven-atk-5-07-gu', /三百年/, 'Lifespan figure caption distinguishes the 300-year form'],
  ['/gu/man-as-before-gu', /六转/, 'Man-as-Before figure caption identifies the six-rank stage'],
  ['/gu/human-atk-5-02-gu', /观察者/, 'Love Gu figure caption preserves the observer-specific view'],
  ['/gu/luck-atk-5-01-gu', /无形|非实体/, 'Fortune Rivaling Heaven figure caption says luck is intangible'],
  ['/gu/supreme-immortal-fetus-gu', /阶段/, 'Supreme Immortal Fetus figure caption identifies its depicted stage'],
  ['/gu/soul-atk-5-01-gu', /重建|复原/, 'Soul Lantern figure caption marks its reconstruction'],
  ['/gu/myriads-self-immortal-gu', /不能逐足核验|无法逐足核验/, 'Myriad Self figure caption preserves the foot-count caveat'],
]) {
  const figure = vm.runInContext(`ibFigure(pageByRouteMap.get(${JSON.stringify(route)}))`, context);
  assert.match(figure, new RegExp(`<figcaption>[^<]*${pattern.source}[^<]*<\\/figcaption>`), note);
}

for (const item of queue.items.filter(item => item.status.startsWith('defer_'))) {
  assert.ok(!manifestByRoute.has(item.route), `${item.route}: deferred card has no mapping`);
  assert.equal(vm.runInContext(`artFor(pageByRouteMap.get(${JSON.stringify(item.route)}))`, context), null, `${item.route}: deferred card remains unmapped at runtime`);
}
assert.equal(queue.items.filter(item => item.status.startsWith('defer_')).length, 19, 'queue has 19 deferred routes');
for (const item of queue.items.filter(item => item.status === 'existing_source_reviewed_no_regeneration')) {
  assert.ok(!manifestByRoute.has(item.route), `${item.route}: existing-source card has no new mapping`);
  assert.equal(vm.runInContext(`artFor(pageByRouteMap.get(${JSON.stringify(item.route)}))`, context), null, `${item.route}: existing-source card remains unmapped at runtime`);
}
assert.equal(queue.items.filter(item => item.status === 'existing_source_reviewed_no_regeneration').length, 6, 'queue has six existing-source routes');

for (const item of audit.pages.filter(item => item.wiki_image)) {
  const page = pagesByRoute.get(item.route);
  assert.ok(page, `${item.route}: existing pictured route remains in built data`);
  const art = vm.runInContext(`artFor(pageByRouteMap.get(${JSON.stringify(item.route)}))`, context);
  assert.equal(art?.path || null, item.wiki_image, `${item.route}: original Wiki art mapping is unchanged`);
  assert.equal(manifestByRoute.has(item.route), false, `${item.route}: original pictured route was not replaced by this manifest`);
}
assert.equal(audit.pages.filter(item => item.wiki_image).length, 36, 'original audit contains 36 pictured routes');

console.log(`PASS: ${manifest.items.length} Wiki Gu mappings, PNG hashes, captions, built WebPs, deferred/existing routes, and ${audit.pages.filter(item => item.wiki_image).length} preserved pictured routes`);
