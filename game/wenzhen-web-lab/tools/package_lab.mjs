/* lab 离线发行打包（W7）。
 * 用法：
 *   node tools/package_lab.mjs --out <全新目录>
 * 输出目录若已存在则拒绝覆盖；不删除用户目录。
 */
import {
  cpSync, existsSync, mkdirSync, readdirSync, readFileSync, statSync, writeFileSync,
} from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';

function parseArgs(argv) {
  const opts = { out: '' };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--out') opts.out = String(argv[++i]);
    else throw new Error(`未知参数: ${a}`);
  }
  if (!opts.out) throw new Error('必须提供 --out <目录>');
  return opts;
}

function walk(dir, base = dir, files = []) {
  for (const name of readdirSync(dir)) {
    const full = path.join(dir, name);
    const st = statSync(full);
    if (st.isDirectory()) walk(full, base, files);
    else files.push(path.relative(base, full));
  }
  return files;
}

function sha256(file) {
  return createHash('sha256').update(readFileSync(file)).digest('hex');
}

// Keep the full generated PNG masters in the workspace, but ship only the optimized Web images.
const OMIT_WEB_ART_MASTERS = new Set([
  'web/scene-01.png', 'web/scene-02.png', 'web/scene-03.png', 'web/scene-04.png', 'web/scene-05.png',
  'web/scene-01-preview.jpg',
  'enemies/web_boss_miasma_vein_lord.png',
  'enemies/web_boss_blood_vein_bishop.png',
  'enemies/web_boss_clan_patriarch.png',
  'enemies/web_boss_blue_fur_jiangshi.png',
]);

function main() {
  const opts = parseArgs(process.argv.slice(2));
  const out = path.resolve(opts.out);
  if (existsSync(out)) {
    console.error(`FAIL: 输出目录已存在，拒绝覆盖: ${out}`);
    process.exit(2);
  }

  const labRoot = path.resolve(import.meta.dirname, '..');
  const gameRoot = path.resolve(labRoot, '..');
  const assetsSrc = path.join(gameRoot, 'assets', 'wenzhen');

  mkdirSync(out, { recursive: true });
  const labDest = path.join(out, 'game', 'wenzhen-web-lab');
  const assetsDest = path.join(out, 'game', 'assets', 'wenzhen');
  mkdirSync(labDest, { recursive: true });
  mkdirSync(path.join(out, 'game', 'assets'), { recursive: true });

  // 保持 lab.html 相对脚本/样式布局
  for (const name of ['lab.html', 'css', 'js']) {
    const src = path.join(labRoot, name);
    if (!existsSync(src)) throw new Error(`缺少运行时入口: ${src}`);
    cpSync(src, path.join(labDest, name), { recursive: true });
  }
  if (existsSync(assetsSrc)) {
    for (const rel of walk(assetsSrc)) {
      if (OMIT_WEB_ART_MASTERS.has(rel.split(path.sep).join('/'))) continue;
      const src = path.join(assetsSrc, rel);
      const dest = path.join(assetsDest, rel);
      mkdirSync(path.dirname(dest), { recursive: true });
      cpSync(src, dest);
    }
  }

  const readme = `<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><title>问真 · 启动说明</title>
<style>body{font:16px/1.7 system-ui,"Segoe UI","PingFang SC","Microsoft YaHei",sans-serif;margin:40px;max-width:720px;color:#222}
code{background:#f4f1ea;padding:2px 6px;border-radius:4px}</style></head>
<body>
<h1>问真</h1>
<p>双击打开 <code>game/wenzhen-web-lab/lab.html</code> 即可开始。无需 Node、Godot 或联网。</p>
<h2>操作</h2>
<ul>
  <li>大厅选择难度 →「开始新局」</li>
  <li>五段路线选择后继 → 战斗 / 休整 / 市集 / 野蛊 / 险地 / 异闻</li>
  <li>战斗：观察、拳脚、蛊虫、杀招、结束回合；注意敌方意图与反击预警</li>
  <li>整备：坊市买卖、炼化、开炉、杀招组装、修为突破</li>
  <li>本局自动保存（浏览器 localStorage）。刷新后从大厅「继续当前局」。</li>
  <li>大厅保留最近 24 局修行旧录，可查看路线并以原种子复走。</li>
  <li>换浏览器或移动目录不会自动迁移存档。</li>
</ul>
<h2>存储</h2>
<p>进行中存档按兼容版本续玩，新增内容、美术和文案不打断当前长局；跨局旧录单独保留在浏览器本地存储中。隐私模式或清除站点数据会丢档；存储失败时游戏会明确提示。</p>
</body></html>
`;
  writeFileSync(path.join(out, 'README.html'), readme, 'utf8');

  const shipped = walk(out).map((rel) => {
    const full = path.join(out, rel);
    return { path: rel.split(path.sep).join('/'), bytes: statSync(full).size, sha256: sha256(full) };
  });
  writeFileSync(path.join(out, 'MANIFEST.json'), JSON.stringify({ generatedAt: new Date().toISOString(), files: shipped }, null, 2), 'utf8');

  console.error(`PASS: 打包完成 ${out}（${shipped.length} files）`);
  console.log(JSON.stringify({ out, fileCount: shipped.length }, null, 2));
}

main();
