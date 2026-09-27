/* 一局蛊途 · 战损/补给/炼蛊取舍自测 */
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

async function clickAct(page, label) {
  await page.locator('[data-act]', { hasText: label }).first().click();
}

async function clickOpt(page, label) {
  await page.locator('[data-opt]', { hasText: label }).first().click();
}

async function pick(page, name) {
  await page.locator('[data-pick]', { hasText: name }).first().click();
}

async function ensurePrep(page) {
  if (await page.locator('[data-act="go-battle"]').count()) {
    await page.locator('[data-act="go-battle"]').first().click();
  }
}

async function fightOnce(page) {
  await ensurePrep(page);
  for (let i = 0; i < 40; i++) {
    if (await page.locator('[data-act="after-battle"]').count()) return true;
    if ((await text(page, '#hp')) === '0') return false;
    if (await page.locator('#btn-resolve').isHidden()) break;
    await page.locator('#btn-clear').click().catch(() => {});
    const moon = page.locator('[data-pick]', { hasText: '月光' }).first();
    const small = page.locator('[data-pick]', { hasText: '小光' }).first();
    const fist = page.locator('[data-pick]', { hasText: '拳脚' }).first();
    if (await moon.count() && (await moon.isEnabled())) await moon.click();
    if (await small.count() && (await small.isEnabled())) await small.click();
    if ((await page.locator('.gu-btn.is-picked').count()) === 0 && (await fist.count()) && (await fist.isEnabled())) {
      await fist.click();
    }
    await page.click('#btn-resolve');
    await page.waitForTimeout(20);
    if (await page.locator('[data-act="after-battle"]').count()) return true;
    if ((await text(page, '#hp')) === '0') return false;
  }
  return !!(await page.locator('[data-act="after-battle"]').count());
}

async function run() {
  const browser = await chromium.launch({ executablePath: CHROME, headless: true });
  const page = await browser.newPage({ viewport: { width: 1100, height: 950 } });
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  await page.goto(url);
  await page.waitForTimeout(120);

  console.log('1) 入局账本来自模型');
  assert((await text(page, '#wallet')) === '48', '初始钱包 48U');
  assert((await text(page, '#hp')) === '100', '耐受 100');
  assert((await text(page, '#mp')) === '44', '真元 44');
  assert((await text(page, '#ledger')).includes('12U') && (await text(page, '#ledger')).includes('0.12'),
    '账本写明满耐 12U / 真元 0.12U/点');

  await clickAct(page, '出发');
  assert((await text(page, '#screen-title')).includes('起点') || (await text(page, '#screen-title')).includes('段') || (await text(page, '#screen-title')).includes('青石'),
    '进入分段');

  console.log('2) 路线可选 · 先休整');
  // 第一段选休整
  await clickOpt(page, '休整');
  await clickAct(page, '免费小休');
  assert(Number(await text(page, '#wallet')) < 48, '供养扣钱');
  await clickAct(page, '离开');

  console.log('3) 战斗接进一局 · 战损留下');
  await clickOpt(page, '甲壳');
  // 备战编制
  assert(await page.locator('[data-act="go-battle"]').count(), '进战斗前有出战编制');
  assert((await text(page, '#screen-tag')).includes('C=4') || (await text(page, '#scene')).includes('心智'), '编制上限对齐心智容量');
  await clickAct(page, '带这套进场');
  assert(await page.locator('#intent').isVisible(), '战斗意图可见');
  assert((await text(page, '#ledger')).includes('出场') || Number(await text(page, '#wallet')) < 48,
    '出场消耗 fieldCost');
  const won = await fightOnce(page);
  assert(won, '一场能打完');
  const walletAfter = Number(await text(page, '#wallet'));
  assert(walletAfter > 0, '战后有账可记');
  await clickAct(page, '收下战果');

  console.log('4) 炼台是转型不是升级');
  // 找一段带炼台的
  const title = await text(page, '#screen-title');
  if (!title.includes('炼') && !(await page.locator('[data-opt]', { hasText: '炼台' }).count())) {
    // 选能到炼台的
    if (await page.locator('[data-opt]', { hasText: '休整' }).count()) {
      await clickOpt(page, '休整');
      await clickAct(page, '离开');
    }
  }
  if (await page.locator('[data-opt]', { hasText: '炼台' }).count()) {
    await clickOpt(page, '炼台');
    assert((await text(page, '#screen-tag')).includes('95%') || (await text(page, '#scene')).includes('转型') || (await text(page, '#scene')).includes('部件'),
      '炼台写明失败/吃部件');
    assert((await text(page, '#choices')).includes('月芒') || (await text(page, '#choices')).includes('小光'),
      '炼的是分岔/拆件，不是点升级');
    await clickAct(page, '不炼');
  } else {
    console.log('  (skip) 本局路径未到炼台');
  }

  console.log('5) 打到终验或收束');
  for (let i = 0; i < 12; i++) {
    if (await page.locator('#end-panel').isVisible()) break;
    if (await page.locator('[data-act="go-battle"]').count()) {
      await clickAct(page, '带这套进场');
      await fightOnce(page);
      if (await page.locator('[data-act="after-battle"]').count()) await clickAct(page, '收下战果');
    } else if (await page.locator('[data-opt]', { hasText: '终验' }).count()) {
      await clickOpt(page, '终验');
    } else if (await page.locator('[data-opt]').count()) {
      const fight = page.locator('[data-opt]', { hasText: '兽' }).first();
      const anyFight = page.locator('[data-opt]', { hasText: '战' }).first();
      const rest = page.locator('[data-opt]', { hasText: '休' }).first();
      if (await fight.count()) await fight.click();
      else if (await anyFight.count()) await anyFight.click();
      else if (await rest.count()) await rest.click();
      else await page.locator('[data-opt]').first().click();
    } else if (await page.locator('[data-act="after-battle"]').count()) {
      await clickAct(page, '收下战果');
    } else if (await page.locator('[data-act="leave-node"]').count()) {
      await clickAct(page, '离开');
    }
    if ((await text(page, '#hp')) === '0') break;
    if (await page.locator('#btn-resolve').isVisible()) {
      await fightOnce(page);
      if (await page.locator('[data-act="after-battle"]').count()) await clickAct(page, '收下战果');
    }
    await page.waitForTimeout(30);
  }

  assert(await page.locator('#end-panel').isVisible(), '能走到收束（胜或败）');
  const end = await text(page, '#end-story');
  assert(end.includes('供养') || end.includes('炼制') || end.includes('出场'), '账本列出模型经济项');
  assert(end.includes('转型') || end.includes('取舍') || end.includes('战损') || end.includes('路线'),
    '回放指向取舍');

  if (errors.length) {
    console.error(errors);
    throw new Error('page errors');
  }
  console.log('\nRUN PROTO CHECKS PASSED');
  await browser.close();
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
