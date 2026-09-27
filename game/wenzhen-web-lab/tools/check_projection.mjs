/* PHASE1 Projection validator · 必须核对真实消费者，禁止只验示例文本
 * RUL-2026-09-21-010 q3
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const RUL = JSON.parse(readFileSync(join(root, '../world-model/rulings/RUL-2026-09-21-010.json'), 'utf8'));
const PROJ = JSON.parse(readFileSync(join(root, 'data/projections.json'), 'utf8'));
const BAL = JSON.parse(readFileSync(join(root, '../data/balance.json'), 'utf8'));

const REQUIRED = RUL.q3_projection.required_fields;

function resolveParent(path) {
  let cur = BAL;
  for (const p of String(path).replace(/^balance\./, '').split('.')) cur = cur?.[p];
  return cur;
}

/** 加载真实 lab 消费者 balance.js（注入 WORLD_BALANCE），读回 LAB 实值 */
function loadLabConsumer() {
  const context = vm.createContext({});
  context.WORLD_BALANCE = BAL;
  const src = readFileSync(join(root, 'js/balance.js'), 'utf8');
  vm.runInContext(src, context, { filename: 'balance.js' });
  return context.MvpBalance;
}

/** 加载生成物 data.js（真实投影消费者：build_data 落库的 DATA.projections） */
function loadDataBundle() {
  const context = vm.createContext({});
  const src = readFileSync(join(root, 'js/data.js'), 'utf8');
  vm.runInContext(src + '\n;globalThis.__DATA__ = typeof DATA === "undefined" ? null : DATA;',
    context, { filename: 'js/data.js' });
  return context.__DATA__;
}

/** 加载 mvp_content.js（MVP 覆写真实消费者：guRef+overrideReason） */
function loadMvpContent() {
  const context = vm.createContext({});
  context.WORLD_BALANCE = BAL;
  vm.runInContext(readFileSync(join(root, 'js/balance.js'), 'utf8'), context, { filename: 'balance.js' });
  vm.runInContext(readFileSync(join(root, 'js/mvp_content.js'), 'utf8'), context, { filename: 'mvp_content.js' });
  return context.MVP_CONTENT;
}

/** childKey → 真实消费者读数 */
function readConsumer(childKey) {
  const B = loadLabConsumer();
  const map = {
    'lab.thoughtsPerTurn': B.LAB.thoughtsPerTurn,
    'lab.playerHp': B.LAB.playerHp,
    'lab.LAB_EXCHANGE_RATE': B.LAB.LAB_EXCHANGE_RATE,
    'lab.LAB_BUDGET_PROJECTION': B.LAB_BUDGET_PROJECTION,
    'lab.worldRankBudget1': B.worldRankBudget(1),
    'lab.crossRankQiCost': (base, p, g) => B.crossRankQiCost(base, p, g),
    'lab.complexityPoints': (km) => B.complexityPoints(km),
  };
  return map[childKey];
}

