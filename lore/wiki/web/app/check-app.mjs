import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

// Use the built data and real rendering functions; no browser dependency.
const nodes = new Map();
function node(selector) {
  if (!nodes.has(selector)) {
    const listeners = new Map();
    nodes.set(selector, {
      innerHTML: '', value: '', classList: { toggle() {} }, listeners,
      addEventListener(type, handler) { listeners.set(type, handler); },
      setAttribute() {}, querySelector: node,
    });
  }
  return nodes.get(selector);
}
const documentHandlers = new Map();
const windowHandlers = new Map();
const location = { hash: '#/' };
const context = vm.createContext({
  location, console, URLSearchParams, setTimeout,
  localStorage: { getItem() { return null; } },
  document: { querySelector: node, querySelectorAll: () => [], addEventListener(type, handler) { documentHandlers.set(type, handler); }, body: node('body') },
  window: { addEventListener(type, handler) { windowHandlers.set(type, handler); }, scrollTo() {} }, fetch: () => new Promise(() => {}),
});
const run = code => vm.runInContext(code, context);
const fire = (selector, type, event = {}) => nodes.get(selector).listeners.get(type)(event);
run(readFileSync(new URL('./app.js', import.meta.url), 'utf8'));
for (const file of ['app.js', 'style.css', 'index.html']) {
  assert.equal(readFileSync(new URL(`./${file}`, import.meta.url), 'utf8'), readFileSync(new URL(`./dist/${file}`, import.meta.url), 'utf8'), `served ${file} matches source`);
}
context.data = JSON.parse(readFileSync(new URL('./dist/data.json', import.meta.url), 'utf8'));
run('db = data; pageByRouteMap = new Map(db.pages.map(p => [p.route, p])); buildArtIndex(); render();');

