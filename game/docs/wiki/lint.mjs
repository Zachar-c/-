// LLM Wiki lint（game/docs/wiki 唯一入口，脚本自定位）
// 检查：frontmatter / 悬空链接 / 孤儿页 / 脚注引用与源路径 / 可视化 / mermaid 括号引用
// 用法：node lint.mjs   （从任意 cwd 运行均可；也可 node game/docs/wiki/lint.mjs）
import { readdirSync, readFileSync, existsSync, statSync } from "node:fs";
import { join, relative, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const wikiDir = resolve(dirname(fileURLToPath(import.meta.url)));
const gameDir = resolve(wikiDir, "..", "..");
const repoRoot = resolve(gameDir, "..");

function walk(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) {
      if (name === "references") continue; // 维护规范豁免：规范提取副本不参与链接 lint
      out.push(...walk(p));
    } else if (name.endsWith(".md")) out.push(p);
  }
  return out;
}

const pages = walk(wikiDir);
const relOf = (p) => relative(wikiDir, p).replace(/\\/g, "/");
const pageRels = new Set(pages.map(relOf));

const problems = [];
const warns = [];
const notes = [];
const inbound = new Map();

// 路径 token：允许 ASCII 与 CJK 文件名；slash-token（含目录）与带扩展名的裸文件
const CJK = "\\u4e00-\\u9fff";
const slashTokRe = new RegExp(`[A-Za-z0-9_\\-${CJK}]+(?:\\/[A-Za-z0-9_\\-.${CJK}]+)+\\/?`, "g");
const fileTokRe = new RegExp(`[A-Za-z0-9_\\-${CJK}]+\\.(?:md|gd|json|cfg|py|mjs|js|txt|html|godot|import|uid|tres|tscn)`, "g");
const repoPrefixes = ["docs/", "data/", "scripts/", "game/", "memory/", "lore/", "working/", "ai-system/", "editorial/"];

function resolveOne(tok, fromRel) {
  const bases = [
    ["wiki", join(wikiDir, tok)],
    ["game", join(gameDir, tok)],
    ["root", join(repoRoot, tok)],
  ];
  const hits = bases.filter(([, p]) => existsSync(p));
  if (hits.length === 0) return { tok, ok: false };
  if (hits.length > 1) notes.push(`${fromRel}: 脚注源 \`${tok}\` 多基准命中（${hits.map((h) => h[0]).join("/")}），按 ${hits[0][0]} 计`);
  return { tok, ok: true, base: hits[0][0] };
}

