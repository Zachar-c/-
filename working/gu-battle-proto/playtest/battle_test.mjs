/* 蛊战回合 · 接入 rank1-9 数值后的自测 */
import { chromium } from 'playwright-core';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const url = pathToFileURL(path.resolve('../index.html')).href;

function assert(cond, msg) {
  if (!cond) throw new Error('FAIL: ' + msg);
  console.log('  OK  ' + msg);
}

async function text(page, sel) {
  return (await page.locator(sel).innerText()).trim();
}

async function pick(page, name) {
  await page.locator('[data-pick]', { hasText: name }).first().click();
}

async function run() {
  const browser = await chromium.launch({ executablePath: CHROME, headless: true });
  const page = await browser.newPage({ viewport: { width: 1100, height: 900 } });
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  await page.goto(url);
  await page.waitForTimeout(150);

  console.log('1) 标尺来自模型');
  assert((await text(page, '#hp')).includes('100'), '耐受 100 = baseHp');
  assert((await text(page, '#mp')).includes('44'), '丙等真元 44 = 100A');
  assert((await text(page, '#rules')).includes('rank1-9-model'), '规则面板标注数值源');
  assert((await text(page, '#rules')).includes('24') && (await text(page, '#rules')).includes('66'),
    '规则写明标准/爆发预算');

  console.log('2) AP=2');
  assert((await text(page, '#ap')).includes('2'), '本回剩余 AP=2');

  console.log('3) 意图与八场序列');
  const intent = await text(page, '#intent');
  assert(intent.includes('意图') || intent.includes('急咬'), '意图可读');
  const enemy = await text(page, '#enemy-box');
  assert(enemy.includes('skirmisher') || enemy.includes('快攻'), '第一场用模型 skirmisher 模板');
  assert((await text(page, '#enemy-name')).includes('1 ·'), '波次编号可见（八场）');

  console.log('4) 协同仍在，但跟模型预算');
  await pick(page, '月光');
  await pick(page, '小光');
  const tip = await text(page, '#combo-tip');
  assert(tip.includes('协同') || tip.includes('×2'), '月光+小光协同');
  // 月光 AP1 + 小光 AP0，还剩 1AP
  assert((await text(page, '#ap')).includes('1'), '月光占 1AP，小光 0AP');
  await page.click('#btn-resolve');
  await page.waitForTimeout(40);
  assert((await text(page, '#log')).includes('协同') || (await text(page, '#log')).includes('加倍'), '结算记协同');

  console.log('5) 标准攻击耗 10 真元');
  let mp = Number(await text(page, '#mp'));
  assert(mp <= 34, `放完月刃后真元≤34（44-10）当前 ${mp}`);

  console.log('6) 爆发占满 2AP 且有冷却');
  if (await page.locator('#btn-clear').isEnabled()) await page.click('#btn-clear');
  await pick(page, '白豕');
  assert((await text(page, '#ap')).includes('0'), '爆发吃掉 2AP');
  await page.click('#btn-resolve');
  await page.waitForTimeout(40);
  const boarBtn = page.locator('[data-pick]', { hasText: '白豕' }).first();
  assert(await boarBtn.isDisabled(), '爆发冷却中不可连放');

  console.log('7) 拳脚可空放（真元打空仍可行动）');
  if (await page.locator('#btn-clear').isEnabled()) await page.click('#btn-clear');
  // 花光真元
  for (let i = 0; i < 6; i++) {
    if ((await text(page, '#result-panel') && false)) break;
    const moon = page.locator('[data-pick]', { hasText: '月光' }).first();
    if (await moon.isEnabled()) await moon.click();
    const resolve = page.locator('#btn-resolve');
    if (await resolve.isEnabled()) {
      await resolve.click();
      await page.waitForTimeout(20);
    }
    if (Number(await text(page, '#mp')) <= 0) break;
    if (await page.locator('#result-panel').isVisible()) break;
    await page.click('#btn-clear').catch(() => {});
  }
  if (!(await page.locator('#result-panel').isVisible())) {
    await page.click('#btn-clear').catch(() => {});
    const fist = page.locator('[data-pick]', { hasText: '拳脚' }).first();
    assert(await fist.isEnabled(), '真元不足时拳脚仍可用');
  }

  if (errors.length) {
    console.error(errors);
    throw new Error('page errors');
  }
  console.log('\nMODEL-LINKED BATTLE CHECKS PASSED');
  await browser.close();
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
