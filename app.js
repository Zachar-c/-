const chains = [
  {
    level: "p0",
    title: "P0 · 杀招 + 炼蛊 + 蛊虫",
    meta: "第一生产主线 · 验证样本：月光 / 小光 / 月芒",
    steps: ["Evidence", "Rule", "Entity / Relation", "Canon Runtime", "Production View", "Game Semantics", "Runtime"],
  },
  {
    level: "p1",
    title: "P1 · 力量承载",
    meta: "真元 · 资质 · 转数 · 念头 · 魂魄",
    steps: ["CANON_VERIFIED 部分", "Semantic 绑定中"],
  },
  {
    level: "p2",
    title: "P2 · 经济世界",
    meta: "打谁 · 养什么 · 炼什么 · 买什么",
    steps: ["经济 / 蛊材 / 养蛊", "掉落 / 敌人库存 / 交易"],
  },
];

const sample = [
  {
    ref: "CAN-SMALL-LIGHT-001",
    rule: "小光辅助月光，月刃增强",
    game: "辅助蛊须真实改变主蛊输出，非装饰标签",
    status: "CANON_VERIFIED",
    kind: "ok",
  },
  {
    ref: "CAN-SMALL-LIGHT-002 · E:V1-015708",
    rule: "月光+双小光 → 月芒",
    game: "recipe 是组件结构，不是技能解锁钥匙",
    status: "RUNTIME_READY",
    kind: "ok",
  },
  {
    ref: "ST-MOONGLOW-02…04",
    rule: "首炼失败 · 三倍攻击 · 叠加上限",
    game: "合成失败与叠加须可结算",
    status: "SEMANTICS_READY",
    kind: "ok",
  },
  {
    ref: "KM-* · killer-moves",
    rule: "杀招=多蛊运行结构",
    game: "组件合成，禁止独立技能表",
    status: "PARTIAL",
    kind: "partial",
  },
  {
    ref: "REF-* · refinement",
    rule: "炼化意志 / 合炼秘方 / 推演",
    game: "炼蛊是过程不是购买",
    status: "KNOWLEDGE_READY",
    kind: "warn",
  },
];

const stats = [
  ["Markdown 页", "122"],
  ["概念页", "82"],
  ["E-ID", "4950"],
  ["EVT 引用", "2647"],
  ["ST 引用", "289"],
  ["规则 ID", "~190"],
  ["十三弧覆盖", "100% 行域"],
];

const debt = [
  ["待核对", "193"],
  ["笔记层级", "48"],
  ["未核验", "46"],
  ["两说", "9"],
  ["策略", "仅清阻塞 Knowledge Ready"],
];

const flow = [
  "需求 / 游戏支柱",
  "确定所需 Canon",
  "回 Wiki",
  "清必要知识债",
  "Knowledge Ready",
  "Canon Runtime",
  "Game Semantics",
  "Conformance",
  "Game",
];

function el(tag, cls, text) {
  const n = document.createElement(tag);
  if (cls) n.className = cls;
  if (text != null) n.textContent = text;
  return n;
}

function renderChains() {
  const root = document.getElementById("chains");
  chains.forEach((c) => {
    const box = el("article", `chain ${c.level}`);
    const head = el("div", "title");
    head.append(el("strong", null, c.title), el("span", null, c.meta));
    const steps = el("div", "steps");
    c.steps.forEach((s) => steps.append(el("i", null, s)));
    box.append(head, steps);
    root.append(box);
  });
}

function renderSample() {
  const tbody = document.querySelector("#sample tbody");
  sample.forEach((row) => {
    const tr = el("tr");
    const ref = el("td");
    ref.append(el("code", null, row.ref));
    tr.append(ref, el("td", null, row.rule), el("td", null, row.game));
    const st = el("td");
    st.append(el("span", `badge ${row.kind}`, row.status));
    tr.append(st);
    tbody.append(tr);
  });
}

function renderStats(id, rows) {
  const root = document.getElementById(id);
  rows.forEach(([k, v]) => {
    const li = el("li");
    li.append(el("span", null, k), el("b", null, v));
    root.append(li);
  });
}

function renderFlow() {
  const root = document.getElementById("flow");
  flow.forEach((step, i) => {
    root.append(el("span", null, step));
    if (i < flow.length - 1) root.append(el("span", "arrow", "→"));
  });
}

renderChains();
renderSample();
renderStats("stats", stats);
renderStats("debt", debt);
renderFlow();
