import { chromium } from 'playwright-core';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const url = pathToFileURL(path.resolve('../index.html')).href + '?seed=818181';
const browser = await chromium.launch({ executablePath: 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe', headless: true });
const assert = (condition, message) => { if (!condition) throw new Error(message); console.log('OK', message); };
const errors = [];
async function newPage() {
  const context = await browser.newContext({ viewport: { width: 1000, height: 900 } });
  const page = await context.newPage();
  page.on('pageerror', (error) => errors.push(error.message));
  await page.goto(url);
  await page.evaluate(() => localStorage.clear());
  await page.reload();
  return { context, page };
}
async function act(page, id) { await page.locator(`[data-act="${id}"]`).first().click(); }
async function option(page, label) { await page.locator('[data-opt]', { hasText: label }).first().click(); }
async function loseBattle(page) {
  for (let i = 0; i < 20 && !(await page.locator('#end-panel').isVisible()); i++) {
    if (!(await page.locator('#btn-resolve').isVisible())) break;
    await page.locator('#btn-resolve').click();
  }
}
try {
  const { page } = await newPage();
  await act(page, 'start');
  await option(page, '路边休整');
  await act(page, 'leave-node');
  await option(page, '商队');
  await act(page, 'shop-study:moonglow');
  assert((await page.locator('#knowledge').innerText()).includes('本世抄得：月芒方'), '局内抄得的蛊方已出现但尚未跨世提交');
  const progressBefore = await page.evaluate(() => JSON.parse(localStorage.getItem('wenzhen_gu_run_checkpoint_v2')).run);
  await page.reload();
  assert((await page.locator('#life').innerText()) === '1' && (await page.locator('#rank').innerText()) === '1', '进度重载恢复同一世与修为');
  assert((await page.locator('#wallet').innerText()) === String(progressBefore.wallet), '进度重载恢复元石');
  assert((await page.locator('#knowledge').innerText()).includes('本世抄得：月芒方'), '未提交蛊方随本世检查点恢复');
  const progressAfter = await page.evaluate(() => JSON.parse(localStorage.getItem('wenzhen_gu_run_checkpoint_v2')).run);
  assert(progressAfter.randomState === progressBefore.randomState && progressAfter.learnedThisLife[0] === 'moonglow', '检查点保留 RNG 与本世配方知识');

  await option(page, '虚魂体');
  await act(page, 'go-battle');
  await page.locator('[data-pick="moon"]').click();
  await page.locator('#btn-resolve').click();
  const battleBefore = await page.evaluate(() => JSON.parse(localStorage.getItem('wenzhen_gu_run_checkpoint_v2')).run);
  assert(battleBefore.screen === 'battle' && battleBefore.turn > 1, '战斗已推进后写入检查点');
  await page.reload();
  assert((await page.locator('#screen-title').innerText()).includes('虚魂体'), '重载回到原战斗');
  const battleAfter = await page.evaluate(() => JSON.parse(localStorage.getItem('wenzhen_gu_run_checkpoint_v2')).run);
  assert(battleAfter.enemyHp === battleBefore.enemyHp && battleAfter.turn === battleBefore.turn && battleAfter.hp === battleBefore.hp, '重载保留敌我战斗状态');

  await page.locator('#btn-restart').click();
  assert((await page.locator('#life').innerText()) === '1' && (await page.locator('#wallet').innerText()) === '48' && (await page.locator('#rank').innerText()) === '1', '重开本局以同一世的新局开始');
  assert(!(await page.locator('#knowledge').innerText()).includes('本世抄得：'), '重开本局丢弃未提交蛊方');
  const restarted = await page.evaluate(() => JSON.parse(localStorage.getItem('wenzhen_gu_run_checkpoint_v2')).run);
  assert(restarted.ready.join(',') === 'moon,small,jade' && restarted.battleWon === false && restarted.enemy === null, '重开清除战斗状态并恢复初始编制');
  await page.reload();
  assert((await page.locator('#life').innerText()) === '1' && (await page.locator('#wallet').innerText()) === '48', '重开后的新局检查点可正常重载');

  // 独立清洁档：提交知识后结束本世，再核对下一世和损坏检查点回退。
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
  await act(page, 'leave-node');
  await option(page, '终验');
  await act(page, 'go-battle');
  await loseBattle(page);
  assert(await page.locator('#end-panel').isVisible(), '终验失败正常结束本世');
  assert((await page.locator('#end-story').innerText()).includes('下一世已知：月芒方'), '结束本世提交配方知识');
  assert(await page.evaluate(() => localStorage.getItem('wenzhen_gu_run_checkpoint_v2') === null), '本世结束清除旧检查点');
  await page.reload();
  assert((await page.locator('#life').innerText()) === '2' && (await page.locator('#wallet').innerText()) === '48', '结束后重载进入全新下一世');
  assert((await page.locator('#knowledge').innerText()).includes('已知蛊方：月芒方'), '已提交知识进入下一世');
  await page.evaluate(() => localStorage.setItem('wenzhen_gu_run_checkpoint_v2', JSON.stringify({ version: 2, seed: 818181, life: 2, run: { screen: '<img src=x onerror=alert(1)>' } })));
  await page.reload();
  assert((await page.locator('#life').innerText()) === '2' && (await page.locator('#wallet').innerText()) === '48', '损坏检查点安全回退为当前世新局');
  assert((await page.locator('#knowledge').innerText()).includes('已知蛊方：月芒方'), '损坏检查点回退保留已提交 meta');
  assert(await page.evaluate(() => localStorage.getItem('wenzhen_gu_run_checkpoint_v2') !== null), '回退后以安全新局状态重建检查点');
  await page.evaluate(() => {
    const saved = JSON.parse(localStorage.getItem('wenzhen_gu_run_checkpoint_v2'));
    saved.run.gu = {};
    localStorage.setItem('wenzhen_gu_run_checkpoint_v2', JSON.stringify(saved));
  });
  await page.reload();
  assert((await page.locator('#gu-list').innerText()).includes('月光蛊'), '缺失初始蛊的检查点回退为安全新局');
  assert(errors.length === 0, '全流程无页面异常');
  console.log('RESUME CHECKS PASSED');
} finally { await browser.close(); }