// EPUB-only locators must remain visible to the site's evidence audit.
const epubPage = context.data.pages.find(p => p.route === '/rules/immortal-gu-uniqueness');
assert.ok(epubPage && epubPage.audit.rawRefs > 0, 'EPUB locators counted');
assert.equal(epubPage.audit.evidence, '有原文锚点', 'EPUB-only evidence recognized');
run('auditMode = true');
assert.ok(run("ibBase(byRoute('/rules/immortal-gu-uniqueness'))").includes('处原文定位'), 'EPUB locators shown in evidence audit');
run('auditMode = false');
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
for (const [route, kind] of [['/characters/fang-yuan', 'character'], ['/world/index', 'index'], ['/world/aptitude-and-aperture', 'world'], ['/world/blade-path', 'path']]) {
  const page = context.data.pages.find(p => p.route === route);
  assert.ok(run(`classificationLink(byRoute(${JSON.stringify(route)}))`).includes(`href="#/kind/${kind}"`), `${route}: classification uses its kind`);
}
assert.ok(run("classificationLink({kind:'missing',category:'world'})").includes('href="#/category/world"'), 'legacy page classification falls back to category');
assert.match(readFileSync(new URL('./index.html', import.meta.url), 'utf8'), /href="#\/kind\/world"[^>]*data-tab="world"/, 'world tab uses the kind route');
// A real article's Markdown links must resolve after frontend enhancement.
const articlePage = context.data.pages.find(p => p.route === '/characters/fang-yuan');
const articleIds = new Set([...articlePage.html.matchAll(/\bid="([^"]+)"/g)].map(m => m[1]));
const localLinks = [...articlePage.html.matchAll(/href="#([^"/][^"]*)"/g)].map(m => decodeURIComponent(m[1]));
assert.ok(localLinks.length >= 5, 'article includes its reading guide');
for (const id of localLinks) assert.ok(articleIds.has(id), `article heading target: ${id}`);
const tribulation = context.data.pages.find(p => p.route === '/rules/tribulation');
const claimRow = tribulation.html.match(/<tr>\s*<td>TRIB-017<\/td>[\s\S]*?<\/tr>/)?.[0];
assert.ok(claimRow, 'updated tribulation claim is rendered');
assert.equal([...claimRow.matchAll(/<td>/g)].length, 4, 'epistemic marker does not split the table');
assert.ok(claimRow.includes('不得把记载与预期写成已实现的收益'), 'the claim preserves its limit');
const heads = [{ id: '原著明确内容' }, { id: '' }];
const article = { querySelectorAll(sel) { return sel === 'h2' ? heads : []; }, querySelector() { return null; } };
const originalQuery = context.document.querySelector;
context.document.querySelector = sel => sel === '#main article' ? article : null;
run('enhanceArticle(null, true)');
context.document.querySelector = originalQuery;
assert.equal(heads[0].id, '原著明确内容', 'enhancement preserves the Markdown anchor');
assert.equal(heads[1].id, 'sec-1', 'older headings retain the fallback');
// Clicking an encoded local heading must leave the article route intact.
location.hash = '#/characters/fang-yuan';
let scrolled = false;
let prevented = false;
context.document.getElementById = id => id === '学堂考核与资源'
  ? { scrollIntoView() { scrolled = true; } } : null;
const headingLink = { getAttribute() { return '#' + encodeURIComponent('学堂考核与资源'); } };
documentHandlers.get('click')({
  target: { closest(selector) { return selector === 'a[href^="#"]' ? headingLink : null; } },
  preventDefault() { prevented = true; },
});
assert.ok(scrolled && prevented, 'local heading click scrolls without native hash navigation');
assert.equal(location.hash, '#/characters/fang-yuan', 'heading navigation preserves the article route');
assert.equal(run('currentRoute()'), '/characters/fang-yuan', 'later renders still select this article');

// Exercise the actual layer filters against a tiny DOM surface and assert visibility.
const element = (layer, classes = []) => {
  const names = new Set(classes);
  return {
    dataset: layer ? { layer } : {},
    classList: {
      contains: name => names.has(name),
      toggle(name, on) { on ? names.add(name) : names.delete(name); },
    },
    get visible() { return !names.has('hidden'); },
  };
};
const articleSecs = ['canon', 'research', 'game', 'notes', 'meta', 'gap'].map(layer => element(layer, ['article-sec']));
const gameProjection = element('game', ['game-projection']);
const docSections = ['canon', 'state', 'notes', 'gap', 'meta'].map(layer => element(layer, ['doc-sec']));
const themeBlocks = ['canon', 'research', 'game', 'notes', 'meta', 'gap'].map(layer => element(layer, ['theme-block']));
const theme = element('', ['theme']);
const themesSection = element('mixed', ['doc-sec', 'doc-sec--themes']);
theme.querySelectorAll = selector => selector === '.theme-block' ? themeBlocks : [];
themesSection.querySelectorAll = selector => selector === '.theme' ? [theme] : [];
const doc = { dataset: {}, querySelectorAll(selector) {
  if (selector === '.doc-sec') return [...docSections, themesSection];
  return [];
} };
const originalQueryAll = context.document.querySelectorAll;
const originalQueryOne = context.document.querySelector;
context.document.querySelectorAll = selector => selector === '.article-sec' ? articleSecs : [];
context.document.querySelector = selector => selector === '.game-projection' ? gameProjection : selector === '.doc' ? doc : null;

run("applyArticleView('all')");
assert.ok(articleSecs.every(sec => sec.visible), 'legacy page all shows every layer');
assert.ok(gameProjection.visible, 'legacy page all shows game projection');
run("applyArticleView('canon')");
assert.deepEqual(articleSecs.map(sec => sec.visible), [true, false, false, false, false, false], 'legacy canon shows facts only');
assert.equal(gameProjection.visible, false, 'legacy canon hides game projection');
run("applyArticleView('gap')");
assert.deepEqual(articleSecs.map(sec => sec.visible), [false, false, false, false, false, true], 'legacy gap shows gaps only');

context.document.querySelector = selector => selector === '.doc' ? doc : selector === '.game-projection' ? gameProjection : null;
run("applyLayerView('all')");
assert.ok(docSections.every(sec => sec.visible), 'doc all shows non-theme canon/state/notes/gap/meta sections');
assert.ok(themesSection.visible && theme.visible && themeBlocks.every(block => block.visible), 'doc all shows theme and all its layers');
assert.ok(gameProjection.visible, 'doc all shows game projection');
const docBeforeAudit = [...docSections, themesSection, theme, ...themeBlocks, gameProjection].map(item => item.visible);
run("auditMode = true; applyLayerView('all')");
assert.deepEqual([...docSections, themesSection, theme, ...themeBlocks, gameProjection].map(item => item.visible), docBeforeAudit, 'audit mode leaves all-view content visible');
run("auditMode = false; applyLayerView('canon')");
assert.deepEqual(docSections.map(sec => sec.visible), [true, false, false, false, false], 'doc canon shows canonical sections only');
assert.deepEqual(themeBlocks.map(block => block.visible), [true, false, false, false, false, false], 'doc canon shows canonical theme blocks only');
run("applyLayerView('gap')");
assert.deepEqual(docSections.map(sec => sec.visible), [false, false, false, true, false], 'doc gap shows gap sections only');
assert.deepEqual(themeBlocks.map(block => block.visible), [false, false, false, false, false, true], 'doc gap shows gap theme blocks only');
context.document.querySelectorAll = originalQueryAll;
context.document.querySelector = originalQueryOne;

// Exercise real search listeners, URL encoding, and history-style hash changes.
const searchTerm = '蛊虫+人物&?';
location.hash = '#/characters/fang-yuan';
node('#search').value = searchTerm;
fire('#search', 'input');
assert.equal(new URLSearchParams(location.hash.split('?')[1]).get('q'), searchTerm, 'detail search encodes the complete Chinese query once');

location.hash = '#/';
run('render()');
node('#hero-search').value = '方源';
fire('#hero-search', 'input');
assert.equal(new URLSearchParams(location.hash.split('?')[1]).get('q'), '方源', 'hero search navigates with its query');

const submitTerm = '搜索 &?';
location.hash = '#/characters/fang-yuan';
run(`searchQuery = ${JSON.stringify(submitTerm)}`);
let submitPrevented = false;
fire('#search-form', 'submit', { preventDefault() { submitPrevented = true; } });
assert.ok(submitPrevented, 'search form prevents native submission');
assert.equal(new URLSearchParams(location.hash.split('?')[1]).get('q'), submitTerm, 'non-search form submit keeps its query');

location.hash = '#/search?q=' + encodeURIComponent('后退词');
run("searchQuery = 'stale'");
windowHandlers.get('hashchange')();
assert.equal(run('searchQuery'), '后退词', 'search hashchange restores query from an older search URL');
location.hash = '#/search';
windowHandlers.get('hashchange')();
assert.equal(run('searchQuery'), '', 'search hashchange clears the query when URL has no q');
console.log('PASS: kind lists/routes, article navigation and layer visibility, classification/search URL behavior, hash restoration and empty-query clearing.');
