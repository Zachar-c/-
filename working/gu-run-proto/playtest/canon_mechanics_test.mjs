/* Canon 边界与原型设计值分开验证；通过真实浏览器按钮路径，不注入游戏状态。 */
import { chromium } from 'playwright-core';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const url = pathToFileURL(path.resolve('../index.html')).href + '?seed=20260927';
const browser = await chromium.launch({ executablePath: 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe', headless: true });
const assert = (condition, message) => { if (!condition) throw Error(message); console.log('OK', message); };
const errors = [];
async function freshPage() {
  const context = await browser.newContext({ viewport: { width: 1000, height: 900 } });
  const page = await context.newPage();
  page.on('pageerror', (error) => errors.push(error.message));
  await page.goto(url);
  await page.evaluate(() => localStorage.clear());
  await page.reload();
  await act(page, 'start');
  return page;
}
async function act(page, id) { await page.locator(`[data-act="${id}"]`).first().click(); }
async function option(page, label) { await page.locator('[data-opt]', { hasText: label }).first().click(); }
async function snapshot(page) {
  return page.evaluate(() => JSON.parse(localStorage.getItem('wenzhen_gu_run_checkpoint_v2')).run);
}
async function winCurrentBattle(page) {
  for (let i = 0; i < 20; i++) {
    if (await page.locator('[data-act="after-battle"]').count()) return;
    const moon = page.locator('[data-pick="moon"]');
    const small = page.locator('[data-pick="small"]');
    if (await moon.count() && await moon.isEnabled()) await moon.click();
    if (await small.count() && await small.isEnabled()) await small.click();
    if (!(await page.locator('.gu-btn.is-picked').count())) await page.locator('[data-pick="fist"]').click();
    await page.locator('#btn-resolve').click();
  }
  throw Error('未在 20 回合内获胜');
}

try {
  const rank = await freshPage();
  assert((await rank.locator('#rank').innerText()) === '1', '开局为一转初阶');
  assert((await rank.locator('#mp-cap').innerText()).includes('/44'), '一转 44% 元海的青铜当量上限是 44');
  assert(await rank.locator('[data-opt]', { hasText: '闭关冲二转' }).count() === 0, '开局没有付费即时升转');
  await act(rank, 'cultivate');
  assert(await rank.locator('[data-act="breakthrough"]').isDisabled(), '初阶不能破境');
  for (let i = 0; i < 12; i++) await act(rank, 'practice');
  assert((await rank.locator('#rank-stage').innerText()) === '巅峰', '三小境界共需十二次修炼');
  assert(await rank.locator('[data-act="breakthrough"]').isDisabled(), '巅峰没有外援仍不能冲二转');
  await act(rank, 'back-seg');
  await option(rank, '拦路战');
  await act(rank, 'go-battle');
  await winCurrentBattle(rank);
  await act(rank, 'after-battle');
  await act(rank, 'cultivate');
  assert(await rank.locator('[data-act="breakthrough"]').isDisabled(), '外援已得但元海未满仍不能破境');
  await act(rank, 'back-seg');
  await option(rank, '商队');
  await act(rank, 'shop-mp');
  assert((await rank.locator('#mp').innerText()) === '44', '补给后元海重新充满');
  await act(rank, 'leave-node');
  await act(rank, 'cultivate');
  await act(rank, 'breakthrough');
  const r2 = await snapshot(rank);
  assert(r2.rank === 2 && r2.minorStage === 0, '满条件后才升二转初阶');
  assert(r2.mp === 264 && (await rank.locator('#mp-cap').innerText()).includes('/440'), '二转有效容量 440，闭关后只恢复六成 [Design]');
  assert((await rank.locator('#ledger').innerText()).includes('元海 44%'), '升转不篡改资质决定的元海比例');

  const body = await freshPage();
  await act(body, 'cultivate');
  await act(body, 'boar-imprint');
  assert((await snapshot(body)).mp === 34, '白豕催用锻体先消耗 10 真元 [Design]');
  assert((await snapshot(body)).strength === 1, '肉身力量进入常驻状态');
  await act(body, 'back-seg');
  await option(body, '拦路战');
  await act(body, 'go-battle');
  const mpBeforeFist = (await snapshot(body)).mp;
  await body.locator('[data-pick="fist"]').click();
  await body.locator('#btn-resolve').click();
  const afterFist = await snapshot(body);
  assert(afterFist.mp === mpBeforeFist && afterFist.enemyHp === afterFist.enemyMax - 18, '已得猪力的拳脚 18 伤、0 真元；+8 伤为 [Design]');
  await winCurrentBattle(body);
  await act(body, 'after-battle');
  await option(body, '商队');
  await act(body, 'shop-study:whitejade');
  await option(body, '炼台');
  await act(body, 'refine-whitejade');
  const afterRefine = await snapshot(body);
  assert(afterRefine.gu.boar.alive === false && afterRefine.strength === 1, '白豕蛊合炼消失后已得肉身力量仍在');

  const wine = await freshPage();
  await option(wine, '路边休整');
  await act(wine, 'leave-node');
  await option(wine, '商队');
  await act(wine, 'shop-buy:winebug');
  assert((await snapshot(wine)).ready.includes('winebug') === false, '酒虫不占战斗出战槽');
  await act(wine, 'leave-node');
  await act(wine, 'cultivate');
  const wineMp = (await snapshot(wine)).mp;
  await act(wine, 'wine-practice');
  const wineResult = await snapshot(wine);
  assert(wineResult.practice === 2 && wineResult.mp === wineMp, '酒虫提纯推动修行，不提供真元净回复；8 小时恢复为修炼时间模型');
  assert((await wine.locator('#log').innerText()).includes('4→1'), '界面明确 4:1 提纯已有真元');
  for (let i = 0; i < 5; i++) await act(wine, 'wine-practice');
  assert((await wine.locator('#rank-stage').innerText()) === '巅峰', '酒虫只在本转小境界内加速');
  assert(await wine.locator('[data-act="wine-practice"]').isDisabled(), '一转巅峰不能靠一转酒虫升二转');
  await act(wine, 'back-seg');
  await option(wine, '虚魂体');
  assert(await wine.locator('[data-ready="winebug"]').count() === 0, '酒虫不是战斗卡');
  assert(errors.length === 0, '无页面运行错误');
  console.log('CANON MECHANICS CHECKS PASSED');
} finally { await browser.close(); }