function checkFootnoteSource(raw, fromRel) {
  const slashToks = [...raw.matchAll(slashTokRe)].map((m) => m[0]);
  // 裸文件名若是某条全路径的子串（同一引用的重复提取），跳过不单独检查
  const fileToks = [...raw.matchAll(fileTokRe)].map((m) => m[0])
    .filter((t) => !slashToks.some((s) => s.includes(t)));
  const toks = [...new Set([...slashToks, ...fileToks])];
  if (toks.length === 0) return `未提取到任何路径（原文：\`${raw.slice(0, 60)}\`）`;
  const fails = [];
  for (const tok of toks) {
    const r = resolveOne(tok, fromRel);
    if (r.ok) continue;
    const hasExt = /\.[A-Za-z0-9]+$/.test(tok);
    const repoish = repoPrefixes.some((p) => tok.startsWith(p));
    if (hasExt || repoish) fails.push(tok);
    else notes.push(`${fromRel}: 疑似非仓库路径 \`${tok}\` 未解析（可能是外部标识），仅备注`);
  }
  if (fails.length) return `路径不存在（wiki/game/root 三基准）：${fails.map((t) => `\`${t}\``).join("、")}`;
  return null;
}

for (const page of pages) {
  const rel = relOf(page);
  const text = readFileSync(page, "utf8");
  const issues = [];

  // ---- frontmatter ----
  const fm = text.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!fm) {
    issues.push("缺 frontmatter");
  } else {
    const body = fm[1];
    const field = (k) => {
      const m = body.match(new RegExp(`^${k}:\\s*(.*)$`, "m"));
      return m ? m[1].trim() : null;
    };
    for (const k of ["title", "description", "date", "tags"]) {
      if (!field(k)) issues.push(`frontmatter 缺 ${k}`);
    }
    const date = field("date");
    if (date && !/^\d{4}-\d{2}-\d{2}$/.test(date)) issues.push(`date 格式非 YYYY-MM-DD：${date}`);
    const tagsRaw = field("tags");
    if (tagsRaw) {
      const tags = tagsRaw.replace(/^\[|\]$/g, "").split(",").map((s) => s.trim()).filter(Boolean);
      if (tags.length < 2) issues.push(`tags 少于 2 个：${tagsRaw}`);
    }
  }

  // ---- 页面间 markdown 链接 ----
  const linkRe = /\[[^\]]*\]\(([^)\s]+)\)/g;
  let m;
  while ((m = linkRe.exec(text))) {
    let target = m[1];
    if (/^(https?:|mailto:|#)/.test(target)) continue;
    target = target.split("#")[0];
    if (!target) continue;
    const abs = resolve(dirname(page), decodeURIComponent(target));
    if (!existsSync(abs)) {
      issues.push(`悬空链接 → ${target}`);
      continue;
    }
    if (abs.endsWith(".md")) {
      const targetRel = relative(wikiDir, abs).replace(/\\/g, "/");
      if (pageRels.has(targetRel) && targetRel !== rel) {
        if (!inbound.has(targetRel)) inbound.set(targetRel, new Set());
        inbound.get(targetRel).add(rel);
      }
    }
  }

  // ---- 可视化（表格或 mermaid）：规范 MUST，缺失记 WARN ----
  const hasTable = /^\|.*\|$/m.test(text);
  const hasMermaid = /```mermaid/.test(text);
  if (rel !== "plan.md" && !hasTable && !hasMermaid) {
    warns.push(`${rel}: 无可视化（表格/mermaid）`);
  }

  // ---- mermaid 节点标签括号引用 ----
  for (const block of text.matchAll(/```mermaid([\s\S]*?)```/g)) {
    for (const line of block[1].split("\n")) {
      if (/\[[^\[\]\"]*\([^)]*\)[^\[\]\"]*\]/.test(line)) {
        issues.push(`mermaid 节点标签含括号未加引号：${line.trim().slice(0, 60)}`);
      }
      if (line.includes("$")) {
        issues.push(`mermaid 内含 $：${line.trim().slice(0, 60)}`);
      }
    }
  }

  // ---- 脚注：引用与定义（定义行本身不计入"被引用"）----
  const defIdx = new Map(); // 字符偏移 -> id
  const defined = new Map(); // id -> raw
  const defRe = /^[ \t]*\[\^([^\]]+)\]:[ \t]*(.+)$/gm;
  while ((m = defRe.exec(text))) {
    defined.set(m[1], m[2]);
    defIdx.set(m.index, m[1]);
  }
  const usedRe = /\[\^([^\]]+)\]/g;
  const used = new Set();
  while ((m = usedRe.exec(text))) {
    if (!defIdx.has(m.index)) used.add(m[1]);
  }
  // plan.md 为追踪页，会在 What/Why 里用 [^n] 指称脚注编号，不当作引用
  if (rel !== "plan.md") {
    for (const id of used) {
      if (!defined.has(id)) issues.push(`脚注 [^${id}] 被引用但无定义`);
    }
  }
  for (const [id, raw] of defined) {
    if (!used.has(id)) notes.push(`${rel}: 脚注 [^${id}] 定义未被正文引用（${raw.slice(0, 40)}）`);
    if (raw.trim().startsWith("[失源]")) {
      notes.push(`${rel}: 脚注 [^${id}] 标记 [失源]，不计入失败`);
      continue;
    }
    const fail = checkFootnoteSource(raw, rel);
    if (fail) issues.push(`脚注 [^${id}] 源不可解析：${fail}`);
  }

  if (issues.length) problems.push({ rel, issues });
}

// ---- 孤儿页 ----
const orphans = [...pageRels].filter((r) => r !== "overview.md" && !inbound.has(r));

// ---- 报告 ----
console.log(`== LLM Wiki lint ==  页面数：${pages.length}`);
console.log(`   wiki=${wikiDir}`);
if (problems.length === 0) console.log("frontmatter / 链接 / 脚注源 / mermaid：全部通过");
for (const { rel, issues } of problems) {
  console.log(`\n[FAIL] ${rel}`);
  for (const i of issues) console.log(`  - ${i}`);
}
if (warns.length) {
  console.log(`\n[WARN] ${warns.length} 条：`);
  for (const w of warns) console.log(`  - ${w}`);
}
if (orphans.length) {
  console.log(`\n[孤儿页]（无任何页面链入）：`);
  for (const o of orphans) console.log(`  - ${o}`);
}
if (notes.length) {
  console.log(`\n[备注] ${notes.length} 条：`);
  for (const n of notes) console.log(`  - ${n}`);
}
console.log(`\n结果：FAIL ${problems.length} 页，WARN ${warns.length}，孤儿页 ${orphans.length}，备注 ${notes.length}`);
process.exit(problems.length ? 1 : 0);
