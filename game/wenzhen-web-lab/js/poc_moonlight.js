// POC：月光蛊本体/收藏投影贴图挂载（visual_poc，非正式资产，可整文件随挂载点一起移除）。
// 上位：docs/superpowers/specs/2026-09-20-wenzhen-visual-positioning-v1-approved.md
//   —— 本体层=规则炼成世界；主题皮肤≠世界事实，必须带幻想标识。
// 资产来源：game/wenzhen-web/assets/gu/moonlight_gu/（manifest: not_production_asset=true）；
//   projection.svg 抽取自 visual-proof-01.html 的内联投影画（其 CSS 依赖仅为动画，静帧自足）。
// 挂载点：整备页蛊仓蛊卡（journey.js inventoryCard）、战斗页蛊虫按钮/可用蛊虫（battle.js）。
// 约定：战斗是世界事实语境，按钮固定用本体贴图；收藏投影只出现在蛊卡检视，且带幻想皮肤标识。
const MOONLIGHT_POC = (() => {
  const GU_ID = 'moonlight_gu';
  const CANONICAL = 'assets/poc/moonlight_gu/canonical-body.png';
  const ICON = 'assets/poc/moonlight_gu/icon-64.png';
  const PROJECTION = 'assets/poc/moonlight_gu/projection.svg';
  const STORAGE_KEY = 'poc_moonlight_mode';

  function isPoc(id) {
    return id === GU_ID;
  }

  function mode() {
    try {
      return localStorage.getItem(STORAGE_KEY) === 'projection' ? 'projection' : 'canonical';
    } catch {
      return 'canonical';
    }
  }

  function setMode(value) {
    try {
      localStorage.setItem(STORAGE_KEY, value === 'projection' ? 'projection' : 'canonical');
    } catch {
      /* 无 localStorage（file:// 隐私模式等）时模式不跨会话，功能不受阻 */
    }
  }

  // 蛊卡卡面：本体走原 48px 图位；投影改为卡顶横幅 + 幻想皮肤标识。
  // 返回 '' 表示该蛊不在本 POC 范围，调用方回退原 icon 渲染。
  function cardArt(id) {
    if (!isPoc(id)) return '';
    if (mode() === 'projection') {
      return `<div class="poc-art"><img class="poc-projection" src="${PROJECTION}" alt="月光蛊收藏投影">`
        + '<span class="poc-theme-flag">幻想皮肤 · 非世界事实</span></div>';
    }
    return `<img class="poc-canonical" src="${CANONICAL}" alt="月光蛊本体">`;
  }

  // 战斗按钮小图：固定本体（icon_64 在按钮尺寸下辨识度最稳）。
  function battleIcon(id) {
    return isPoc(id) ? `<img class="poc-gu-btn-icon" src="${ICON}" alt="">` : '';
  }

  function toggleLabel() {
    return mode() === 'projection' ? '投影' : '本体';
  }

  return { GU_ID, isPoc, mode, setMode, cardArt, battleIcon, toggleLabel };
})();
