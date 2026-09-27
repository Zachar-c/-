// G0 全仓文档结构门禁（docs/DOCUMENTATION_GOVERNANCE.md §3）
// 用法：node tools/docs-lint.mjs [--json] [--strict-orphans]
// 检查：相对链接可解析 · 编译层孤儿 · frontmatter date · 脚注路径形状 · mermaid 卫生
import { readdirSync, readFileSync, existsSync, statSync, writeFileSync } from "node:fs";
import { join, relative, dirname, resolve, extname } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const args = new Set(process.argv.slice(2));
const wantJson = args.has("--json");
const strictOrphans = args.has("--strict-orphans");

const INCLUDE_DIRS = ["docs", "lore", "game", "editorial", "fortune", "ai-system"];
const EXCLUDE_DIR_NAMES = new Set([
  ".git", ".git-nested-backup", ".worktrees", "node_modules", ".godot",
  "source", "archive", "references", ".superpowers", ".workbuddy", ".zcode",
  "__pycache__", "generated", ".snapshots",
]);
const ENTRY_NAMES = new Set([
  "readme.md", "agents.md", "index.md", "overview.md", "plan.md",
  "maintenance.md", "changelog.md", "todo.md", "project_map.md", "migration.md",
  "governance.md",
]);
const WIKI_PREFIXES = ["lore/wiki/", "game/docs/wiki/"];
const REPO_PREFIXES = [
  "docs/", "lore/", "game/", "editorial/", "fortune/", "ai-system/",
  "tools/", "scripts/", "working/", "memory/", "archive/", "source/",
];
// 源层/历史/过程记录按路径约定发现，不要求被链入
const SOURCE_LAYER_PREFIXES = [
  "docs/superpowers/", "docs/design/", "docs/art/", "docs/code-drift-audit/",
  "game/docs/superpowers/", "game/world-model/", "ai-system/tasks/",
  "game/docs/art/", "editorial/working/", "editorial/volumes/",
  "lore/research/", "working/",
  "editorial/notes/", "editorial/outlines/", "editorial/index/", "editorial/docs/",
  "game/docs/q8/", "game/docs/q8f/", "game/docs/q8g/", "game/docs/audit/",
  "game/docs/lore/candidates/", "game/wenzhen-web/docs/",
  "fortune/app/docs/", "ai-system/reviews/",
];
const ORPHAN_EXEMPT = [
  "lore/wiki/tools/",
  "game/docs/wiki/references/",
  "game/addons/",
  "game/lore_engine/tests/",
];
const ORPHAN_EXEMPT_RE = [
  /(^|\/)_/,                          // 本地工具/探针输出
  /-handoff\.md$/i,                   // 过程交接记录
  /-acceptance(-candidate)?(-\d+)?\.md$/i,
  /RESEARCH-REQUEST-/i,
  /(^|\/)(CODESTYLE|DEPLOY|THIRD_PARTY_NOTICES|LICENSE)\.md$/i,
  /(^|\/)分支：六卷精编版\//,
  /(^|\/)肉鸽设计-原始数据\//,
  /(^|\/)读书笔记\//,
  /记忆库\//,
];
const LOCAL_ONLY_SOURCES = new Set([
  "source/蛊真人-clean.txt",
  "source/《人祖传》.txt",
  "蛊真人-clean.txt",
  "蛊真人.txt",
]);

function walk(dir, out = []) {
  let names;
  try { names = readdirSync(dir); } catch { return out; }
  for (const name of names) {
    if (EXCLUDE_DIR_NAMES.has(name)) continue;
    const p = join(dir, name);
    let st;
    try { st = statSync(p); } catch { continue; }
    if (st.isDirectory()) walk(p, out);
    else if (name.toLowerCase().endsWith(".md")) out.push(p);
  }
  return out;
}

function relOf(p) {
  return relative(repoRoot, p).replace(/\\/g, "/");
}

