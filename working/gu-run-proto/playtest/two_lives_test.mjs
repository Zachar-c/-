/* 用同一种子走两世：第一世买到知识，第二世把商队机会用于补蛊并实际炼成。
   另核对一转持有二转蛊时不能上场。 */
import { chromium } from 'playwright-core';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const url = pathToFileURL(path.resolve('../index.html')).href + '?seed=20260927';
const browser = await chromium.launch({ executablePath: 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe', headless: true });
const errors = [];
const assert = (condition, text) => { if (!condition) throw Error(text); console.log('OK', text); };
async function openPage() {
  const context = await browser.newContext({ viewport: { width: 1000, height: 900 } });
  const page = await context.newPage();
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(url);
  await page.evaluate(() => localStorage.clear());
  await page.reload();
  return page;
}
async function option(page, label) { await page.locator('[data-opt]', { hasText: label }).first().click(); }
async function act(page, id) { await page.locator(`[data-act="${id}"]`).first().click(); }
async function endBattle(page) {
  for (let i = 0; i < 32 && !(await page.locator('#end-panel').isVisible()); i++) {
    if (!(await page.locator('#btn-resolve').isVisible())) break;
    const moon = page.locator('[data-pick="moon"]');
    const small = page.locator('[data-pick="small"]');
    const fist = page.locator('[data-pick="fist"]');
    if (await moon.isEnabled()) await moon.click();
    if (await small.isEnabled()) await small.click();
    if (!(await page.locator('.gu-btn.is-picked').count()) && await fist.isEnabled()) await fist.click();
    await page.locator('#btn-resolve').click();
  }
}
try {
  const page = await openPage();
  await act(page, 'start');
  assert(await page.locator('[data-opt]', { hasText: '闭关冲二转' }).count() === 0, '开局没有即时升转路线');
  await option(page, '路边休整');
  await act(page, 'leave-node');
  await option(page, '商队');
  await act(page, 'shop-study:moonglow');
  assert((await page.locator('#knowledge').innerText()).includes('本世抄得：月芒方'), '第一世花商队机会抄月芒方');
  assert((await page.locator('#stage').innerText()) === '2', '抄方占用整个节点');
  await option(page, '休整');
  await act(page, 'leave-node');
  await option(page, '补给');
  await act(page, 'shop-buy:small');
  assert((await page.locator('#gu-list').innerText()).includes('小光蛊 ×2'), '第一世虽凑双小光，但错过炼台');
  await act(page, 'leave-node');
  await option(page, '终验');
  await act(page, 'go-battle');
  await endBattle(page);
  assert(await page.locator('#end-panel').isVisible(), '第一世完成真实终验');
  assert((await page.locator('#end-story').innerText()).includes('下一世已知：月芒方'), '只在局终提交跨世知识');

  await page.reload(); // 真正跨页面重载，而不只依赖同一 JS 会话里的状态。
  assert((await page.locator('#life').innerText()) === '2', '第二世开始');
  assert((await page.locator('#rank').innerText()) === '1', '修为不继承');
  assert((await page.locator('#wallet').innerText()) === '48', '元石不继承');
  assert(!(await page.locator('#gu-list').innerText()).includes('小光蛊 ×2'), '第二只蛊不继承');
  assert((await page.locator('#knowledge').innerText()).includes('已知蛊方：月芒方'), '蛊方知识继承');
  await act(page, 'start');
  await option(page, '拦路战');
  await act(page, 'go-battle');
  await endBattle(page);
  assert((await page.locator('#log').innerText()).includes('冲窍外援资格'), '战场胜利取得冲窍外援');
  await act(page, 'after-battle');
  await option(page, '商队');
  assert(await page.locator('[data-act="shop-study:moonglow"]').isDisabled(), '已知蛊方无需再次抄录');
  await act(page, 'shop-buy:small');
  await act(page, 'shop-mp');
  assert((await page.locator('#mp').innerText()) === '44', '破境前补满一转元海');
  await act(page, 'leave-node');
  await act(page, 'cultivate');
  for (let i = 0; i < 12; i++) await act(page, 'practice');
  assert((await page.locator('#rank-stage').innerText()) === '巅峰', '十二次修炼抵达一转巅峰');
  await act(page, 'breakthrough');
  assert((await page.locator('#rank').innerText()) === '2', '巅峰、外援、真元与元石齐备后破入二转');
  assert((await page.locator('#mp-cap').innerText()).includes('/440'), '二转有效真元上限提升至 440 青铜当量');
  await act(page, 'back-seg');
  await option(page, '炼台');
  assert(await page.locator('[data-act="refine-moonglow"]').isEnabled(), '第二世可在中盘选择炼月芒');
  await act(page, 'refine-moonglow');
  assert((await page.locator('#gu-list').innerText()).includes('月芒蛊'), '相同种子下月芒实际炼成');
  assert((await page.locator('#ledger').innerText()).includes('二转蛊须二转方能出战'), '编制规则明示二转条件');
  await act(page, 'leave-node');
  await option(page, '扰元兽');
  assert(await page.locator('[data-ready="moonglow"]').isEnabled(), '二转时月芒可进入编制');
  await act(page, 'go-battle');
  const before = Number((await page.locator('#enemy-box .hp-bar i').getAttribute('style')).match(/\d+/)[0]);
  await page.locator('[data-pick="moonglow"]').click();
  await page.locator('#btn-resolve').click();
  const after = Number((await page.locator('#enemy-box .hp-bar i').getAttribute('style')).match(/\d+/)[0]);
  assert(after < before, '第二世知识转型在战斗中产生可观察效果');
  await page.setViewportSize({ width: 320, height: 740 });
  const widthCheck = await page.evaluate(() => ({ page: document.documentElement.scrollWidth, viewport: innerWidth }));
  assert(widthCheck.page <= widthCheck.viewport, '320px 手机宽度无横向溢出');
  await page.screenshot({ path: path.resolve('mobile-two-lives.png'), fullPage: true });

  const rankGate = await openPage();
  await act(rankGate, 'start');
  await option(rankGate, '路边休整');
  await act(rankGate, 'leave-node');
  await option(rankGate, '商队');
  await act(rankGate, 'shop-study:whitejade');
  await option(rankGate, '炼台');
  await act(rankGate, 'refine-whitejade');
  assert((await rankGate.locator('#gu-list').innerText()).includes('白玉蛊'), '一转可持有炼成的白玉蛊');
  await act(rankGate, 'leave-node');
  await option(rankGate, '扰元兽');
  assert(await rankGate.locator('[data-ready="whitejade"]').isDisabled(), '一转不能编入二转白玉蛊');

  const unfinished = await openPage();
  await act(unfinished, 'start');
  await option(unfinished, '路边休整');
  await act(unfinished, 'leave-node');
  await option(unfinished, '商队');
  await act(unfinished, 'shop-study:moonglow');
  await unfinished.reload();
  assert((await unfinished.locator('#knowledge').innerText()).includes('已知蛊方：无'), '未结束本世时抄方不偷跑进永久记忆');
  assert(errors.length === 0, '无页面运行错误');
  console.log('TWO-LIFE CONTRACT PASSED');
} finally { await browser.close(); }
