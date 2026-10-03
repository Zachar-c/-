'use strict';

/* ============================================================
   问真 · 知识库
   读取 dist/data.json（只读），重构为阅读优先的 Wiki 布局。
   不修改任何 Wiki 数据与内容。
   ============================================================ */

let db = null;
let auditMode = localStorage.getItem('wikiAuditMode') === 'on';
let listFilter = 'all';
let searchQuery = '';
let pageByRouteMap = new Map();
let artByPath = new Map();
let artCards = [];

const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));
const esc = (v) => String(v ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

const SHORT_CAT = { characters: '人物', gu: '蛊虫', events: '事件', world: '世界', rules: '规则', themes: '主题', source: '来源', paths: '路径', home: '总览' };

// L1 DECISION：仅 10 kind；站点按 kind 分栏，不猜类型
const KIND_LABEL = () => db.kinds || {};
function kindLabel(k) { return (db.kinds && db.kinds[k]) || k; }
function pagesByKind(k) { return entryPages().filter(p => p.kind === k); }
function classificationLink(page) {
  const typed = Object.hasOwn(db.kinds || {}, page.kind);
  return `<a href="#/${typed ? 'kind' : 'category'}/${esc(typed ? page.kind : page.category)}">${esc(typed ? kindLabel(page.kind) : catLabel(page.category))}</a>`;
}
function kindChip(page) {
  if (!page.kind) return '';
  return `<span class="chip chip-kind" data-kind="${esc(page.kind)}">${esc(kindLabel(page.kind))}</span>`;
}
const KIND_KNOWLEDGE = () => (db.kindGroups && db.kindGroups.knowledge) || ['character','gu','event','world','path','rule','theme'];
const KIND_META = () => (db.kindGroups && db.kindGroups.meta) || ['index','relation','reference'];

/* ---------------- 基础派生 ---------------- */

const allPages = () => db.pages.filter(p => p.category !== 'home');
const entryPages = () => allPages().filter(p => !p.route.endsWith('/index'));
const byRoute = (route) => pageByRouteMap.get(route) || null;
const catLabel = (key) => db.categories[key] || SHORT_CAT[key] || key;
const hubOf = (key) => byRoute('/' + key + '/index');

function entryType(page) {
  if (page.kind && db.kinds && db.kinds[page.kind]) {
    return db.kinds[page.kind];
  }
  switch (page.category) {
    case 'gu': return '蛊虫';
    case 'characters': return '人物';
    case 'events': return '事件';
    case 'themes': return '主题';
    case 'rules': return '规则';
    case 'source': return '来源';
    case 'world': {
      const t = page.title;
      const d = page.description || '';
      if (/总表|名录|索引|总览/.test(t)) return '名录';
      if (['南疆', '北原', '东海', '西漠', '中洲'].includes(t)) return '地域';
      if (/道$/.test(t) || /流派/.test(d)) return '流派';
      if (/组织|势力|门派/.test(d)) return '组织';
      return '世界';
    }
    default: return '条目';
  }
}

// 原著转数：只认 Wiki 自己撰写的简介字段，不从正文随意抓取。
// 正文常同时出现多种转数（如酒虫一系跨一转至四转），抓「首个」会得出误导性结论。
// 「多形态」只在简介明确并列多个转数时成立（「一/二/三/四转」「一转、二转」）：
// 简介里出现两个转数不等于本页多变——「二转草蛊……可撕成一片一转消耗型生机叶」
// 是本页转数与附属物转数并存，本页仍是单一转数，不能一并标成多形态。
const RANK_ONE = '[一二三四五六七八九十两]+';
const RANK_SERIES_RE = new RegExp(
  `${RANK_ONE}\\s*[/、·]\\s*${RANK_ONE}(?:\\s*[/、·]\\s*${RANK_ONE})*\\s*转` // 一/二/三/四转
  + `|${RANK_ONE}转\\s*[、/·]\\s*${RANK_ONE}转`,                            // 一转、二转
);
function canonRank(page) {
  if (page.category !== 'gu') return { rank: '', multi: false };
  const d = page.description || '';
  if (RANK_SERIES_RE.test(d)) return { rank: '', multi: true };
  const m = d.match(new RegExp(`${RANK_ONE}转`));
  return { rank: m ? m[0] : '', multi: false };
}

// 「单一蛊虫条目」：名录 / 关系表 / 总表这类汇总页不是实体，不参与蛊虫实体卡与转数呈现
const GU_LIST_RE = /总表|名录|总览|索引|关系|图谱|一览|边界|续录/;
function isGuEntity(page) {
  return page.category === 'gu' && !page.route.endsWith('/index')
    && !!page.description && !GU_LIST_RE.test(page.title);
}

const TAGS = {
  gap: { label: '待核对', cls: 'chip-gap' },
  inferred: { label: '推导', cls: 'chip-inferred' },
  evidence: { label: '缺证据', cls: 'chip-evidence' },
  thin: { label: '信息不足', cls: 'chip-thin' },
  ok: { label: '无自动警示', cls: 'chip-ok' },
};
const TAG_SECTION = { gap: '待核对', inferred: '分析与解读', evidence: '待核对', thin: '', ok: '原著明确内容' };
const AUDIT_COLOR = { gap: '#b8794c', inferred: '#a8913f', evidence: '#7d6450', thin: '#3d474e', ok: '#4d7d6c' };
const SECTION_TAG = { '待核对': 'gap', '分析与解读': 'inferred', '资料整理': 'inferred', '原著明确内容': 'ok' };
const FLAG_ORDER = ['gap', 'inferred', 'evidence', 'thin', 'ok'];

// 审计标记是「命中该特征」，一个条目可同时命中多个；无任何命中仅表示未见自动警示，不证明内容完整或事实已核
function auditFlags(page) {
  const a = page.audit;
  const f = [];
  if (a.gapItems > 0 || a.unresolved > 0) f.push('gap');
  if (a.inferred > 0) f.push('inferred');
  if (a.evidence !== '有原文锚点') f.push('evidence');
  if (!page.description && page.text.length < 900) f.push('thin');
  return f.length ? f : ['ok'];
}

function auditChips(page, clickable) {
  return auditFlags(page).map(id => clickable
    ? `<button type="button" class="chip ${TAGS[id].cls}" data-goto-tag="${id}">${TAGS[id].label}</button>`
    : `<span class="chip ${TAGS[id].cls}">${TAGS[id].label}</span>`).join('');
}

function auditSummary() {
  const pages = entryPages();
  const s = { total: pages.length, gap: 0, inferred: 0, evidence: 0, thin: 0, ok: 0 };
  pages.forEach(p => FLAG_ORDER.forEach(k => { if (auditFlags(p).includes(k)) s[k]++; }));
  return s;
}

function relevance(page) {
  const a = page.audit;
  return (a.gapItems * 2) + (a.inferred * 3) + a.unresolved + (a.evidence !== '有原文锚点' ? 4 : 0);
}

// 检索排序：标题完全命中 > 标题前缀 > 标题包含 > 简介包含 > 仅正文命中；同层按出现次数微调
function relevanceTo(page, q) {
  const t = page.title.toLocaleLowerCase();
  const d = (page.description || '').toLocaleLowerCase();
  const b = page.text.toLocaleLowerCase();
  let s = 0;
  if (t === q) s += 1000;
  else if (t.startsWith(q)) s += 600;
  else if (t.includes(q)) s += 400;
  if (d.includes(q)) s += 150;
  if (b.includes(q)) s += 40 + Math.min(b.split(q).length - 1, 20) * 3;
  return s;
}

// 详情页简介与正文首段常高度重合；重合时不再重复展示简介，正文原样不动
function leadIsRedundant(desc, bodyText) {
  const clean = (s) => String(s || '').replace(/[^\u4e00-\u9fa5A-Za-z0-9]/g, '');
  const d = clean(desc);
  if (d.length < 8) return false;
  const head = clean(bodyText).slice(0, 600);
  let hit = 0;
  let total = 0;
  for (let i = 0; i + 2 <= d.length; i++) {
    total++;
    if (head.includes(d.slice(i, i + 2))) hit++;
  }
  return total > 0 && hit / total >= 0.6;
}

/* ---------------- 生图匹配（诚实标注，不臆造归属） ---------------- */

function buildArtIndex() {
  artByPath = new Map();
  artCards = [];
  db.art.forEach(item => {
    artByPath.set(item.path, item);
    if (item.path.startsWith('art/gu/cards/')) {
      artCards.push({ path: item.path, slug: item.path.slice('art/gu/cards/'.length).replace(/_gu_card\.png\.webp$/, '') });
    }
  });
}

function artFor(page) {
  if (page.category !== 'gu') return null;
  if (page.art && artByPath.has(page.art.path)) return { ...artByPath.get(page.art.path), caption: page.art.caption };
  const tail = page.route.split('/').pop().replace(/-gu$/, '').replace(/-/g, '_');
  const exact = 'art/gu/cards/' + tail + '_gu_card.png.webp';
  if (artByPath.has(exact)) return { ...artByPath.get(exact), caption: '游戏同名卡面' };
  const prefixed = artCards.filter(c => c.slug.startsWith(tail + '_'));
  if (prefixed.length === 1) return { ...artByPath.get(prefixed[0].path), caption: '游戏卡面（名称近似，非同名）' };
  return null;
}

/* ---------------- 相关条目 ---------------- */

function relatedRoutes(page) {
  const found = new Set();
  const re = /href="#(\/[^"#?]+)"/g;
  let m;
  while ((m = re.exec(page.html)) !== null) {
    const r = m[1];
    if (r === page.route || r.endsWith('/index')) continue;
    if (pageByRouteMap.has(r)) found.add(r);
  }
  return Array.from(found);
}

function linkChips(routes, limit) {
  const list = limit ? routes.slice(0, limit) : routes;
  return list.map(r => {
    const p = byRoute(r);
    if (!p) return '';
    return `<a href="#${r}"><span class="lb">${esc(SHORT_CAT[p.category] || '')}</span>${esc(p.title)}</a>`;
  }).join('');
}

/* ---------------- 左侧知识导航 ---------------- */

function railHtml(activeKey, activeRoute, toc, activeKind = '') {
  const cats = Object.entries(db.categories);
  const entries = entryPages();
  // L1 Q4：侧栏两组——知识（character/gu/event/world/path/rule/theme）+ 索引与资料
  const kindGroups = [
    { title: '知识', kinds: KIND_KNOWLEDGE() },
    { title: '索引与资料', kinds: KIND_META() },
  ];
  const groups = kindGroups.map(g => {
    const rows = g.kinds.map(k => {
      const items = pagesByKind(k);
      if (!items.length) return '';
      const open = k === activeKind || (pageByRouteMap.get(activeRoute) || {}).kind === k;
      return `<div class="rail-group${open ? ' open' : ''}">
        <a class="rail-cat" href="#/kind/${k}"><span>${esc(kindLabel(k))}</span><em>${items.length}</em></a>
        ${open ? `<div class="rail-items">${items.map(p => `<a class="rail-item${p.route === activeRoute ? ' active' : ''}" href="#${p.route}" title="${esc(p.title)}">${esc(p.title)}</a>`).join('')}</div>` : ''}
      </div>`;
    }).join('');
    return `<div class="rail-section"><div class="rail-section-title">${esc(g.title)}</div>${rows}</div>`;
  }).join('');
  const nav = `<nav class="rail-nav" aria-label="知识导航">
    <div class="rail-title">知识导航</div>
    <a class="rail-link${activeRoute === '/' ? ' active' : ''}" href="#/">首页</a>
    <a class="rail-link${activeRoute === '/browse' ? ' active' : ''}" href="#/browse"><span>全部条目</span><em>${entries.length}</em></a>
    <div class="rail-sep"></div>
    ${groups}
  </nav>`;
  // 详情页目录优先：分类列表可能很长，目录置于其上才始终可见
  // 窄屏下整块导航会排在正文之前（实测 390px 时正文标题被推到约 1000px 之后），
  // 故包一层可折叠壳：宽屏恒展开（CSS 隐藏开关），窄屏默认收起、由开关控制。
  const body = toc ? `${toc}${nav}` : nav;
  return `<div class="rail-fold" data-open="false">
    <button class="rail-toggle" type="button" aria-expanded="false" aria-controls="rail-body">
      <span class="rail-toggle-mark" aria-hidden="true"></span>
      <span class="rail-toggle-text">导航与本页目录</span>
      <span class="rail-toggle-hint">${entries.length} 条目</span>
    </button>
    <div class="rail-body" id="rail-body">${body}</div>
  </div>`;
}

/* ---------------- EPUB 引用：点击展开原文 ---------------- */

// 页面里的定位有两种写法：迁移后的 `EPUB chapter_0020 para_019`（一段代码），
// 与存量的 `chapter_0020` `para_019`（各自一段代码）。先扫一遍配对，再统一挂点击。
function bindEpubCitations(root, page) {
  const refs = new Map(((page && page.epubRefs) || []).map(r => [`${r.c}:${r.p}`, r]));
  if (!refs.size) return 0;

  const entries = $$('code', root).map(el => {
    const text = (el.textContent || '').trim();
    const both = text.match(/chapter_(\d{4})\s+para_(\d{3})/);
    if (both) return { el, chapter: +both[1], para: +both[2] };
    const onlyChapter = text.match(/^chapter_(\d{4})$/);
    if (onlyChapter) return { el, chapter: +onlyChapter[1], para: null };
    const onlyPara = text.match(/^para_(\d{3})$/);
    if (onlyPara) return { el, chapter: null, para: +onlyPara[1] };
    return null;
  }).filter(Boolean);

  // 存量写法里 para_ 单独成段，沿用上文最近的 chapter
  let carried = null;
  for (const entry of entries) {
    if (entry.chapter !== null) carried = entry.chapter;
    else entry.chapter = carried;
  }

  let bound = 0;
  for (const entry of entries) {
    if (entry.chapter === null || entry.para === null) continue;
    const ref = refs.get(`${entry.chapter}:${entry.para}`);
    if (!ref) continue;
    const el = entry.el;
    el.classList.add('cite');
    el.setAttribute('role', 'button');
    el.setAttribute('tabindex', '0');
    el.setAttribute('aria-expanded', 'false');
    el.title = `展开原文：第 ${entry.chapter} 章第 ${entry.para} 段`;
    const toggle = () => {
      const open = el.classList.toggle('cite-open');
      el.setAttribute('aria-expanded', String(open));
      let panel = el.nextElementSibling;
      if (panel && panel.classList.contains('cite-excerpt')) {
        if (!open) { panel.remove(); return; }
      } else {
        panel = document.createElement('span');
        panel.className = 'cite-excerpt';
        panel.innerHTML = `<b>EPUB chapter_${String(entry.chapter).padStart(4, '0')} para_${String(entry.para).padStart(3, '0')}</b>${esc(ref.t)}`;
        el.after(panel);
      }
    };
    el.addEventListener('click', toggle);
    el.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); toggle(); }
    });
    bound++;
  }
  return bound;
}

