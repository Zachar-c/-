/* params.js 是研究参数的浏览器切片；任何已抄字段变更都要显式对齐。 */
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';

const source = JSON.parse(fs.readFileSync(path.resolve('../../../docs/design/rank1-9-model/parameters.json'), 'utf8'));
const context = { window: {} };
vm.runInNewContext(fs.readFileSync(path.resolve('../params.js'), 'utf8'), context);
const slice = context.window.MODEL;
const checks = [
  ['version', slice.version, source.version],
  ['combat', slice.combat, source.combat],
  ['rank1', slice.rank, source.ranks[0]],
  ['aptitude', slice.aptitude.value, source.aptitudes[slice.aptitude.id]],
  ['actions', slice.actions, source.actions],
  ['enemies', slice.enemies, source.enemies],
  ['carriers', slice.carriers, source.carriers],
  ['refinement', slice.refinement, source.refinement],
  ['economy', slice.economy, source.economy],
];
function compareSubset(label, part, whole) {
  if (part && typeof part === 'object') {
    for (const key of Object.keys(part)) compareSubset(`${label}.${key}`, part[key], whole?.[key]);
    return;
  }
  if (part !== whole) throw Error(`${label}: prototype=${JSON.stringify(part)} source=${JSON.stringify(whole)}`);
}
for (const [label, part, whole] of checks) compareSubset(label, part, whole);
console.log(`MODEL LINK PASS: ${checks.map(([label]) => label).join(', ')}`);