function isWiki(rel) {
  return WIKI_PREFIXES.some((p) => rel.startsWith(p));
}

function isEntry(rel) {
  const base = rel.split("/").pop().toLowerCase();
  return ENTRY_NAMES.has(base) || rel === "PROJECT_MAP.md" || rel === "MIGRATION.md";
}

function parseFrontmatter(text) {
  const m = text.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!m) return null;
  const body = m[1];
  const field = (k) => {
    const fm = body.match(new RegExp(`^${k}:\\s*(.*)$`, "m"));
    return fm ? fm[1].trim() : null;
  };
  return { body, field, raw: m[0] };
}

function stripCode(text) {
  return text
    .replace(/```[\s\S]*?```/g, (b) => (b.startsWith("```mermaid") ? b : " "))
    .replace(/`[^`\n]*`/g, " ");
}

function extractLinks(text) {
  const out = [];
  const re = /!?\[[^\]]*\]\(([^)\n]+)\)/g;
  let m;
  while ((m = re.exec(text))) {
    let raw = m[1].trim();
    // 去掉 "title" 与 =WxH 尺寸后缀
    raw = raw.replace(/\s+"[^"]*"$/, "").replace(/\s+=\d+[xX,]\d+\s*$/, "");
    if (!raw || /^(https?:|mailto:|#|data:)/i.test(raw)) continue;
    if (/^\d+[xX,]\d+$/.test(raw)) continue;
    out.push({ raw, index: m.index });
  }
  return out;
}

function extractFootnoteDefs(text) {
  const defs = [];
  const re = /^[ \t]*\[\^([^\]]+)\]:[ \t]*(.+)$/gm;
  let m;
  while ((m = re.exec(text))) defs.push({ id: m[1], raw: m[2].trim(), index: m.index });
  return defs;
}

function pathTokens(s) {
  const CJK = "\\u4e00-\\u9fff";
  const slashTokRe = new RegExp(
    `[A-Za-z0-9_\\-${CJK}]+(?:\\/[A-Za-z0-9_\\-.${CJK}]+)+\\/?`,
    "g",
  );
  const fileTokRe = new RegExp(
    `[A-Za-z0-9_\\-${CJK}]+\\.(?:md|gd|json|cfg|py|mjs|js|txt|html|godot|import|uid|tres|tscn|css|ps1|sh)`,
    "g",
  );
  const slashToks = [...s.matchAll(slashTokRe)].map((x) => x[0].replace(/\/$/, ""));
  const fileToks = [...s.matchAll(fileTokRe)].map((x) => x[0])
    .filter((t) => !slashToks.some((sl) => sl.includes(t)));
  return [...new Set([...slashToks, ...fileToks])];
}

function isExternalIdentifier(tok) {
  // org/repo 形态且不是本仓已知前缀 → 外部标识（如 lucasastorian/llmwiki）
  if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(tok)) return false;
  return !REPO_PREFIXES.some((p) => tok.startsWith(p));
}

function resolvePathToken(tok) {
  if (LOCAL_ONLY_SOURCES.has(tok)) return { ok: true, localOnly: true };
  if (existsSync(join(repoRoot, tok))) return { ok: true };
  // 短路径可能相对 game/（历史写法）；可解析但要求改全路径
  if (existsSync(join(repoRoot, "game", tok))) return { ok: true, needFullPrefix: "game/" };
  return { ok: false };
}

// ---- collect pages ----
const pages = [];
for (const d of INCLUDE_DIRS) {
  const p = join(repoRoot, d);
  if (existsSync(p)) pages.push(...walk(p));
}
for (const name of readdirSync(repoRoot)) {
  const p = join(repoRoot, name);
  if (statSync(p).isFile() && name.toLowerCase().endsWith(".md")) pages.push(p);
}

const pageRels = new Set(pages.map(relOf));
const inbound = new Map();
const problems = [];
const warns = [];
const notes = [];

function addProblem(rel, issue) {
  problems.push({ rel, issue });
}

for (const page of pages) {
  const rel = relOf(page);
  let text;
  try {
    text = readFileSync(page, "utf8");
  } catch (e) {
    addProblem(rel, `无法读取：${e.message}`);
    continue;
  }
  const bodyForLinks = stripCode(text);

  // ---- links ----
  for (const { raw } of extractLinks(bodyForLinks)) {
    const target = decodeURIComponent(raw.split("#")[0].split("?")[0]);
    if (!target) continue;
    const abs = resolve(dirname(page), target);
    if (!existsSync(abs)) {
      addProblem(rel, `悬空链接 → ${raw}`);
      continue;
    }
    if (abs.toLowerCase().endsWith(".md")) {
      const tRel = relOf(abs);
      if (pageRels.has(tRel) && tRel !== rel) {
        if (!inbound.has(tRel)) inbound.set(tRel, new Set());
        inbound.get(tRel).add(rel);
      }
    }
  }

  // ---- frontmatter date ----
  const fm = parseFrontmatter(text);
  if (fm) {
    const date = fm.field("date");
    if (date && !/^\d{4}-\d{2}-\d{2}$/.test(date.replace(/["']/g, ""))) {
      addProblem(rel, `date 格式非 YYYY-MM-DD：${date}`);
    }
    if (isWiki(rel) && rel.startsWith("game/docs/wiki/")) {
      for (const k of ["title", "description", "date", "tags"]) {
        if (!fm.field(k)) addProblem(rel, `frontmatter 缺 ${k}`);
      }
    }
    if (isWiki(rel) && rel.startsWith("lore/wiki/") && rel.includes("/")) {
      // lore 概念页（子目录非 index）要求 type/name/aliases/sources
      const base = rel.split("/").pop();
      if (base !== "index.md" && base !== "AGENTS.md" && base !== "README.md"
        && base !== "log.md" && base !== "COORDINATION.md" && !base.startsWith("benchmark-")
        && !base.includes("l1-") && !base.includes("schema-") && !base.includes("retrospective")) {
        for (const k of ["type", "name", "sources"]) {
          if (!fm.field(k)) addProblem(rel, `frontmatter 缺 ${k}`);
        }
      }
    }
  }

  // ---- footnote path shape (wiki layers + any footnote) ----
  for (const def of extractFootnoteDefs(text)) {
    if (def.raw.startsWith("[失源]")) {
      notes.push(`${rel}: 脚注 [^${def.id}] 标记 [失源]`);
      continue;
    }
    const toks = pathTokens(def.raw);
    if (toks.length === 0) continue;
    const fails = [];
    let sawLocalOnly = false;
    for (const tok of toks) {
      if (isExternalIdentifier(tok)) {
        notes.push(`${rel}: 外部标识 \`${tok}\` 不参与路径校验`);
        continue;
      }
      const r = resolvePathToken(tok);
      if (r.ok) {
        if (r.localOnly) sawLocalOnly = true;
        if (r.needFullPrefix) {
          warns.push(`${rel}: 脚注路径请用仓库根相对全路径 \`${r.needFullPrefix}${tok}\`（L1 D2）`);
        }
        continue;
      }
      const looksRepo = /\//.test(tok) || /\.(md|gd|json|mjs|py|txt|ps1)$/.test(tok);
      if (looksRepo) fails.push(tok);
      else notes.push(`${rel}: 疑似外部标识 \`${tok}\` 未解析，仅备注`);
    }
    if (fails.length) {
      if (isWiki(rel)) addProblem(rel, `脚注 [^${def.id}] 源不可解析：${fails.join("、")}`);
      else warns.push(`${rel}: 脚注 [^${def.id}] 源不可解析：${fails.join("、")}`);
    }
    if (sawLocalOnly) notes.push(`${rel}: 脚注 [^${def.id}] 含 local-only 原文路径`);
  }

  // ---- mermaid hygiene ----
  for (const block of text.matchAll(/```mermaid([\s\S]*?)```/g)) {
    for (const line of block[1].split("\n")) {
      if (/\[[^\[\]\"]*\([^)]*\)[^\[\]\"]*\]/.test(line)) {
        warns.push(`${rel}: mermaid 节点标签含括号未加引号：${line.trim().slice(0, 60)}`);
      }
      if (line.includes("$")) {
        warns.push(`${rel}: mermaid 内含 $：${line.trim().slice(0, 60)}`);
      }
    }
  }
}

// ---- orphans ----
const orphans = [];
for (const r of pageRels) {
  if (isEntry(r)) continue;
  if (inbound.has(r)) continue;
  if (ORPHAN_EXEMPT.some((p) => r.startsWith(p))) continue;
  if (ORPHAN_EXEMPT_RE.some((re) => re.test(r))) continue;
  orphans.push(r);
}
const wikiOrphans = orphans.filter(isWiki);
const otherOrphans = orphans.filter((r) => {
  if (isWiki(r)) return false;
  if (SOURCE_LAYER_PREFIXES.some((p) => r.startsWith(p))) return false;
  return true;
});

// ---- report ----
const summary = {
  pages: pages.length,
  fail: problems.length,
  warn: warns.length,
  wikiOrphans: wikiOrphans.length,
  otherOrphans: otherOrphans.length,
  notes: notes.length,
};

if (wantJson) {
  writeFileSync(
    join(repoRoot, "tools", "docs-lint-report.json"),
    JSON.stringify({ summary, problems, warns, wikiOrphans, otherOrphans, notes }, null, 2),
  );
  console.log(JSON.stringify(summary));
} else {
  console.log(`== G0 docs-lint ==  页面数：${pages.length}`);
  console.log(`   root=${repoRoot}`);
  if (problems.length === 0) console.log("链接 / frontmatter / 脚注源：全部通过");
  for (const p of problems) {
    console.log(`\n[FAIL] ${p.rel}`);
    console.log(`  - ${p.issue}`);
  }
  if (warns.length) {
    console.log(`\n[WARN] ${warns.length} 条：`);
    for (const w of warns) console.log(`  - ${w}`);
  }
  if (wikiOrphans.length) {
    console.log(`\n[孤儿页·编译层] ${wikiOrphans.length}：`);
    for (const o of wikiOrphans) console.log(`  - ${o}`);
  }
  if (otherOrphans.length) {
    const byDir = new Map();
    for (const o of otherOrphans) {
      const dir = o.includes("/") ? o.slice(0, o.lastIndexOf("/")) : ".";
      byDir.set(dir, (byDir.get(dir) || 0) + 1);
    }
    const top = [...byDir.entries()].sort((a, b) => b[1] - a[1]).slice(0, 25);
    console.log(`\n[孤儿页·其他] ${otherOrphans.length}（WARN，按目录汇总）：`);
    for (const [dir, n] of top) console.log(`  - ${dir}/ × ${n}`);
    if (byDir.size > 25) console.log(`  … 另 ${byDir.size - 25} 个目录`);
  }
  if (notes.length) {
    console.log(`\n[备注] ${notes.length} 条（显示前 20）：`);
    for (const n of notes.slice(0, 20)) console.log(`  - ${n}`);
    if (notes.length > 20) console.log(`  … 另 ${notes.length - 20} 条`);
  }
  console.log(
    `\n结果：FAIL ${problems.length}，WARN ${warns.length + (strictOrphans ? otherOrphans.length : 0)}，` +
      `编译层孤儿 ${wikiOrphans.length}，其他孤儿 ${otherOrphans.length}，备注 ${notes.length}`,
  );
}

const failCount = problems.length + wikiOrphans.length + (strictOrphans ? otherOrphans.length : 0);
process.exit(failCount ? 1 : 0);