function tocHtml() {
  return '<nav class="toc" id="toc" aria-label="本页目录"><div class="toc-title">本页目录</div></nav>';
}

// 窄屏导航壳的开合。宽屏由 CSS 强制展开（开关 display:none），此处只服务窄屏。
function setRailFold(fold, open) {
  if (!fold) return;
  fold.dataset.open = open ? 'true' : 'false';
  const btn = fold.querySelector('.rail-toggle');
  if (btn) btn.setAttribute('aria-expanded', String(open));
}

/* ---------------- Infobox ---------------- */

const RARITY_CN = { common: '普通', uncommon: '精良', rare: '稀有', epic: '史诗', legendary: '传说' };
const RANK_CN = { 1: '一转', 2: '二转', 3: '三转', 4: '四转', 5: '五转', 6: '六转', 7: '七转', 8: '八转', 9: '九转' };

// 转数有两个独立权威来源，互不覆盖：原著＝Wiki 简介字段；《问真》＝游戏仓库投影。
// 游戏仓库数据不得补全或裁定原著缺失的字段，因此两者分开呈现。
const MULTI_RANK_LABEL = '多形态 · 见谱系';
function rankInfo(page) {
  const raw = page.game && page.game.stats ? page.game.stats.rank : null;
  const can = canonRank(page);
  return { canon: can.rank, multi: can.multi, game: RANK_CN[raw] || '' };
}

// 主展示 chip：两边一致时可合并，来源不同或单边缺失时并列并标出来源；
// 原著是多形态时不给单值，直接标「多形态 · 见谱系」
function rankChip(page) {
  const { canon, multi, game } = rankInfo(page);
  if (!multi && canon && game && canon === game) return `<span class="chip chip-type">${esc(canon)}</span>`;
  const parts = [];
  if (multi) parts.push(`原著 ${MULTI_RANK_LABEL}`);
  else if (canon) parts.push(`原著 ${canon}`);
  if (game) parts.push(`《问真》${game}`);
  return parts.length ? `<span class="chip chip-type">${esc(parts.join(' · '))}</span>` : '';
}

// 图鉴卡数值条：数据驱动——按游戏仓库实际存在的字段迭代，有则显示、无则消失。
// 卡面字段优先排序；此后新增字段（真元品质、修炼收益等）也会自动出现，无需改代码。
// 转数不在此重复，它由基本信息里的来源分行承担。
const CODEX_LABEL = {
  rarity: '稀有度', school: '流派', role: '定位', slot_role: '定位',
  value: '价值', essence_cost: '真元消耗', true_qi_cost: '真气消耗', feeding_cost: '喂养消耗',
  feed_points: '喂养点数', replace_value: '替换值', v1_effect: 'v1 效果',
};
const CODEX_ORDER = ['rarity', 'school', 'slot_role', 'value', 'essence_cost', 'true_qi_cost',
  'feeding_cost', 'feed_points', 'replace_value', 'v1_effect'];
