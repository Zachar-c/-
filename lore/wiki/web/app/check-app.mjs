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
      setAttribute() {}, querySelector: node, querySelectorAll: () => [],
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
  const source = readFileSync(new URL(`./${file}`, import.meta.url), 'utf8');
  const served = readFileSync(new URL(`./dist/${file}`, import.meta.url), 'utf8');
  // 构建会按 app.js/style.css 内容哈希改写 dist/index.html 的 ?v=，比对时归一化该查询串，
  // 这样既能发现 dist 被手工改动，又不会每次构建都误报。
  const normalize = t => (file === 'index.html' ? t.replace(/(\?v=)[^"']*/g, '$1') : t);
  assert.equal(normalize(served), normalize(source), `served ${file} matches source`);
}
// 缓存版本号必须随前端内容变化：改代码不换版本号会让回访者继续用旧脚本。
const servedIndex = readFileSync(new URL('./dist/index.html', import.meta.url), 'utf8');
const assetStamp = servedIndex.match(/(?:app\.js|style\.css)\?v=([a-z0-9]+)/)?.[1];
assert.ok(assetStamp && assetStamp !== '20260930' && assetStamp !== '20261001', `assets carry a content-hash version (got ${assetStamp})`);
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

// Accessibility regressions in the stylesheet. Static checks so they need no browser:
// keyboard focus must stay visible, sticky chrome must not hide focused headings,
// motion must respect the OS setting, and no var() may silently fall back.
const css = readFileSync(new URL('./style.css', import.meta.url), 'utf8');
const focusRule = css.match(/:focus-visible\s*\{([^}]*)\}/);
assert.ok(focusRule, 'stylesheet defines a :focus-visible ring');
const focusWidth = Number(focusRule[1].match(/outline:\s*(\d+)px/)?.[1]);
assert.ok(focusWidth >= 2, `focus ring is at least 2px wide (got ${focusWidth}px)`);
assert.match(focusRule[1], /outline:\s*(?!none)\d+px\s+solid/, 'focus ring is a solid outline, not none');
const rootBlock = css.slice(css.indexOf(':root{'), css.indexOf('color-scheme'));
const declared = new Set([...rootBlock.matchAll(/(--[a-z0-9-]+)\s*:/g)].map(m => m[1]));
const referenced = new Set([...css.matchAll(/var\((--[a-z0-9-]+)/g)].map(m => m[1]));
assert.deepEqual([...referenced].filter(t => !declared.has(t)), [], 'every var() resolves to a declared token');
assert.deepEqual([...css.matchAll(/var\((--[a-z0-9-]+),/g)].map(m => m[1]), [], 'no var() hides a missing token behind a fallback literal');
assert.ok(!/(^|[;{\s])outline:\s*none/.test(css), 'no outline is removed without a visible replacement');
assert.match(css, /@media\s*\(prefers-reduced-motion:\s*reduce\)/, 'motion respects prefers-reduced-motion');
const topbarHeight = Number(css.match(/\.topbar\{[^}]*height:(\d+)px/)?.[1]);
const scrollPad = Number(css.match(/scroll-padding-top:(\d+)px/)?.[1]);
assert.ok(topbarHeight && scrollPad && scrollPad >= topbarHeight, 'scroll-padding clears the sticky topbar so anchors are not hidden');

// 导航改造：窄屏导航壳、返回所属列表、面包屑当前项、滚动位置记忆。
location.hash = '#/characters/fang-yuan';
run('render()');
// context.window is the vm stub; keep its scroll position settable for the memory test
context.window.scrollY = 0;
const articleHtml = node('#main').innerHTML;
assert.ok(articleHtml.includes('class="rail-fold" data-open="false"'), 'rail renders as a collapsible shell');
assert.ok(articleHtml.includes('class="rail-toggle"') && articleHtml.includes('aria-expanded="false"'), 'rail toggle starts collapsed and exposes its state');
assert.ok(articleHtml.includes('aria-controls="rail-body"'), 'rail toggle points at the region it controls');
assert.ok(articleHtml.includes('class="back-link" href="#/kind/character"'), 'article offers a way back to its kind list');
assert.ok(articleHtml.includes('aria-current="page">方源<'), 'breadcrumb marks the current page');
const skipLink = readFileSync(new URL('./index.html', import.meta.url), 'utf8').match(/<a[^>]*class="skip-link"[^>]*>[^<]*<\/a>/)?.[0];
assert.ok(skipLink, 'index offers a skip link to the body');
assert.ok(skipLink.includes('href="#main"'), 'skip link targets the main landmark');

// 滚动记忆必须按「正在离开的 URL」归档：hashchange 触发时 location.hash 已是新值。
// 故意让两者不同，否则用 scrollKey() 归档的实现也能通过这个断言。
location.hash = '#/kind/gu';
run('leavingKey = "#/characters/fang-yuan"');
context.window.scrollY = 1234;
const scrollProbe = run(`(() => { scrollMemory.clear(); rememberScroll(); return { saved: [...scrollMemory.entries()], leaving: leavingKey }; })()`);
assert.deepEqual(Object.fromEntries(scrollProbe.saved), { '#/characters/fang-yuan': 1234 }, 'scroll is filed under the page being left, not the page being entered');
assert.equal(scrollProbe.leaving, '#/kind/gu', 'leaving key advances to the new URL');
assert.ok(readFileSync(new URL('./app.js', import.meta.url), 'utf8').includes("history.scrollRestoration = 'manual'"), 'browser scroll restoration is disabled so it cannot override ours');

// 窄屏导航壳的 CSS 行为：收起时必须真的隐藏，开关触摸目标不得低于 WCAG 2.2 AA 的 24px。
const mobileCss = readFileSync(new URL('./style.css', import.meta.url), 'utf8').slice(
  readFileSync(new URL('./style.css', import.meta.url), 'utf8').indexOf('@media(max-width:900px)'));
assert.match(mobileCss, /\.rail-fold\[data-open="false"\]\s*\.rail-body\s*\{[^}]*display:\s*none/, 'collapsed rail hides its body on narrow screens');
assert.match(mobileCss, /\.rail-toggle\s*\{[^}]*display:\s*flex/, 'narrow screens show the rail toggle');
const toggleMinHeight = Number(mobileCss.match(/\.rail-toggle\s*\{[^}]*min-height:\s*(\d+)px/)?.[1]);
assert.ok(toggleMinHeight >= 24, `rail toggle meets the 24px WCAG 2.2 AA target size (got ${toggleMinHeight}px)`);
assert.ok(readFileSync(new URL('./style.css', import.meta.url), 'utf8').indexOf('.rail-toggle{display:none}') < readFileSync(new URL('./style.css', import.meta.url), 'utf8').indexOf('@media(max-width:900px)'), 'base rule hides the toggle without overriding the narrow-screen rule');

// EPUB 引用：数据侧抽取 + 前端可点击展开
const fangYuan = context.data.pages.find(p => p.route === '/characters/fang-yuan');
assert.ok(Array.isArray(fangYuan.epubRefs) && fangYuan.epubRefs.length > 0, 'article carries EPUB excerpts');
for (const ref of fangYuan.epubRefs) {
  assert.ok(Number.isInteger(ref.c) && Number.isInteger(ref.p) && ref.p >= 1 && ref.p <= ref.n,
    `locator in range: chapter_${ref.c} para_${ref.p} of ${ref.n}`);
  assert.ok(typeof ref.t === 'string' && ref.t.length > 0, 'excerpt has text');
}
// 抽出的原文必须逐字来自 canonical 源，不能是占位文本。
// 只断言「够长」挡不住 TODO 之类的占位，所以对已知定位钉一个具体句子。
const known = fangYuan.epubRefs.find(r => r.c === 20 && r.p === 19);
assert.ok(known, 'known locator chapter_0020 para_019 is present');
assert.equal(known.t, '他如法炮制，泄露出一丝春秋蝉的气息，压在月光蛊上。',
  'excerpt text matches the canonical paragraph verbatim');
// 章号与段落号也钉死，避免索引口径整体偏移一位这类错误蒙混过关
assert.equal(known.n, 62, 'chapter_0020 paragraph count comes from the canonical source');
// 点击后可展开：绑定函数存在且对无引文页面安全返回
// 沙箱 DOM 不含真实 <code>，这里用合成节点验证配对逻辑：
// 存量写法把定位拆成 `chapter_0020` + `para_019` 两段，para 需沿用上文的 chapter。
const fakeCode = (text) => {
  const attrs = {};
  const listeners = {};
  return {
    textContent: text, attrs, listeners,
    classList: { _s: new Set(), add(c) { this._s.add(c); }, toggle(c) { this._s.has(c) ? this._s.delete(c) : this._s.add(c); return this._s.has(c); }, contains(c) { return this._s.has(c); } },
    setAttribute(k, v) { attrs[k] = v; },
    addEventListener(t, fn) { listeners[t] = fn; },
    nextElementSibling: null, after() {},
  };
};
context.__codes = [
  fakeCode('EPUB chapter_0020 para_019'),   // 迁移后的连续写法
  fakeCode('chapter_0300'),                 // 存量写法：章节单独成段
  fakeCode('para_012'),                     // 段落单独成段，应沿用 chapter_0300
  fakeCode('chapter_9999'),                 // 无对应原文，不应绑定
  fakeCode('para_001'),
];
const fakeRoot = { querySelectorAll: () => context.__codes };
context.__fakeRoot = fakeRoot;
const pairing = run(`(() => {
  const target = { epubRefs: [
    {c:20,p:19,t:'连续写法原文',n:30},
    {c:300,p:12,t:'拆段写法原文',n:40},
  ] };
  const n = bindEpubCitations(__fakeRoot, target);
  return { n, bound: __codes.map(c => c.classList.contains('cite')),
           titles: __codes.map(c => c.title || null),   // title 是属性赋值，不是 setAttribute
           roles: __codes.map(c => c.attrs.role || null) };
})()`);
assert.equal(pairing.n, 2, 'only locators with real excerpts are bound');
// 拆段写法里只有 para_ 那一段可展开：单有 chapter_0300 时还不知道段落，无法定位原文。
assert.deepEqual(pairing.bound, [true, false, true, false, false],
  'contiguous form binds; split form binds the para half; chapter_9999 has no excerpt so nothing binds');
assert.match(pairing.titles[2], /第 300 章第 12 段/, 'split-form para inherits the preceding chapter');
assert.deepEqual([pairing.roles[0], pairing.roles[2]], ['button', 'button'], 'bound citations expose button semantics');
assert.equal(run("bindEpubCitations(__fakeRoot, {epubRefs: []})"), 0, 'no refs means nothing bound');
delete context.__codes; delete context.__fakeRoot;
assert.ok(readFileSync(new URL('./app.js', import.meta.url), 'utf8').includes("el.classList.add('cite')"), 'citations get the cite hook class');

console.log('PASS: kind lists/routes, article navigation and layer visibility, classification/search URL behavior, hash restoration and empty-query clearing, stylesheet focus/motion/token accessibility, EPUB citation excerpts and click-to-expand.');
