/* 对照 params.js 与 rank1-9-model/parameters.json，防数值漂移 */
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve('../../..');
const src = JSON.parse(
  fs.readFileSync(path.join(root, 'docs/design/rank1-9-model/parameters.json'), 'utf8')
);
const paramsJs = fs.readFileSync(path.resolve('../params.js'), 'utf8');
const win = {};
new Function('window', paramsJs)(win);
const MODEL = win.MODEL;

function subset(a, b) {
  // a 的键值必须在 b 中一致；b 可有额外字段
  for (const k of Object.keys(a)) {
    if (JSON.stringify(a[k]) !== JSON.stringify(b[k])) return false;
  }
  return true;
}

function eq(name, a, b, mode = 'subset') {
  const ok = mode === 'subset' ? subset(a, b) : JSON.stringify(a) === JSON.stringify(b);
  console.log((ok ? 'OK  ' : 'FAIL') + ' | ' + name);
  return ok;
}

let pass = 0;
let fail = 0;
function t(name, a, b, mode) {
  if (eq(name, a, b, mode)) pass++;
  else fail++;
}

t('version', MODEL.version, src.version, 'exact');
t('baseHp', MODEL.combat.baseHp, src.combat.baseHp, 'exact');
t('actionsPerTurn', MODEL.combat.actionsPerTurn, src.combat.actionsPerTurn, 'exact');
t('maxTurns', MODEL.combat.maxTurns, src.combat.maxTurns, 'exact');
t('blockExpires', MODEL.combat.blockExpires, src.combat.blockExpires, 'exact');
t('aptitude丙', MODEL.aptitude.value, src.aptitudes['丙'], 'exact');
t('rank1.base', MODEL.rank.base, src.ranks[0].base, 'exact');
t('rank1.essence', MODEL.rank.essence, src.ranks[0].essence, 'exact');
for (const id of Object.keys(MODEL.actions)) {
  t('actions.' + id, MODEL.actions[id], src.actions[id]);
}
for (const id of Object.keys(MODEL.enemies)) {
  t('enemy.' + id, MODEL.enemies[id], src.enemies[id]);
}
t('carriers.soulBodyResist', MODEL.carriers.soulBodyResist, src.carriers.soulBodyResist);
t('carriers.packDamageFloor', MODEL.carriers.packDamageFloor, src.carriers.packDamageFloor);

console.log('---');
console.log('MODEL LINK', pass, 'pass', fail, 'fail');
if (fail) process.exit(1);