// 开发侧结构性字段不进卡面，它们的归属是正文《问真》当前实现
const CODEX_SKIP = new Set(['rank', 'role', 'canon_refs', 'canon_anchors', 'buildRole',
  'buildTags', 'synergy_hooks', 'combat', 'field_actions', 'source_class']);

function codexValue(v) {
  if (Array.isArray(v)) return v.join(' · ');
  if (v && typeof v === 'object') {
    const parts = [v.kind, v.amount != null ? String(v.amount) : ''].filter(Boolean);
    if (v.ignoreEvasion) parts.push('忽略闪避');
    return parts.length ? parts.join(' ') : JSON.stringify(v);
  }
  return String(v);
}

function codexStats(page) {
  const s = { ...((page.game && page.game.stats) || {}) };
  if (s.slot_role == null) s.slot_role = s.role;
  const usable = ([k, v]) => !CODEX_SKIP.has(k) && v != null && v !== '' && (!Array.isArray(v) || v.length);
  const keys = CODEX_ORDER.filter(k => k in s)
    .concat(Object.keys(s).filter(k => !CODEX_ORDER.includes(k) && !CODEX_SKIP.has(k)));
  const chips = keys.filter(k => usable([k, s[k]])).map(k => {
    // role 缺省时才用 slot_role 兜底定位，避免同一值出现两次
    const v = k === 'rarity' ? (RARITY_CN[s[k]] || s[k]) : codexValue(s[k]);
    return [v, CODEX_LABEL[k] || k];
  }).filter(([v]) => v !== '');
  if (!chips.length) return '';
  return `<div class="codex-stats">${chips.map(([v, k]) => `<span class="cs"><b>${esc(v)}</b><i>${esc(k)}</i></span>`).join('')}</div>`;
}

function ibFigure(page) {
  const art = artFor(page);
  const isCard = !!art && art.path.startsWith('art/gu/cards/');
  // 卡面属《问真》素材，角标只取游戏仓库转数，不用原著字段补位
  const rev = isCard ? rankInfo(page).game : '';
  if (art) {
    return `<div class="ib-main"><div class="ib-label">${isCard || page.art ? '蛊虫图鉴' : '条目信息'}</div>
      <figure class="ib-figure${isCard ? ' ib-figure--codex' : ''}">
        <div class="codex-frame">${rev ? `<span class="codex-rank">${esc(rev)}</span>` : ''}<img src="${encodeURI(art.path)}" alt="${esc(page.title)}" ${art.w && art.h ? `width="${art.w}" height="${art.h}" ` : ''}decoding="async"></div>
        <figcaption>${esc(art.caption)}</figcaption>
      </figure>
      ${isCard ? codexStats(page) : ''}
    </div>`;
  }
  const glyph = page.category === 'characters' ? '人' : page.category === 'gu' ? '蛊' : '問';
  return `<div class="ib-main"><div class="ib-label">${page.category === 'gu' ? '蛊虫图鉴' : '条目信息'}</div>
    <div class="ib-seal"><span class="glyph">${glyph}</span><p>暂无专属生图<br><a href="#/art">参见美术馆</a></p></div>
    ${page.category === 'gu' ? codexStats(page) : ''}
  </div>`;
}

function ibBase(page) {
  const a = page.audit;
  const rows = [];
  rows.push(['类型', esc(entryType(page))]);
  rows.push(['分类', classificationLink(page)]);
  if (page.category === 'gu') {
    // 转数来源分离：原著字段与游戏仓库各自成行，谁也补全不了谁
    const { canon, multi, game } = rankInfo(page);
    if (canon || multi || game || isGuEntity(page)) {
      rows.push(['原著转数', multi
        ? `${esc(MULTI_RANK_LABEL)}${auditMode ? '<span class="ib-sub">简介为并列多形态，不做单值概括</span>' : ''}`
        : canon
          ? `${esc(canon)}${auditMode ? '<span class="ib-sub">取自简介字段</span>' : ''}`
          : '<span class="ib-sub">待取证</span>']);
      // 运行条目读不到，既可能是尚未实现，也可能是构建期游戏数据源不完整（见 db.gameMeta.warnings）。
      // 有游戏侧对照记录时如实标出来源；没有则按数据源是否完整区分「未载入」与「未收录」，
      // 不在数据源已知残缺的情况下把本页的数据缺口断称成《问真》的事实。
      const lr = page.game && page.game.lore ? page.game.lore.gameRank : null;
      const loreRank = lr == null || lr === '' ? '' : (RANK_CN[lr] || `${lr} 转`);
      rows.push(['《问真》转数', game ? esc(game)
        : loreRank ? `${esc(loreRank)}<span class="ib-sub">游戏侧对照，运行条目未载入</span>`
          : gameDataIncomplete() ? '<span class="ib-sub">未载入</span>'
            : '<span class="ib-sub">未收录</span>']);
    }
  }
  if (auditMode) rows.push(['证据锚点', (a.evidenceIds || a.rawRefs) ? `${a.evidenceIds} 个 ID${a.rawRefs ? ' · ' + a.rawRefs + ' 处原文定位' : ''}` : '未识别']);
  return `<div class="ib-section"><h4>基本信息</h4><dl class="ib-rows">${rows.map(([k, v]) => `<dt>${k}</dt><dd>${v}</dd>`).join('')}</dl></div>`;
}

function ibAudit(page) {
  const a = page.audit;
  const rows = [
    ['标记', auditChips(page, true) || `<span class="chip chip-ok">无自动警示</span>`],
    ['待核对项', String(a.gapItems)],
    ['未决表述', String(a.unresolved)],
    ['推断标记', String(a.inferred)],
    ['证据', esc(a.evidence)],
  ];
  return `<div class="ib-section"><h4>知识审计</h4>
    <dl class="ib-rows">${rows.map(([k, v]) => `<dt>${k}</dt><dd>${v}</dd>`).join('')}</dl>
    <p class="ib-note">标记由页面文本自动识别，仅供定位；无标记不等于内容完整。</p>
  </div>`;
}

/* 炼蛊链路：节点化展示，长链路不再堆成一行文字 */
function chainNode(o) {
  return o && o.linked
    ? `<a class="rc-node" href="#${o.route}">${esc(o.name)}</a>`
    : `<span class="rc-node rc-node--plain" title="本网站没有该蛊虫页">${esc(o ? o.name : '—')}</span>`;
}

function chainHtml(recipe) {
  return `${(recipe.inputs || []).map(chainNode).join('<span class="rc-arrow">+</span>')}<span class="rc-arrow rc-arrow--to">→</span>${chainNode(recipe.output)}`;
}

function ibGame(g) {
  const s = g.stats || {};
  const rows = [];
  if (s.rank != null) rows.push(['转数', `${esc(s.rank)} 转`]);
  if (s.rarity) rows.push(['稀有度', esc(s.rarity)]);
  if (s.v1_effect) rows.push(['v1 效果', esc(`${s.v1_effect.kind}${s.v1_effect.amount != null ? ' ' + s.v1_effect.amount : ''}${s.v1_effect.ignoreEvasion ? ' · 忽略闪避' : ''}`)]);
  if (s.essence_cost != null) rows.push(['真元消耗', esc(s.essence_cost)]);
  // 游戏仓库自带的对照记录，只能表示「游戏侧怎么看」，不能裁定原著；
  // 它没记到的原著侧如实写「未记录」，不渲染成 null 转
  if (g.lore) {
    const side = (v) => (v == null || v === '' ? '未记录' : `${v} 转`);
    rows.push(['游戏↔原著', esc(`《问真》${side(g.lore.gameRank)} / 原著 ${side(g.lore.loreRank)} · ${g.lore.status || ''}`)]);
  }
  const live = (g.recipes || []).filter(r => !r.retired);
  if (live.length) rows.push(['炼蛊链', `<div class="rc-chains">${live.map(r => `<div class="rc-chain">${chainHtml(r)}</div>`).join('')}</div>`]);
  if ((g.shops || []).length) rows.push(['商店', esc(g.shops.map(o => `元石 ${o.stoneCost}`).join(' · '))]);
  if (!rows.length) return '';
  return `<div class="ib-section"><h4>《问真》实现</h4>
    <dl class="ib-rows">${rows.map(([k, v]) => `<dt>${esc(k)}</dt><dd>${v}</dd>`).join('')}</dl>
    <p class="ib-note">构建期从游戏仓库读取，数值以游戏仓库为准；详见正文「《问真》当前实现」。</p>
  </div>`;
}

