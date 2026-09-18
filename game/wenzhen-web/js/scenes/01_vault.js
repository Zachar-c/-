/* 第一幕 · 空窍
   玩家在这里看到的不是风景，是一个人的里面。
   没有一句话解释这是什么——他自己会明白。 */

export async function vaultScene(stage) {
  const A = stage.audio;

  const sphereLayer = stage.layer(0.30);
  const sphere = stage.put(sphereLayer, 'div', 'vault-sphere');

  const shellLayer = stage.layer(0.55);
  const shell = stage.put(shellLayer, 'div', 'vault-shell');
  stage.put(shell, 'div', 'vault-sea');

  const bloomLayer = stage.layer(1.05);
  const bloom = stage.put(bloomLayer, 'div', 'vault-bloom');

  const bugLayer = stage.layer(1.35);
  const bug = stage.put(bugLayer, 'img', 'vault-cicada');
  bug.src = 'assets/cicada.png';
  bug.alt = '';
  bug.draggable = false;

  stage.parallax();

  // 先黑着，让声音把空间建立起来，再给画面
  await stage.wait(1500);
  A.heartbeat();
  await stage.wait(2700);
  A.fadeRoom('vault', 1, 7000);

  await stage.fade(sphereLayer, 1, 4400);   // 白色光膜
  await stage.wait(300);
  await stage.fade(shellLayer, 1, 3800);    // 元海：丙等，只占四五成
  await stage.wait(800);
  A.chime();
  await stage.fade(bloomLayer, 1, 3400);
  await stage.fade(bugLayer, 1, 4000);      // 春秋蝉，在睡

  await stage.wait(1500);

  // 玩家第一次能做的事：看。看的方式是把视线移过去。
  const nudgeTimer = setTimeout(() => bloom.classList.add('hint'), 12000);

  stage.onFirstHover(bugLayer, () => {
    clearTimeout(nudgeTimer);
    bug.classList.remove('nudge');
    void bug.offsetWidth;                   // 重排，让动画能重播
    bug.classList.add('nudge');
    A.chime(1568, 0.032, 2.4);              // 它动了一下，作为回应
  });

  await stage.waitForLook(bugLayer);
  clearTimeout(nudgeTimer);

  // 心口一沉。空窍向内收缩，白光吃掉整个画面。
  bug.classList.remove('nudge');
  bloom.classList.remove('hint');
  A.heartbeat();
  await stage.wait(430);
  A.chime(622, 0.075, 6);
  sphere.classList.add('collapse');
  shell.classList.add('collapse');
  bloom.classList.add('collapse');
  bug.classList.add('collapse');
  await stage.wait(430);                    // 让收缩被看见，再让白光吃掉它
  stage.whiteout(0.95, 700, 2600);
  A.fadeRoom('vault', 0, 1400);

  await stage.wait(830);
  stage.clear();
  await stage.wait(180);
}
