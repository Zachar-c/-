// Canon Runtime 消费一致性（P3 原型）：
// 1) DATA.canon 必须存在（lore/runtime 编译产物随库提交）；
// 2) canon 实体形状白名单——Game 数值不得倒灌 Canon 层；
// 3) rank_status=verified 的蛊，游戏生效转数必须等于 canon 转数（分叉/压缩/重用等状态豁免，由 canonAlert 上屏提示）；
// 4) relation 引用完整；月光+双小光→月芒古方在案；
// 5) canon.js 的 canonAlert 对分叉蛊给出原著口径、对一致蛊保持静默。
import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const context = vm.createContext({});
const load = (relativePath) => vm.runInContext(
  fs.readFileSync(new URL(relativePath, import.meta.url), 'utf8'),
  context,
  { filename: relativePath },
);

load('../js/data.js');
load('../js/canon.js');
vm.runInContext('globalThis.__DATA = DATA; globalThis.__CANON = Canon;', context);
const data = context.__DATA;
const canon = context.__CANON;

const runtimeManifest = JSON.parse(
  fs.readFileSync(new URL('../../../lore/runtime/manifest.json', import.meta.url), 'utf8'));

test('DATA.canon exists and is bound to the committed runtime build', () => {
  assert.ok(data.canon, 'DATA.canon 为 null——先运行 py -3 lore/wiki/tools/compile_runtime.py');
  assert.equal(data.canon.contentVersion, runtimeManifest.content_version);
  assert.match(data.canon.sourceSha256 || '', /^[0-9a-f]{64}$/);
});

test('canon entity shape is whitelist-only (no game values leak into canon)', () => {
  for (const [id, entry] of Object.entries(data.canon.entities)) {
    assert.deepEqual(Object.keys(entry).sort(), ['name', 'rank', 'rankStatus'], id);
    if (entry.rank != null) {
      assert.equal(typeof entry.rank, 'number', id);
      assert.ok(entry.rank >= 1 && entry.rank <= 9, `${id} rank 越界：${entry.rank}`);
    }
    assert.ok(['verified', 'divergence', 'rank_cap', 'name_reuse', 'collision', 'timepoint'].includes(entry.rankStatus), id);
  }
});

test('verified canon rank must equal game rank (the drift gate)', () => {
  const mismatches = [];
  for (const gu of data.gu) {
    const entry = data.canon.entities[gu.id];
    if (!entry || entry.rank == null) continue;
    if (entry.rankStatus === 'verified' && Number(entry.rank) !== Number(gu.rank)) {
      mismatches.push(`${gu.id}: game=${gu.rank} canon=${entry.rank}`);
    }
  }
  assert.deepEqual(mismatches, []);
});

test('divergence gu keep canon truth and surface an in-game alert', () => {
  const bloodBat = data.canon.entities.blood_bat_gu;
  assert.ok(bloodBat, 'blood_bat_gu 应在 canon 实体表');
  assert.equal(bloodBat.rank, 3, 'canon 口径：刀翅血蝠蛊三转（roster-3 E:V1-031864）');
  assert.equal(bloodBat.rankStatus, 'divergence');
  assert.notEqual(canon.canonAlert('blood_bat_gu', 1), '', '游戏 rank=1 时应显示原著口径提示');
});

test('relations reference existing entities; the moon-glow canon recipe is present', () => {
  for (const r of data.canon.relations) {
    const refs = [r.from, r.to, r.output, ...(r.inputs || [])].filter(Boolean);
    for (const id of refs) {
      assert.ok(data.canon.entities[id], `relation ${r.id} 引用未编译实体 ${id}`);
    }
  }
  const refine = data.canon.relations.find((r) => r.id === 'REL-REFINE-MOONGLOW');
  assert.ok(refine, '缺少月光+双小光→月芒合炼关系');
  assert.deepEqual([...refine.inputs], ['moonlight_gu', 'small_light_gu', 'small_light_gu']);
  assert.equal(refine.output, 'moon_glow_gu');
  assert.equal(refine.output_rank, 2);
  const support = data.canon.relations.find((r) => r.id === 'REL-SMALLLIGHT-MOONLIGHT-SUPPORT');
  assert.equal(support.from, 'small_light_gu');
  assert.equal(support.to, 'moonlight_gu');
});

test('canonAlert stays silent when game rank matches verified canon', () => {
  assert.equal(canon.canonAlert('moonlight_gu', 1), '');
  assert.equal(canon.canonAlert('small_light_gu', 1), '');
  assert.equal(canon.canonAlert('moon_glow_gu', 2), '');
  assert.equal(canon.canonAlert('nonexistent_gu', 1), '');
});