function infobox(page) {
  if (page.category === 'home') return '';
  const rel = relatedRoutes(page);
  const groups = {};
  rel.forEach(r => { const p = byRoute(r); if (p) (groups[p.category] = groups[p.category] || []).push(r); });

  let detail = ibBase(page);

  if (page.category === 'characters') {
    const chars = groups.characters || [];
    const others = rel.filter(r => byRoute(r) && byRoute(r).category !== 'characters');
    if (chars.length) detail += `<div class="ib-section"><h4>人物关系</h4><div class="ib-links">${linkChips(chars)}</div></div>`;
    if (others.length) detail += `<div class="ib-section"><h4>相关条目</h4><div class="ib-links">${linkChips(others, 18)}</div>${others.length > 18 ? `<p class="ib-more">另有 ${others.length - 18} 条正文内链</p>` : ''}</div>`;
  } else if (page.category === 'gu') {
    if (page.game) detail += ibGame(page.game);
    if (rel.length) detail += `<div class="ib-section"><h4>相关条目</h4><div class="ib-links">${linkChips(rel, 16)}</div>${rel.length > 16 ? `<p class="ib-more">另有 ${rel.length - 16} 条正文内链</p>` : ''}</div>`;
  } else {
    const order = ['world', 'rules', 'gu', 'characters', 'events', 'themes'];
    const flat = [];
    order.forEach(k => (groups[k] || []).forEach(r => flat.push(r)));
    if (flat.length) detail += `<div class="ib-section"><h4>相关条目</h4><div class="ib-links">${linkChips(flat, 16)}</div>${flat.length > 16 ? `<p class="ib-more">另有 ${flat.length - 16} 条正文内链</p>` : ''}</div>`;
  }

  if (auditMode) detail += ibAudit(page);

  const foot = [];
  if (auditMode) {
    if (page.date) foot.push(`最后补全 ${esc(page.date)}`);
    if (page.schema) foot.push(`schema v${esc(page.schema)}`);
  }

  return `<aside class="col-infobox"><div class="infobox">${ibFigure(page)}<div class="infobox-detail">${detail}${foot.length ? `<div class="ib-section"><p class="ib-note">${foot.join(' · ')}</p></div>` : ''}</div></div></aside>`;
}

/* ---------------- 视图：首页 ---------------- */

