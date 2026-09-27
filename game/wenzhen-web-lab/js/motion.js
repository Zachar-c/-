/* 问真动效层（GSAP 增强，纯表现层）——js/motion.js
 * 定位：只做"看得见的动效"：不读写游戏 state、不改结算路径、不阻塞输入。
 * 降级链（任一环缺失都整体静默回退 lab.css 原生 CSS 动画，游戏照常可玩）：
 *   1) js/vendor/gsap.min.js 未载入（离线副本缺文件 / 旧缓存）→ window.Motion 全部为空操作；
 *   2) 系统 prefers-reduced-motion: reduce → 不创建任何 GSAP tween（CSS 侧另有瞬时化媒体查询兜底）。
 * 由 GSAP 接管的动画（场景进场 / 战斗浮动数字 / 敌方受击横震）通过 html.motion-on
 * 关闭 lab.css 里对应的 keyframes，避免 CSS 与 GSAP 双重驱动同一属性。
 */
(() => {
  'use strict';
  if (typeof window === 'undefined' || typeof document === 'undefined') return;

  const noop = () => {};
  const gsap = window.gsap;
  if (!gsap || typeof gsap.to !== 'function') {
    // GSAP 缺席：暴露全空操作接口，主流程的 window.Motion?. 调用全部安全跳过。
    window.Motion = { active: false, pageEnter: noop, hudNum: noop, float: noop, shake: noop, dockIn: noop };
    return;
  }

  gsap.defaults({ ease: 'power2.out', duration: 0.32, overwrite: 'auto' });

  let active = false;
  // 跟随系统动效偏好：偏好减弱时 active=false，一个 tween 都不建；偏好改回后自动恢复。
  // 游戏侧 tween 都是在钩子里按需创建的，不在 matchMedia 上下文内，
  // 所以这里只负责翻 flag 与挂/摘 motion-on，不承担 tween 回收。
  gsap.matchMedia().add({ ok: '(prefers-reduced-motion: no-preference)' }, (ctx) => {
    active = !!ctx.conditions.ok;
    document.documentElement.classList.toggle('motion-on', active);
  });

  const rootStyle = getComputedStyle(document.documentElement);
  const COLOR = {
    jade: (rootStyle.getPropertyValue('--jade') || '#8fc0a8').trim() || '#8fc0a8',
    flash: (rootStyle.getPropertyValue('--hit-flash') || '#de5233').trim() || '#de5233',
  };

  const restColor = new WeakMap();
  let pageTl = null;
  let pageRows = null;
  // 这些容器里的卡片逐张浮现（地图节点 / 战后三选一 / 备卡），不整块淡入。
  const CARD_GROUPS = '.map-nodes, .reward-choices, .node-cards, .prep-cards, .action-cards';
  // 进场限流：重页（大厅旧录 / 整备长列表）只动前 40 行，其余直接呈现，
  // 避免一次进场拉起几百个并发 tween。
  const MAX_PAGE_ROWS = 40;
  const ENTER_CLEAR = 'transform,opacity,transition';

  // 进场/入坞目标上常驻 CSS transform 过渡（.map-node / button 的 hover 反馈）。
  // 不压掉的话，GSAP 每帧的内联写入都会被 CSS transition 再插值一遍——双重缓动、白烧合成。
  // 动画期间置 none，结束随 clearProps 一并恢复，hover 手感不受影响。
  function disarmTransitions(targets) {
    gsap.set(targets, { transition: 'none' });
  }

  // 场景进场：面板直接子块淡入上浮，卡片容器则逐张浮现。
  function pageEnter(panel) {
    if (!active || !panel || !panel.classList.contains('on')) return;
    // 快速换页时上一次 from() 可能被打断在中途：先停掉旧时间线、把旧目标的内联样式清干净，
    // 否则新 from() 会把"半透明"当成终点，面板会永久蒙灰。
    if (pageTl) pageTl.kill();
    if (pageRows) gsap.set(pageRows, { clearProps: ENTER_CLEAR });
    pageRows = [];
    for (const child of panel.children) {
      if (child.matches && child.matches(CARD_GROUPS)) pageRows.push(...child.children);
      else pageRows.push(child);
    }
    if (!pageRows.length) return;
    if (pageRows.length > MAX_PAGE_ROWS) pageRows = pageRows.slice(0, MAX_PAGE_ROWS);
    disarmTransitions(pageRows);
    pageTl = gsap.timeline();
    pageTl.from(pageRows, {
      y: 14,
      opacity: 0,
      duration: 0.36,
      ease: 'power3.out',
      stagger: { amount: 0.2 },
      clearProps: ENTER_CLEAR,
    });
  }

  // HUD 数字变化弹跳：dir>0 涨（玉色），dir<0 跌（朱色）。
  function hudNum(el, dir) {
    if (!active || !el || !dir) return;
    if (!restColor.has(el)) restColor.set(el, getComputedStyle(el).color);
    gsap.fromTo(el, { scale: 1 }, {
      scale: 1.24, duration: 0.14, ease: 'power2.out',
      yoyo: true, repeat: 1, repeatDelay: 0.02, overwrite: 'auto',
    });
    gsap.fromTo(el, { color: dir > 0 ? COLOR.jade : COLOR.flash }, {
      color: restColor.get(el), duration: 0.5, ease: 'power1.out',
      overwrite: 'auto', clearProps: 'color',
    });
  }

  // 战斗浮动数字（-伤/+疗/规则标签）：GSAP 版 floatUp，带随机横漂与微旋。
  function float(node) {
    if (!active || !node || !node.parentNode) return;
    // node 是 floatOn 刚创建的全新节点，没有旧 tween 可杀，直接落起始帧（战斗热路径，不做无用功）。
    // .float-dmg 的 CSS 定位用 translateX(-50%) 居中；GSAP 里用 xPercent 复刻，避免被覆盖。
    gsap.set(node, { xPercent: -50, x: 0, y: 8, scale: 0.92, opacity: 0, rotation: gsap.utils.random(-5, 5) });
    gsap.timeline()
      .to(node, { opacity: 1, duration: 0.12, ease: 'power1.out' }, 0)
      .to(node, { y: -34, x: gsap.utils.random(-9, 9), scale: 1.05, duration: 0.42, ease: 'power2.out' }, 0)
      .to(node, { opacity: 0, y: -46, duration: 0.24, ease: 'power1.in' }, 0.5);
  }

  // 敌方受击横震：弹性回弹替代 CSS shake；.hit 的 filter 闪光仍由 CSS 提供。
  function shake(box) {
    if (!active || !box) return;
    gsap.fromTo(box, { x: -11 }, {
      x: 0, duration: 0.42, ease: 'elastic.out(1.1, 0.32)', overwrite: 'auto', clearProps: 'transform',
    });
  }

  // 主行动坞按钮内容变化时轻推入场（内容相同则不动，避免常规重绘也抖）。
  function dockIn(btn) {
    if (!active || !btn) return;
    disarmTransitions([btn]);
    gsap.fromTo(btn, { y: 10, opacity: 0 }, {
      y: 0, opacity: 1, duration: 0.26, ease: 'power2.out', overwrite: 'auto', clearProps: ENTER_CLEAR,
    });
  }

  window.Motion = {
    get active() { return active; },
    pageEnter,
    hudNum,
    float,
    shake,
    dockIn,
  };
})();