export function checkProjections(mutated = null) {
  const rows = [];
  const add = (name, ok, detail) => rows.push({ name, ok: !!ok, detail: String(detail) });
  const items = mutated?.items || PROJ.items;

  for (const item of items) {
    const missing = REQUIRED.filter((f) => item[f] === undefined);
    add(`${item.id} 字段齐全`, missing.length === 0, missing.join(',') || 'ok');
    add(`${item.id} parents[]`, Array.isArray(item.parents) && item.parents.length > 0, item.parents.join(','));
    add(`${item.id} forbidWriteBack`, item.forbidWriteBack === true, String(item.forbidWriteBack));
    add(`${item.id} LAB_ONLY`, item.authority === 'LAB_ONLY', item.authority);

    const ck = String(item.childKey || '');
    const bad = /recipe|canonical|provenance|dao\b/i.test(ck) || /entity_id/.test(ck);
    add(`${item.id} 未投影禁项`, !bad, ck);

    // parent 真源
    if (item.validation?.type === 'explicit_value' && item.validation.expectParent != null) {
      const actual = resolveParent(item.parents[0]);
      add(
        `${item.id} parent=${item.parents[0]}`,
        actual === item.validation.expectParent,
        `expect ${item.validation.expectParent} got ${actual}`,
      );
    }

    // RUL-2026-09-26-001 AUTOACCEPT：world curve → formula → exact LAB curve（30 值逐值复算）
    if (item.validation?.type === 'formula_projection') {
      const parent = resolveParent(item.parents[0]);
      const roles = ['attack', 'defense', 'healing', 'logistics', 'movement', 'recon'];
      const parentOk = !!parent && roles.every((r) => Array.isArray(parent[r]) && parent[r].length === 5);
      add(`${item.id} parent 曲线在案（六 role×5 值）`, parentOk, item.parents[0]);
      if (parentOk) {
        const mismatch = [];
        for (const r of roles) {
          for (let i = 0; i < 5; i++) {
            const expect = Math.max(1, Math.ceil(parent[r][i] / Math.sqrt(20)));
            if (item.value?.[r]?.[i] !== expect) mismatch.push(`${r}r${i + 1} proj=${item.value?.[r]?.[i]} formula=${expect}`);
          }
        }
        add(`${item.id} 公式复算 30 值逐值一致`, mismatch.length === 0, mismatch.join('; ') || 'max(1,ceil(world/√20))');
        const mono = roles.every((r) => item.value[r].every((v, i) => i === 0 || v >= item.value[r][i - 1]));
        add(`${item.id} 每 role 单调不减`, mono, 'RUL frozen invariant');
      }
      add(
        `${item.id} policy=sqrt_budget_scalar_projection_v1`,
        item.policy === 'sqrt_budget_scalar_projection_v1',
        item.policy,
      );
      const bundle = loadDataBundle();
      const actual = String(item.validation.path || '').split('.').reduce((o, k) => o?.[k], bundle);
      add(
        `${item.id} 生成物实值 == projection.value`,
        JSON.stringify(actual) === JSON.stringify(item.value),
        `embedded=${JSON.stringify(actual)}`,
      );
      const legacy = JSON.stringify({
        attack: [2, 3, 4, 5, 6], defense: [3, 4, 5, 6, 7], healing: [2, 3, 4, 5, 6],
        logistics: [1, 2, 3, 4, 5], movement: [1, 1, 1, 1, 1], recon: [1, 1, 1, 1, 1],
      });
      add(
        `${item.id} 无旧基线 silent fallback`,
        !JSON.stringify(bundle?.projections || {}).includes(legacy),
        'legacy [2,3,4,5,6] absent from generated data',
      );
      continue;
    }

    // RUL-2026-09-25-001 Q2：投影表/例外项的真实消费者校验（真实消费链，非示例文本）
    if (item.validation?.type === 'data_embedded') {
      const bundle = loadDataBundle();
      const actual = String(item.validation.path || '').split('.').reduce((o, k) => o?.[k], bundle);
      add(
        `${item.id} 生成物实值 == projection.value`,
        JSON.stringify(actual) === JSON.stringify(item.value),
        `embedded=${JSON.stringify(actual)}`,
      );
      if (item.id === 'PROJ-LAB-ENEMY-ATTACK-001') {
        const curveItem = items.find((x) => x.id === 'PROJ-LAB-ROLE-CURVE-001');
        const curve = curveItem?.value?.attack || [];
        const t = item.value || {};
        const le = ['1', '2', '3', '4', '5'].every((r) => Number(t[r]) <= (curve[Number(r) - 1] ?? Infinity));
        add(
          `${item.id} ≤ lab attack 曲线（RUL-2026-09-26-001 不变量）`,
          le,
          `table=${JSON.stringify(t)} curve=${JSON.stringify(curve)}`,
        );
        const mono = ['2', '3', '4', '5'].every((r, i) => Number(t[r]) >= Number(t[String(i + 1)]));
        add(`${item.id} 单调不减`, mono, JSON.stringify(t));
      }
      continue;
    }
    if (item.validation?.type === 'mvp_override_refs') {
      const mvp = loadMvpContent();
      const overrides = Object.values(mvp?.actions || {})
        .filter((a) => a?.guRef && a?.overrideReason)
        .map((a) => a.guRef);
      const expectRefs = item.value?.guRefs || [];
      const same = overrides.length === expectRefs.length && expectRefs.every((g) => overrides.includes(g));
      add(
        `${item.id} 代码覆写与登记一致`,
        same,
        `code=[${overrides.join(',')}] proj=[${expectRefs.join(',')}]`,
      );
      const four = item.value?.rulingNamedFour || [];
      add(
        `${item.id} 裁定点名四蛊已登记`,
        four.length > 0 && four.every((g) => expectRefs.includes(g)),
        four.join(','),
      );
      continue;
    }

    // 真实消费者读数（P1）：必须与 item.value 一致
    const live = readConsumer(ck);
    const expect = item.value;
    let liveOk;
    if (expect && typeof expect === 'object') {
      liveOk = live && Object.keys(expect).every((k) => live[k] === expect[k]);
    } else {
      liveOk = live === expect;
    }
    add(
      `${item.id} 消费者实值 == projection.value`,
      liveOk,
      `proj=${JSON.stringify(expect)} live=${JSON.stringify(live)}`,
    );
  }

  const fe = (mutated?.forbidden_examples || PROJ.forbidden_examples)[0] || {};
  add(
    'C3 月芒 canonical=月光+小光×2',
    (fe.canonical || []).join('+') === 'moonlight_gu+small_light_gu+small_light_gu',
    (fe.canonical || []).join('+'),
  );
  add(
    'C3 lab 短线=experimental_scenario_recipe',
    String(fe.lab_shortcut_id || '').startsWith('experimental_scenario_recipe'),
    fe.lab_shortcut_id,
  );

  // 真实 mvp_content.forge 身份（非示例文本）
  const mvpSrc = readFileSync(join(root, 'js/mvp_content.js'), 'utf8');
  const ctx = vm.createContext({});
  ctx.WORLD_BALANCE = BAL;
  vm.runInContext(readFileSync(join(root, 'js/balance.js'), 'utf8'), ctx, { filename: 'balance.js' });
  vm.runInContext(mvpSrc, ctx, { filename: 'mvp_content.js' });
  const forge = ctx.MVP_CONTENT?.forge || {};
  add(
    'C3 mvp forge.kind=experimental_scenario_recipe',
    forge.kind === 'experimental_scenario_recipe',
    forge.kind,
  );
  add(
    'C3 mvp forge.recipeCanonicalId=moon_glow_fixed',
    forge.recipeCanonicalId === 'moon_glow_fixed',
    forge.recipeCanonicalId,
  );
  add(
    'C3 consume 仅 lab 短线（1 小光）且声明 override',
    forge.consume?.small_light_gu === 1 && !!forge.consumeOverrideReason,
    JSON.stringify(forge.consume),
  );
  return rows;
}

/** 突变自检：改 value 必须失败 */
export function selfMutation() {
  const rows = [];
  const add = (name, ok, detail) => rows.push({ name, ok: !!ok, detail: String(detail) });
  const mutated = JSON.parse(JSON.stringify(PROJ));
  mutated.items = mutated.items.map((it) =>
    it.childKey === 'lab.thoughtsPerTurn' ? { ...it, value: 999 } : it,
  );
  const result = checkProjections(mutated);
  const thoughtFail = result.some((r) => r.name.includes('PROJ-LAB-THOUGHT-001 消费者实值') && !r.ok);
  add('突变 thoughtsPerTurn.value=999 必须检出', thoughtFail, thoughtFail ? 'detected' : 'MISSED');
  return rows;
}

const isMain = process.argv[1]?.includes('check_projection');
if (isMain) {
  const rows = [...checkProjections(), ...selfMutation()];
  for (const r of rows) console.log(`${r.ok ? 'PASS' : 'FAIL'}  ${r.name} — ${r.detail}`);
  const fail = rows.filter((r) => !r.ok);
  console.log(`\n== Projection ${rows.length - fail.length}/${rows.length} ==`);
  if (fail.length) process.exit(1);
}