function viewHome() {
  const s = auditSummary();
  const entries = entryPages();
  const cats = Object.entries(db.categories);

  const catRows = cats.map(([key, label]) => {
    const items = entries.filter(p => p.category === key);
    const samples = (key === 'world'
      ? items.filter(p => entryType(p) === '流派')
      : items).slice(0, 4);
    return `<a class="cat-row" href="#/category/${key}">
      <span class="cat-name">${esc(label)}</span><span class="cat-count">${items.length} 条</span>
      <span class="cat-samples">${samples.map(p => esc(p.title)).join(' · ') || '—'}</span>
    </a>`;
  }).join('');

  const recent = entries.filter(p => p.date).sort((a, b) => b.date.localeCompare(a.date)).slice(0, 7);
  const attention = entries.slice().sort((a, b) => relevance(b) - relevance(a) || a.title.localeCompare(b.title)).slice(0, 7);

  const miniRow = (p, meta) => `<a class="mini-row" href="#${p.route}">
    <div class="t">${esc(p.title)}</div>
    <div class="m"><span class="cat">${esc(catLabel(p.category))}</span>${meta}</div>
  </a>`;

  $('#main').innerHTML = `<div class="home">
    <section class="home-hero">
      <div class="eyebrow">Wenzhen · Knowledge Base</div>
      <h1>问真知识库</h1>
      <p class="lede">${entries.length} 条设定条目，来自本地蒸馏 Wiki。左侧按知识门类导航，中央是正文，右侧是条目信息；开启审计模式可查看每条内容的核对状态。</p>
      <div class="hero-search">
        <svg viewBox="0 0 20 20" aria-hidden="true"><circle cx="8.6" cy="8.6" r="5.4" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M12.7 12.7L17 17" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/></svg>
        <input id="hero-search" type="search" placeholder="搜索蛊虫、人物、流派、事件…" autocomplete="off" aria-label="搜索知识库">
      </div>
      <div class="hero-quick"><a href="#/paths/README">阅读路径</a>${KIND_KNOWLEDGE().map(k => `<a href="#/kind/${k}">${esc(kindLabel(k))}</a>`).join('')}<a href="#/browse">全部条目</a></div>
    </section>

    <section class="home-section">
      <header><h2>五条阅读路径</h2><span class="hint">不知道从哪读起，选一条最像你的</span><a class="more" href="#/category/paths">全部路径 &rarr;</a></header>
      <div class="path-grid">
        ${(() => {
          const order = ['/paths/five-minute-world', '/paths/follow-fang-yuan', '/paths/fanfic-writer', '/paths/lore-researcher', '/paths/wenzhen-dev'];
          const briefs = {
            '/paths/five-minute-world': '访客速览：骨架 → 修炼 → 地域 → 蛊虫循环',
            '/paths/follow-fang-yuan': '剧情读者：故事弧 → 人物 → 关键事件',
            '/paths/fanfic-writer': '同人作者：动机关系 → 时代 → 限制 → 禁止误读',
            '/paths/lore-researcher': '研究者：规则索引 → canon → 证据回查',
            '/paths/wenzhen-dev': '开发：规则数值边界 → 游戏数据分界',
          };
          return order.map(r => {
            const p = byRoute(r);
            if (!p) return '';
            return `<a class="path-card" href="#${p.route}">
              <div class="path-title">${esc(p.title)}</div>
              <div class="path-brief">${esc(briefs[r] || p.description || '')}</div>
            </a>`;
          }).join('');
        })()}
      </div>
    </section>

    <section class="home-section">
      <header><h2>知识</h2><span class="hint">具体对象与世界事实，不与总表混排</span></header>
      <div class="cat-index">
        ${KIND_KNOWLEDGE().map(k => {
          const items = pagesByKind(k);
          if (!items.length) return '';
          const href = `#/kind/${k}`;
          return `<a class="cat-row" href="${href}"><span class="cat-name">${esc(kindLabel(k))}</span><span class="cat-count">${items.length} 条</span><span class="cat-samples">${items.slice(0,4).map(p=>esc(p.title)).join(' · ')}</span></a>`;
        }).join('')}
      </div>
    </section>
    <section class="home-section">
      <header><h2>索引与资料</h2><span class="hint">总表、关系、资料——不抢实体列表</span></header>
      <div class="cat-index">
        ${KIND_META().map(k => {
          const items = pagesByKind(k);
          if (!items.length) return '';
          return `<a class="cat-row" href="#/kind/${k}"><span class="cat-name">${esc(kindLabel(k))}</span><span class="cat-count">${items.length} 条</span><span class="cat-samples">${items.slice(0,4).map(p=>esc(p.title)).join(' · ')}</span></a>`;
        }).join('')}
      </div>
    </section>

    <section class="home-section">
      <header><h2>知识审计摘要</h2><span class="hint">标记可叠加，条形为该特征占全库比例</span></header>
      <div class="audit-card">
        <div class="audit-stats">
          <div class="audit-stat"><div class="num">${s.total}</div><div class="lbl">条目总数</div></div>
          <div class="audit-stat"><div class="num ok">${s.ok}</div><div class="lbl">无自动警示</div></div>
          <div class="audit-stat"><div class="num dim">${entryPages().reduce((n, p) => n + p.audit.gapItems, 0)}</div><div class="lbl">待核对项总计</div></div>
        </div>
        <div class="audit-rows">
          ${[['gap', '待核对'], ['inferred', '含推导'], ['evidence', '缺证据'], ['thin', '信息不足']].map(([id, label]) => {
            const n = s[id];
            const pct = Math.round(n / s.total * 100);
            return `<div class="audit-row"><span class="k">${label}</span><span class="v">${n}</span><span class="bar"><i style="width:${pct}%;background:${AUDIT_COLOR[id]}"></i></span><span class="p">${pct}%</span></div>`;
          }).join('')}
        </div>
        <p class="audit-row-note">「待核对」在当前语料中近乎全覆盖（${s.gap}/${s.total}），区分度低；「含推导」「缺证据」更能定位需要优先处理的条目。</p>
      </div>
    </section>

    <section class="home-section">
      <header><h2>最近补全 / 值得研究</h2><span class="hint">左：按补全日期；右：按缺口权重</span></header>
      <div class="two-col">
        <div>${recent.map(p => miniRow(p, `<span>${esc(p.date)}</span>`)).join('')}</div>
        <div>${attention.map(p => miniRow(p, auditChips(p, false))).join('')}</div>
      </div>
    </section>
  </div>`;

  const hero = $('#hero-search');
  hero.addEventListener('input', () => {
    searchQuery = hero.value.trim();
    location.hash = '#/search' + (searchQuery ? '?q=' + encodeURIComponent(searchQuery) : '');
  });
}

/* ---------------- 视图：列表（分类 / 全部 / 搜索） ---------------- */

function entryRow(p) {
  const type = entryType(p);
  return `<a class="entry" href="#${p.route}">
    <div class="entry-head">
      <span class="entry-title">${esc(p.title)}</span>
      <span class="chip chip-type">${esc(type)}</span>
      ${p.kind && p.kind !== 'entity' && p.kind !== 'event' ? kindChip(p) : ''}
      ${auditMode ? auditChips(p, false) : ''}
    </div>
    <p class="entry-desc">${esc(p.description || p.text.slice(0, 110))}</p>
  </a>`;
}

function listFilterIds(pages) {
  const all = `<button type="button" class="chip${listFilter === 'all' ? ' chip-live' : ''}" data-filter="all">全部 ${pages.length}</button>`;
  return all + FLAG_ORDER.map(id => {
    const n = pages.filter(p => auditFlags(p).includes(id)).length;
    return `<button type="button" class="chip${listFilter === id ? ' chip-live' : ''}" data-filter="${id}"${n ? '' : ' disabled'}>${TAGS[id].label} ${n}</button>`;
  }).join('');
}

function viewList(opts) {
  const { title, subtitle, base, activeKey, filterable = true, hub = null } = opts;
  const q = searchQuery.toLocaleLowerCase();
  const matched = base.filter(p => !q || `${p.title} ${p.description} ${p.text}`.toLocaleLowerCase().includes(q));
  const shown = !filterable || listFilter === 'all' ? matched : matched.filter(p => auditFlags(p).includes(listFilter));
  // 有检索词时按相关度排序：标题命中优先于简介、正文，避免目标页被埋在全文字命中里
  const sorted = q
    ? shown.slice().sort((a, b) => relevanceTo(b, q) - relevanceTo(a, q) || a.title.localeCompare(b.title, 'zh'))
    : shown.slice().sort((a, b) => a.title.localeCompare(b.title, 'zh'));

  const body = `<div class="col-body">
    <nav class="crumbs"><a href="#/">首页</a><span class="sep">/</span><span>${esc(title)}</span></nav>
    <h1 class="page-title">${esc(title)}</h1>
    ${subtitle ? `<p class="page-sub">${subtitle}</p>` : ''}
    ${hub ? `<p class="page-sub">导览页：<a href="#${hub.route}">${esc(hub.title)}</a></p>` : ''}
    <div class="toolbar">
      <span class="label">知识状态</span>
      ${filterable ? listFilterIds(matched) : `<span class="chip chip-ok">共 ${base.length} 条</span>`}
      <span class="spacer"></span>
      <span class="count">显示 ${sorted.length} / ${matched.length} 条</span>
    </div>
    ${sorted.length ? `<div class="entry-list">${sorted.map(entryRow).join('')}</div>` : '<div class="empty">没有符合条件的条目。可更换筛选或检索词。</div>'}
  </div>`;

  $('#main').innerHTML = `<div class="list-grid"><aside class="col-rail">${railHtml(activeKey, opts.activeRoute || '', '', opts.activeKind || '')}</aside>${body}</div>`;
  $$('[data-filter]').forEach(el => el.addEventListener('click', () => { listFilter = el.dataset.filter; render(); }));
}

/* ---------------- 视图：详情 ---------------- */

// 「主题档案」页型：每个主题内三层知识分开披露
// gap（待核对）是独立的「缺口状态」，不属于合理推导，单独成层可查看
const LAYER_LABEL = { canon: '原著事实', research: '合理推导', game: '《问真》实现', notes: '整理笔记', meta: '结构说明', gap: '缺口' };
const LAYER_CLS = { canon: 't-canon', research: 't-research', game: 't-game', notes: 't-notes', meta: 't-meta', gap: 't-gap' };
const KIND_SECTION = { canon: '原著明确内容', notes: '资料整理', analysis: '分析与解读', gaps: '待核对' };
const LAYER_VIEWS = [['all', '全部'], ['canon', '原著'], ['research', '研究'], ['gap', '缺口'], ['game', '游戏']];
const VIEW_ALLOW = { all: null, canon: ['canon'], research: ['research', 'notes', 'meta'], gap: ['gap'], game: ['game'] };
let layerView = localStorage.getItem('wikiLayerView') || 'all';

// 阅读与审计使用同一份完整正文；分层筛选只由读者的显式选择决定。
function effectiveAllow(view) {
  return VIEW_ALLOW[view];
}

function layerBar() {
  const hint = auditMode
    ? '原著事实 / 合理推导 /《问真》实现 三层可分看，缺口（待核对）单列；正文里的证据 ID 可点开核对行号'
    : '默认展示全部正文；原著事实、整理笔记、分析、待核对与游戏改编分层标明，可按需筛选，证据 ID 可点开回查';
  return `<div class="layer-bar">
    <span class="lb-label">按层查看</span>
    ${LAYER_VIEWS.map(([id, label]) => `<button type="button" class="lb-btn${layerView === id ? ' live' : ''}" data-view="${id}" aria-pressed="${layerView === id}">${label}</button>`).join('')}
    <span class="lb-hint">${hint}</span>
  </div>`;
}

function themeBlockHtml(block) {
  return `<div class="theme-block" data-layer="${block.layer}">
    <div class="blk-head"><span class="layer-tag ${LAYER_CLS[block.layer] || ''}">${LAYER_LABEL[block.layer] || '其他'}</span></div>
    <div class="blk-body article">${block.html}</div>
  </div>`;
}

function docSectionHtml(sec) {
  if (sec.kind === 'themes') {
    return `<section class="doc-sec doc-sec--themes" data-layer="mixed" id="${sec.id}">
      <h2>${esc(sec.title)}${auditMode ? '<span class="sec-note">提案结构 · 与下方 v2 证据块并存</span>' : ''}</h2>
      ${(sec.items || []).map((item, i) => `<article class="theme" data-theme>
        <h3 id="${sec.id}-${i}">${esc(item.title)}</h3>
        ${item.blocks.map(themeBlockHtml).join('')}
      </article>`).join('')}
    </section>`;
  }
  const tag = KIND_SECTION[sec.kind];
  const ds = tag ? ` data-section="${tag}"` : '';
  return `<section class="doc-sec" data-layer="${sec.layer}" data-kind="${sec.kind}" id="${sec.id}"${ds}>
    <h2${ds}>${esc(sec.title)}<span class="layer-tag ${LAYER_CLS[sec.layer] || ''}">${LAYER_LABEL[sec.layer] || ''}</span></h2>
    <div class="sec-body article">${sec.html}</div>
  </section>`;
}

/* 《问真》游戏投影：构建期从游戏仓库读取，只读展示 */
// 构建期游戏数据源可能不完整（如 gu.json 存在未解决的合并冲突被截断）。
// 这时「本页读不到运行条目」是站点自己的数据缺口，不能断称为游戏侧的未收录 / 未实现。
const gameDataIncomplete = () => !!(db.gameMeta && (db.gameMeta.warnings || []).length);

function gameProjectionHtml(page) {
  const g = page.game;
  const src = esc((db.gameMeta && db.gameMeta.sources || []).join(' · '));
  const warn = (db.gameMeta && db.gameMeta.warnings || []).map(w => `<p class="gp-warn">${esc(w)}</p>`).join('');
  // 游戏侧缺失时也要如实说明：原著与《问真》是两个独立权威来源，不能静默略过
  if (!g) {
    if (!isGuEntity(page)) return '';
    return `<section class="doc-sec game-projection" data-layer="game" id="game-projection">
      <h2>《问真》当前实现<span class="layer-tag t-game">构建期生成 · 以游戏仓库为准</span></h2>
      <div class="sec-body article">
        ${warn}
        <p class="gp-note">${gameDataIncomplete()
          ? '构建期游戏数据源不完整（见上），本页未能读到该蛊虫的运行条目：<b>无法判定《问真》是否实现</b>。'
          : '运行数据中暂无该蛊虫条目：<b>《问真》尚未实现</b>。'}设计模型不等于运行实现，不在此冒充已实现。这不构成对原著内容的否定，原著一侧见上方「原著明确内容」。</p>
        <p class="gp-src">来源：${src}</p>
      </div>
    </section>`;
  }
  const s = g.stats || {};
  const stats = [];
  if (s.rank != null) stats.push(['转数', `${s.rank} 转`]);
  if (s.rarity) stats.push(['稀有度', s.rarity]);
  if (s.school) stats.push(['流派', s.school]);
  if (s.slot_role || s.role) stats.push(['定位', s.slot_role || s.role]);
  if (s.value != null) stats.push(['价值', String(s.value)]);
  if (s.v1_effect) stats.push(['v1 效果', `${s.v1_effect.kind}${s.v1_effect.amount != null ? ' ' + s.v1_effect.amount : ''}${s.v1_effect.ignoreEvasion ? ' · 忽略闪避' : ''}`]);
  if (s.essence_cost != null) stats.push(['真元消耗', String(s.essence_cost)]);
  if (s.true_qi_cost != null) stats.push(['真气消耗', String(s.true_qi_cost)]);
  if (s.feeding_cost != null) stats.push(['喂养消耗', String(s.feeding_cost)]);
  if (s.replace_value != null) stats.push(['替换值', String(s.replace_value)]);
  if (s.buildTags) stats.push(['构筑标签', s.buildTags.join(' · ')]);
  if (s.synergy_hooks) stats.push(['协同钩子', s.synergy_hooks.join(' · ')]);
  if (s.combat) stats.push(['战斗脚本', s.combat]);
  if (s.field_actions) stats.push(['场地动作', s.field_actions.join(' · ')]);
  if (s.source_class) stats.push(['来源类别', s.source_class]);
  if (g.lore) {
    const side = (v) => (v == null || v === '' ? '未记录' : `${v} 转`);
    stats.push(['游戏↔原著', `${g.lore.name}：《问真》${side(g.lore.gameRank)} / 原著（游戏侧记录）${side(g.lore.loreRank)} · ${g.lore.status || ''}${g.lore.anchor ? ' · ' + g.lore.anchor : ''}`]);
  }

  const recipes = (g.recipes || []).map(r => `<li class="${r.retired ? 'retired' : ''}">
      <span class="rc-id">${esc(r.id)}</span>
      <span class="rc-chain">${chainHtml(r)}</span>
      ${r.outputRank ? `<span class="rc-meta">产出 ${r.outputRank} 转</span>` : ''}
      ${Object.keys(r.materials || {}).length ? `<span class="rc-meta">材料 ${Object.entries(r.materials).map(([k, v]) => `${esc(k)}×${v}`).join('、')}</span>` : ''}
      ${r.branchLabel ? `<span class="rc-meta">${esc(r.branchLabel)}</span>` : ''}
      ${r.stoneCost ? `<span class="rc-meta">元石 ${r.stoneCost}</span>` : ''}
      ${r.retired ? `<span class="rc-meta retired-tag">已退役${r.retireReason ? ' · ' + esc(r.retireReason) : ''}</span>` : ''}
    </li>`).join('');
  const shops = (g.shops || []).map(o => `<li><span class="rc-id">${esc(o.id)}</span><span class="rc-meta">${esc(o.kind)} · 元石 ${o.stoneCost}${o.tier != null ? ' · tier ' + o.tier : ''}</span></li>`).join('');
  const loot = (g.lootTiers || []).map(l => `<li><span class="rc-meta">${esc(l.tier)} 池 · ${esc(l.rarity)} 稀有度${l.chancePct != null ? ' · 出蛊率 ' + l.chancePct + '%' : ''}</span></li>`).join('');

  return `<section class="doc-sec game-projection" data-layer="game" id="game-projection">
    <h2>《问真》当前实现<span class="layer-tag t-game">构建期生成 · 以游戏仓库为准</span></h2>
    <div class="sec-body article">
      ${auditMode ? '<p class="gp-note">以下内容由构建脚本在打包时从游戏仓库读取，页面不手工维护第二份游戏数据；数值如有出入，以游戏仓库为准。</p>' : ''}
      ${warn}
      <dl class="gp-rows">${stats.map(([k, v]) => `<dt>${esc(k)}</dt><dd>${esc(v)}</dd>`).join('')}</dl>
      ${recipes ? `<h4>炼蛊链 · 配方</h4><ul class="gp-list">${recipes}</ul>` : ''}
      ${shops ? `<h4>商店</h4><ul class="gp-list">${shops}</ul>` : ''}
      ${loot ? `<h4>掉落</h4><ul class="gp-list">${loot}</ul>` : ''}
      <p class="gp-src">来源：${src}</p>
    </div>
  </section>`;
}

function viewArticle(page) {
  const a = page.audit;
  const sources = (Array.isArray(page.sources) ? page.sources : [page.sources]).filter(Boolean);
  const isHub = page.route.endsWith('/index') || page.category === 'home';

  $('#main').innerHTML = `<div class="wiki-grid">
    <aside class="col-rail">${railHtml(page.category === 'home' ? '' : page.category, page.route, isHub ? '' : tocHtml(), page.kind || '')}</aside>
    <div class="col-body">
      <nav class="crumbs" aria-label="面包屑">
        <a href="#/">首页</a><span class="sep">/</span>
        ${page.category === 'home' ? '<span aria-current="page">Wiki 原入口</span>' : `${classificationLink(page)}<span class="sep">/</span><span aria-current="page">${esc(page.title)}</span>`}
      </nav>
      ${page.category === 'home' ? '' : `<div class="back-row"><a class="back-link" href="#/${Object.hasOwn(db.kinds || {}, page.kind) ? `kind/${esc(page.kind)}` : `category/${esc(page.category)}`}">
        <span aria-hidden="true">←</span> 返回${esc(Object.hasOwn(db.kinds || {}, page.kind) ? kindLabel(page.kind) : catLabel(page.category))}列表</a></div>`}
      <h1 class="page-title">${esc(page.title)}</h1>
      ${page.description ? `<p class="lede" id="page-lede">${esc(page.description)}</p>` : ''}
      <div class="meta-row">
        <span class="chip chip-type">${esc(entryType(page))}</span>
        ${page.category === 'gu' ? rankChip(page) : ''}
        ${auditMode ? auditChips(page, true) : ''}
        ${auditMode && (a.evidenceIds || a.rawRefs) ? `<span class="sep"></span><span class="meta-note">证据锚点 ${a.evidenceIds} 个 ID${a.rawRefs ? ` · ${a.rawRefs} 处原文定位` : ''}</span>` : ''}
        ${auditMode && page.date ? `<span class="meta-note">最后补全 ${esc(page.date)}</span>` : ''}
      </div>
      ${auditMode ? `<div class="audit-banner"><span>审阅</span><div><b>审计模式已开启。</b>正文各章节按识别结果着色；标记由页面文本自动识别，仅帮助定位缺失章节，不代表原著不存在。</div></div>` : ''}
      ${page.doc ? layerBar() : ''}
      ${page.doc && auditMode ? `<div class="doc-intro article">${page.doc.intro}</div>` : ''}
      ${page.doc
        ? `<div class="doc" data-view="all">${page.doc.sections.map(docSectionHtml).join('')}</div>
           ${gameProjectionHtml(page)}`
        : `<article class="article">${page.html}</article>${gameProjectionHtml(page)}`}
      ${auditMode ? `<div class="source-block">
        <b>页面来源</b>：${sources.length ? sources.map(s => `<code>${esc(s)}</code>`).join(' · ') : '未登记'}<br>
        原文文件未上传至网站；证据 ID 与行号保留供本地核对。
      </div>` : ''}
    </div>
    ${infobox(page)}
  </div>`;

  if (page.doc) enhanceDoc(page);
  else enhanceArticle(page, isHub);
  bindEpubCitations($('#main'), page);
}

// 分层切换按钮：doc 页型与旧 article 页型共用同一套控件，只有应用函数不同
function bindLayerBar(apply) {
  $$('.layer-bar button[data-view]').forEach(btn => btn.addEventListener('click', () => {
    layerView = btn.dataset.view;
    localStorage.setItem('wikiLayerView', layerView);
    $$('.layer-bar button[data-view]').forEach(x => {
      x.classList.toggle('live', x.dataset.view === layerView);
      x.setAttribute('aria-pressed', String(x.dataset.view === layerView));
    });
    apply(layerView);
  }));
}

// 目录跟随分层视图：指向已隐藏章节的目录项一并隐藏，避免点了没反应
function syncTocVisibility() {
  $$('#toc a').forEach(link => {
    const el = document.getElementById((link.getAttribute('href') || '').slice(1));
    link.classList.toggle('hidden', !!el && !!el.closest('.hidden'));
  });
  $$('#toc .toc-group').forEach(group => {
    const links = $$('a', group);
    group.classList.toggle('hidden', links.length > 0 && links.every(l => l.classList.contains('hidden')));
  });
}

// 旧页型（无「主题档案」）按同一套层规则渐进披露：层归属由构建期 data-layer 给出，
// 页面上没有可收起的层时该控件自然不出现——不新增任何页型专属组件。
function applyArticleView(view) {
  const allow = effectiveAllow(view);
  $$('.article-sec').forEach(sec => {
    const l = sec.dataset.layer;
    const on = !l || !allow || allow.includes(l);
    sec.classList.toggle('hidden', !on);
  });
  const gp = $('.game-projection');
  if (gp) gp.classList.toggle('hidden', !(view === 'all' || view === 'game'));
  syncTocVisibility();
}

function applyLayerView(view) {
  const doc = $('.doc');
  if (!doc) return;
  doc.dataset.view = view;
  const allow = effectiveAllow(view);
  $$('.doc-sec', doc).forEach(sec => {
    if (sec.classList.contains('doc-sec--themes')) {
      let shown = 0;
      $$('.theme', sec).forEach(theme => {
        let n = 0;
        $$('.theme-block', theme).forEach(block => {
          const on = !allow || allow.includes(block.dataset.layer);
          block.classList.toggle('hidden', !on);
          if (on) n++;
        });
        theme.classList.toggle('hidden', n === 0);
        if (n) shown++;
      });
      sec.classList.toggle('hidden', shown === 0);
    } else {
      sec.classList.toggle('hidden', !!allow && !allow.includes(sec.dataset.layer));
    }
  });
  const gp = $('.game-projection');
  if (gp) gp.classList.toggle('hidden', !(view === 'all' || view === 'game'));
  syncTocVisibility();
}

/* doc 页型的目录、滚动高亮与分层切换 */
function enhanceDoc(page) {
  // 目录按真实 h2/h3 层级嵌套：主题档案（h2）下挂各主题（h3）；
  // v2 强制块归入「证据骨架」组，与主题档案并列，而不是和它平铺。
  const anchors = [];
  const groups = [];
  let skeleton = null;
  page.doc.sections.forEach(sec => {
    if (sec.kind === 'themes') {
      const children = (sec.items || []).map((item, i) => ({ id: `${sec.id}-${i}`, label: item.title }));
      groups.push({ id: sec.id, label: sec.title, children });
      anchors.push({ id: sec.id }, ...children);
    } else if (sec.kind === 'proposal') {
      groups.push({ id: sec.id, label: sec.title, children: [] });
      anchors.push({ id: sec.id });
    } else {
      if (!skeleton) { skeleton = { label: '证据骨架', children: [] }; groups.push(skeleton); }
      skeleton.children.push({ id: sec.id, label: sec.title });
      anchors.push({ id: sec.id });
    }
  });
  groups.push({ id: 'game-projection', label: '《问真》当前实现', children: [] });
  anchors.push({ id: 'game-projection' });

  const toc = $('#toc');
  if (toc) {
    toc.insertAdjacentHTML('beforeend', groups.map(g => {
      const head = g.id
        ? `<a class="toc-l1" href="#${g.id}">${esc(g.label)}</a>`
        : `<span class="toc-l1 toc-group-label">${esc(g.label)}</span>`;
      return `<div class="toc-group">${head}${g.children.map(c => `<a class="toc-l2" href="#${c.id}">${esc(c.label)}</a>`).join('')}</div>`;
    }).join(''));
    const links = $$('a', toc);
    const spy = () => {
      const y = window.scrollY + 130;
      let current = anchors[0].id;
      anchors.forEach(x => { const el = document.getElementById(x.id); if (el && el.offsetTop <= y && !el.classList.contains('hidden')) current = x.id; });
      links.forEach(l => l.classList.toggle('current', l.getAttribute('href') === '#' + current));
    };
    let ticking = false;
    window.addEventListener('scroll', () => {
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(() => { ticking = false; spy(); });
    }, { passive: true });
    spy();
  }

  bindLayerBar(applyLayerView);
  applyLayerView(layerView);

  if (auditMode) {
    $$('.doc-sec h2[data-section]').forEach(h => {
      const id = SECTION_TAG[h.dataset.section];
      if (id) h.insertAdjacentHTML('beforeend', `<span class="chip ${TAGS[id].cls} section-audit">${TAGS[id].label}</span>`);
    });
  }
}

/* 目录 + 滚动高亮 + 章节审计标记（旧页型） */
function enhanceArticle(page, skipToc = false) {
  const article = $('#main article');
  const toc = $('#toc');
  if (!article) return;
  const heads = $$('h2', article);
  heads.forEach((h, i) => { h.id ||= 'sec-' + i; });

  // 把扁平的「h2 + 后续兄弟节点」切成章节块，带上构建期标注的层，供渐进披露复用
  if (heads.length && article.querySelector('h2[data-layer]')) {
    const frag = document.createDocumentFragment();
    let cur = null;
    Array.from(article.childNodes).forEach(node => {
      if (node.nodeType === 1 && node.tagName === 'H2') {
        cur = document.createElement('section');
        cur.className = 'article-sec';
        cur.dataset.layer = node.dataset.layer || '';
        frag.appendChild(cur);
      }
      (cur || frag).appendChild(node);
    });
    article.replaceChildren(frag);
  }

  const lede = $('#page-lede');
  if (lede && page && page.description && leadIsRedundant(page.description, article.innerText)) lede.remove();

  if (!skipToc && toc && heads.length) {
    toc.insertAdjacentHTML('beforeend', heads.map(h => {
      const id = SECTION_TAG[h.dataset.section];
      const chip = auditMode && id
        ? `<span class="chip ${TAGS[id].cls}" style="margin-left:7px">${TAGS[id].label}</span>` : '';
      return `<a href="#${h.id}" data-section="${esc(h.dataset.section || '')}">${esc(h.textContent.trim())}${chip}</a>`;
    }).join(''));

    const links = $$('a', toc);
    const spy = () => {
      const y = window.scrollY + 120;
      let current = heads[0];
      heads.forEach(h => { if (h.offsetTop <= y) current = h; });
      links.forEach(l => l.classList.toggle('current', l.getAttribute('href') === '#' + current.id));
    };
    let ticking = false;
    window.addEventListener('scroll', () => {
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(() => { ticking = false; spy(); });
    }, { passive: true });
    spy();
  }

  if (auditMode) {
    heads.forEach(h => {
      const id = SECTION_TAG[h.dataset.section];
      if (id) h.insertAdjacentHTML('beforeend', `<span class="chip ${TAGS[id].cls} section-audit">${TAGS[id].label}</span>`);
    });
  }

  // 有可收起的层（推导 / 缺口 / 结构说明）时才出现「按层查看」；纯原著页不出现该控件
  const hideable = $$('.article-sec', article).some(s => s.dataset.layer && s.dataset.layer !== 'canon');
  if (hideable) {
    article.insertAdjacentHTML('beforebegin', layerBar());
    bindLayerBar(applyArticleView);
    applyArticleView(layerView);
  }
}

/* 证据行号展开 + 审计标记跳转 + 窄屏导航壳：全局委托，新旧页型通用 */
document.addEventListener('click', (e) => {
  // 窄屏导航壳开合
  const foldBtn = e.target.closest('.rail-toggle');
  if (foldBtn) {
    const foldEl = foldBtn.closest('.rail-fold');
    setRailFold(foldEl, foldEl.dataset.open !== 'true');
    return;
  }
  // 页内导航只滚动，保留当前文章路由，后续切换审计模式仍停留在本页。
  const link = e.target.closest('a[href^="#"]');
  const href = link?.getAttribute('href');
  // 点目录里的链接时，若导航壳处于收起状态先展开，否则滚动到的章节被藏起来。
  const fold = e.target.closest('.rail-fold');
  if (fold && fold.dataset.open === 'false') setRailFold(fold, true);
  if (href && !href.startsWith('#/')) {
    const target = document.getElementById(decodeURIComponent(href.slice(1)));
    if (target) {
      e.preventDefault();
      target.scrollIntoView({ behavior: 'smooth', block: 'start' });
      return;
    }
  }
  const btn = e.target.closest('button.ev');
  if (btn) {
    const host = btn.closest('.blk-body, .sec-body, .doc-intro, .article') || btn.parentElement;
    const open = host.querySelector(`.ev-detail[data-ev="${btn.dataset.ev}"]`);
    host.querySelectorAll('.ev-detail').forEach(n => n.remove());
    host.querySelectorAll('button.ev').forEach(b => b.setAttribute('aria-expanded', 'false'));
    if (open) return;
    const detail = document.createElement('div');
    detail.className = 'ev-detail';
    detail.dataset.ev = btn.dataset.ev;
    detail.innerHTML = `<b>证据 ${esc(btn.dataset.ev)}</b>${btn.dataset.from ? ` · 原文 <code>${btn.dataset.from}–${btn.dataset.to} 行</code>` : '（未附行号）'}
      <span class="ev-note">原文未随站分发；请在本地 <code>source/蛊真人-clean.txt</code> 核对。行号属「段一」范围 426–34,410。</span>`;
    host.appendChild(detail);
    btn.setAttribute('aria-expanded', 'true');
    return;
  }
  const goto = e.target.closest('[data-goto-tag]');
  if (goto) {
    const sec = TAG_SECTION[goto.dataset.gotoTag];
    const target = sec ? document.querySelector(`h2[data-section="${sec}"]`) : null;
    const node = target || $('.doc-sec h2') || $('article h2');
    if (!node) return;
    node.scrollIntoView({ behavior: 'smooth', block: 'start' });
    node.classList.add('marked-section');
    setTimeout(() => node.classList.remove('marked-section'), 1800);
  }
});

/* ---------------- 视图：美术馆 ---------------- */

function viewGallery() {
  const q = searchQuery.toLocaleLowerCase();
  const items = db.art.filter(i => !q || `${i.name} ${i.original} ${i.groupName}`.toLocaleLowerCase().includes(q));
  const groups = {};
  items.forEach(i => (groups[i.groupName] = groups[i.groupName] || []).push(i));
  const sections = Object.entries(groups).map(([name, list]) => `<section class="home-section">
    <header><h2>${esc(name)}</h2><span class="hint">${list.length} 张</span></header>
    <div class="art-grid">${list.map(i => `<figure class="art-card"><a href="${encodeURI(i.path)}" target="_blank" rel="noopener"><img loading="lazy" src="${encodeURI(i.path)}" alt="${esc(i.name)}"></a><figcaption>${esc(i.name)}<small>${esc(i.original)}</small></figcaption></figure>`).join('')}</div>
  </section>`).join('');

  $('#main').innerHTML = `<div class="home">
    <nav class="crumbs"><a href="#/">首页</a><span class="sep">/</span><span>美术馆</span></nav>
    <h1 class="page-title">美术馆</h1>
    <p class="page-sub">来自现有游戏素材目录的 ${db.art.length} 张图片。素材说明与原著证据分开；图片文件名不自动作为设定事实。</p>
    <p class="count">显示 ${items.length} 张</p>
    ${sections || '<div class="empty">没有符合条件的素材。</div>'}
  </div>`;
}

/* ---------------- 路由 ---------------- */

function currentRoute() {
  const h = location.hash;
  // 页内锚点（#sec-3、#game-projection）不是路由：点过目录再刷新会带着锚点冷启动，
  // 此时按首页渲染，不能把一个存在的章节锚点重绘成「未找到」。
  if (h && !h.startsWith('#/')) return '/';
  return decodeURI(h.slice(1).split('?')[0] || '/');
}

function render() {
  if (!db) return;
  const route = currentRoute();
  const isArt = route === '/art';
  const isWorld = route === '/kind/world' || route === '/category/world';

  document.body.classList.toggle('audit-on', auditMode);
  const toggle = $('#audit-toggle');
  toggle.setAttribute('aria-pressed', String(auditMode));
  toggle.querySelector('b').textContent = auditMode ? '开' : '关';
  const activeTab = isArt ? 'art' : isWorld ? 'world' : 'wiki';
  $$('.topnav a[data-tab]').forEach(el => el.classList.toggle('active', el.dataset.tab === activeTab));

  const searchInput = $('#search');
  if (searchInput.value !== searchQuery) searchInput.value = searchQuery;

  if (isArt) {
    document.title = '美术馆 · 问真';
    viewGallery();
    return;
  }
  if (route === '/browse') {
    document.title = '全部条目 · 问真';
    viewList({ title: '全部条目', subtitle: `现有 ${entryPages().length} 条设定条目，按标题排序。`, base: entryPages(), activeRoute: route });
    return;
  }
  if (route === '/search') {
    document.title = '搜索 · 问真';
    viewList({
      title: searchQuery ? `搜索「${searchQuery}」` : '搜索',
      subtitle: '在全部条目的标题、简介与正文中检索。',
      base: entryPages(), activeRoute: route,
    });
    return;
  }
  if (route.startsWith('/kind/') && Object.hasOwn(db.kinds || {}, route.split('/')[2])) {
    const kind = route.split('/')[2];
    const base = pagesByKind(kind);
    document.title = `${kindLabel(kind)} · 问真`;
    viewList({ title: kindLabel(kind), subtitle: `${base.length} 条${kindLabel(kind)}条目。显示类型、简介与知识状态。`, base, activeKind: kind, activeRoute: route });
    return;
  }
  if (route.startsWith('/category/')) {
    const key = route.split('/')[2];
    const base = entryPages().filter(p => p.category === key);
    document.title = `${catLabel(key)} · 问真`;
    viewList({
      title: catLabel(key),
      subtitle: `${base.length} 条${catLabel(key)}条目。显示类型、简介与知识状态。`,
      base, activeKey: key, activeRoute: route, hub: hubOf(key),
    });
    return;
  }
  if (route === '/' || route === '/index') {
    document.title = '问真 · 知识库';
    viewHome();
    return;
  }
  const page = byRoute(route);
  if (page) {
    document.title = `${page.title} · 问真`;
    viewArticle(page);
    return;
  }
  // 旧 slug 兼容入口：详情页按游戏 id 口径改过名，旧链接只做跳转，不复制页面内容。
  // 目标路由必须在本次构建中真实存在才放行（构建期已过滤），否则仍如实显示「未找到」。
  const alias = db.routeAliases && db.routeAliases[route];
  if (alias && byRoute(alias)) { location.replace('#' + alias); return; }
  document.title = '未找到 · 问真';
  $('#main').innerHTML = `<div class="home"><h1 class="page-title">未找到该条目</h1><p class="page-sub">路由 <code>${esc(route)}</code> 不在知识库中。</p><p><a href="#/browse">浏览全部条目</a></p></div>`;
}

/* ---------------- 事件 ---------------- */

$('#audit-toggle').addEventListener('click', () => {
  auditMode = !auditMode;
  localStorage.setItem('wikiAuditMode', auditMode ? 'on' : 'off');
  render();
});

$('#search').addEventListener('input', () => {
  searchQuery = $('#search').value.trim();
  const route = currentRoute();
  if (route === '/search' || route === '/browse' || route.startsWith('/category/') || route.startsWith('/kind/')) {
    render();
    if (route === '/search') history.replaceState(null, '', '#/search' + (searchQuery ? '?q=' + encodeURIComponent(searchQuery) : ''));
  } else {
    location.hash = '#/search' + (searchQuery ? '?q=' + encodeURIComponent(searchQuery) : '');
  }
});

$('#search-form').addEventListener('submit', (e) => {
  e.preventDefault();
  if (currentRoute() !== '/search') location.hash = '#/search' + (searchQuery ? '?q=' + encodeURIComponent(searchQuery) : '');
});

document.addEventListener('keydown', (e) => {
  if (e.key === '/' && !/^(INPUT|TEXTAREA)$/.test(document.activeElement.tagName)) {
    e.preventDefault();
    $('#search').focus();
  } else if (e.key === 'Escape' && document.activeElement === $('#search')) {
    $('#search').blur();
  }
});

// 滚动位置记忆：按 URL（含查询串）记住离开时的位置，返回时恢复。
// 此前 hashchange 一律 scrollTo(0,0)，实测文章页滚到 2889px 后经列表页返回会归零。
// scrollRestoration 必须置 manual：否则浏览器自带的同文档滚动恢复会在 render 之后
// 覆盖我们恢复的位置（实测新列表页被顶到 702px 而非 0）。
if (typeof history !== 'undefined' && 'scrollRestoration' in history) history.scrollRestoration = 'manual';
const scrollMemory = new Map();
const scrollKey = () => location.hash || '#/';
// 必须记「正在离开的那个」URL：hashchange 触发时 location.hash 已经是新值了。
// 直接用 scrollKey() 会把上一页的位置存到新页面的键上（实测 4000 存进 #/kind/character，
// 恢复时被钳到该页最大可滚动高度 702）。
let leavingKey = scrollKey();
function rememberScroll() {
  if (!scrollMemory.has(leavingKey)) scrollMemory.set(leavingKey, Math.round(window.scrollY));
  leavingKey = scrollKey();
}
function restoreScroll() {
  const y = scrollMemory.get(scrollKey());
  // 用 instant 而非默认行为：恢复位置不该从顶部缓缓滑下来（html 是 scroll-behavior:smooth）。
  // reduced-motion 下同样立即到位。
  window.scrollTo({ top: y === undefined ? 0 : y, left: 0, behavior: 'instant' });
}

// 页内锚点（#sec-3、#game-projection）不是路由：详情页目录全靠它，不能重绘成「未找到」
window.addEventListener('hashchange', () => {
  if (!location.hash.startsWith('#/')) return;
  rememberScroll();
  if (currentRoute() === '/search') searchQuery = new URLSearchParams(location.hash.split('?')[1] || '').get('q') || '';
  render();
  restoreScroll();
});

fetch('data.json')
  .then(r => { if (!r.ok) throw new Error('data load failed'); return r.json(); })
  .then(data => {
    db = data;
    pageByRouteMap = new Map(db.pages.map(p => [p.route, p]));
    buildArtIndex();
    const q = new URLSearchParams(location.hash.split('?')[1] || '').get('q');
    if (q) searchQuery = q;
    try { render(); } catch (e) { console.error('render failed', e); throw e; }
  })
  .catch((err) => {
    console.error('wiki data load failed', err);
    const m = document.querySelector('#main');
    const msg = String((err && err.message) || err);
    if (m) m.innerHTML = '<div class="empty">知识库数据载入失败：' + msg + '<br>请用本地服务打开 dist/index.html，且同目录存在 data.json。</div>';
  });
