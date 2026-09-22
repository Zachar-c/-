import { readFileSync, mkdirSync, copyFileSync, existsSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const game = join(root, '..');
const data = readFileSync(join(root, 'js/data.js'), 'utf8');
const ctx = {};
new Function('globalThis', data + '; globalThis.DATA = DATA;')(ctx);
const DATA = ctx.DATA;

const needEnemies = ['ridge_hound', 'iron_hide_boar', 'ridge_elite_scout', 'thunder_crown_sovereign'];
const needGu = [
  'moonlight_gu',
  'small_light_gu',
  'stone_shell_gu',
  'vitality_grass_gu',
  'jade_skin_gu',
  'white_boar_strength_gu',
  'moon_glow_gu',
];
const enemyById = Object.fromEntries((DATA.enemies || []).map((e) => [e.id, e]));
const guById = Object.fromEntries((DATA.gu || []).map((g) => [g.id, g]));

const srcEnemy = join(game, 'assets/wenzhen/enemies');
const srcGu = join(game, 'assets/wenzhen/gu');
const srcHall = join(game, 'assets/wenzhen/hall');
const srcBg = join(game, 'assets/wenzhen/bg');
const dst = join(root, 'assets/wenzhen');
for (const d of ['enemies', 'gu', 'hall', 'bg']) mkdirSync(join(dst, d), { recursive: true });

const copies = [];
function tryCopy(srcDir, name, dstDir) {
  for (const ext of ['.png', '.jpg']) {
    const from = join(srcDir, name + ext);
    if (existsSync(from)) {
      copyFileSync(from, join(dstDir, name + ext));
      copies.push(`${name}${ext}`);
      return true;
    }
  }
  return false;
}

for (const id of needEnemies) {
  const portrait = enemyById[id]?.portrait;
  if (!portrait) console.log('MISSING portrait', id);
  else tryCopy(srcEnemy, portrait, join(dst, 'enemies'));
}
for (const id of needGu) {
  const icon = guById[id]?.icon || 'gu_moon';
  tryCopy(srcGu, icon, join(dst, 'gu'));
}
tryCopy(srcHall, 'hall_dots', join(dst, 'hall'));
if (existsSync(srcBg)) {
  for (const f of readdirSync(srcBg)) {
    if (f.endsWith('.png') && !f.endsWith('.import')) {
      copyFileSync(join(srcBg, f), join(dst, 'bg', f));
      copies.push('bg/' + f);
    }
  }
}
console.log('copied', copies.length);
console.log(copies.join('\n'));
