import { chromium } from 'playwright-core';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const url = pathToFileURL(path.resolve('../index.html')).href + '?seed=20260927';
const browser = await chromium.launch({ executablePath: 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe', headless: true });
const assert = (condition, message) => { if (!condition) throw new Error(message); console.log('OK', message); };
const errors = [];
async function act(page, id) { await page.locator(`[data-act="${id}"]`).first().click(); }
async function option(page, label) { await page.locator('[data-opt]', { hasText: label }).first().click(); }
async function finishBattle(page) {
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
  const context = await browser.newContext({ viewport: { width: 1000, height: 900 } });
  const page = await context.newPage();
  page.on('pageerror', (error) => errors.push(error.message));
  await page.goto(url);
  await page.evaluate(() => localStorage.clear());
  await page.reload();

  await act(page, 'start');
  await option(page, '路边休整');
  await act(page, 'leave-node');
  await option(page, '商队');
  await act(page, 'shop-study:moonglow');
  await option(page, '休整');
  await act(page, 'leave-node');
  await option(page, '补给');
  await act(page, 'shop-buy:small');
  await act(page, 'leave-node');
  await option(page, '终验');
  await act(page, 'go-battle');
  await finishBattle(page);
  assert(await page.locator('#end-panel').isVisible(), '结束第一世并进入结算页');
  assert(await page.locator('#btn-reset-all').isVisible(), '结算页可见从零重测入口');
  assert((await page.locator('#end-story').innerText()).includes('下一世已知：月芒方'), '第一世已提交蛊方记忆');
  await page.reload();
  assert((await page.locator('#life').innerText()) === '2', '重载进入第二世');
  assert(await page.locator('#btn-reset-all').isVisible(), '第二世起点可见从零重测入口');
  await page.evaluate(() => {
    localStorage.setItem('unrelated-reset-test-sentinel', 'keep-me');
    localStorage.setItem('wenzhen_gu_run_checkpoint_v1', 'legacy-checkpoint');
  });

  const beforeCancel = await page.evaluate(() => ({
    meta: localStorage.getItem('wenzhen_gu_run_recipes_v1'),
    checkpoint: localStorage.getItem('wenzhen_gu_run_checkpoint_v2'),
    legacy: localStorage.getItem('wenzhen_gu_run_checkpoint_v1'),
    sentinel: localStorage.getItem('unrelated-reset-test-sentinel'),
  }));
  page.once('dialog', (dialog) => dialog.dismiss());
  await page.locator('#btn-reset-all').click();
  const afterCancel = await page.evaluate(() => ({
    meta: localStorage.getItem('wenzhen_gu_run_recipes_v1'),
    checkpoint: localStorage.getItem('wenzhen_gu_run_checkpoint_v2'),
    legacy: localStorage.getItem('wenzhen_gu_run_checkpoint_v1'),
    sentinel: localStorage.getItem('unrelated-reset-test-sentinel'),
  }));
  assert(JSON.stringify(afterCancel) === JSON.stringify(beforeCancel), '取消确认不修改 meta、检查点或其他存储');
  assert((await page.locator('#life').innerText()) === '2' && (await page.locator('#knowledge').innerText()).includes('已知蛊方：月芒方'), '取消后仍在第二世并保留记忆');

  page.once('dialog', (dialog) => dialog.accept());
  await page.locator('#btn-reset-all').click();
  assert((await page.locator('#life').innerText()) === '1', '确认后回到第一世');
  assert((await page.locator('#knowledge').innerText()).includes('已知蛊方：无'), '确认后跨世蛊方记忆清空');
  assert((await page.locator('#rank').innerText()) === '1' && (await page.locator('#wallet').innerText()) === '48' &&
    (await page.locator('#hp').innerText()) === '100' && (await page.locator('#mp').innerText()) === '44', '确认后修为、元石、耐受和真元恢复默认');
  const afterConfirm = await page.evaluate(() => ({
    meta: localStorage.getItem('wenzhen_gu_run_recipes_v1'),
    checkpoint: JSON.parse(localStorage.getItem('wenzhen_gu_run_checkpoint_v2')),
    legacy: localStorage.getItem('wenzhen_gu_run_checkpoint_v1'),
    sentinel: localStorage.getItem('unrelated-reset-test-sentinel'),
  }));
  assert(afterConfirm.meta === null && afterConfirm.legacy === null && afterConfirm.checkpoint.life === 1 && afterConfirm.checkpoint.run.learnedThisLife.length === 0, '仅移除原型 meta/新旧检查点后重建第一世新局');
  assert(afterConfirm.sentinel === 'keep-me', '与原型无关的 localStorage 数据保留');

  await page.reload();
  assert((await page.locator('#life').innerText()) === '1' && (await page.locator('#knowledge').innerText()).includes('已知蛊方：无'), '刷新后仍从第一世无记忆状态开始');
  assert((await page.locator('#wallet').innerText()) === '48' && (await page.locator('#rank').innerText()) === '1', '刷新后默认资源状态稳定');
  assert(await page.evaluate(() => localStorage.getItem('unrelated-reset-test-sentinel') === 'keep-me'), '刷新后无关存储仍保留');
  assert(errors.length === 0, '无页面运行错误');
  console.log('RESET CHECKS PASSED');
} finally { await browser.close(); }
