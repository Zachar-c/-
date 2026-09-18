/* 第三幕 · 内视
   他从雨里回到屋里。桌上摆着几颗元石——那是他全部的家当。
   蝉在空窍里，饿了。
   玩家要做的第一件有代价的事：把石头喂进去。
   没有数字，没有面板。桌上还剩几颗，用眼睛数。 */

export async function feedScene(stage) {
  const A = stage.audio;

  // ---------- 屋里 ----------
  A.soundRoom();
  A.fadeRoom('room', 1, 6000);
  A.fadeRoom('rain', 0.26, 4000);          // 同一场雨，隔着墙
  A.fadeRoom('vault', 0.16, 6000);         // 空窍那点低频，一直没有真的停过

  // fadeOutAll 会**同步**抓取当前所有层，所以必须在建本场任何一个层之前调用。
  // 放在后面调用会把这一场自己的屋子也淡掉删掉，画面就只剩黑底。
  const cleanup = stage.fadeOutAll(2800);

  const roomLayer = stage.layer(0.14);
  const room = stage.put(roomLayer, 'img', 'room');
  room.src = 'assets/room.png';
  room.alt = '';
  room.draggable = false;

  stage.fade(roomLayer, 1, 2800);          // 与上一幕叠化，不是切
  await cleanup;
  room.classList.add('settle');

  // ---------- 桌上的元石 ----------
  // 位置是在 1600×900 上对着屋子那张图量出来的。写在场景里，不做布局系统。
  const HOME = [
    { left: '25.2%', top: '74.0%', size: '6.2vmin', rot: '-9deg', flip: 1 },
    { left: '32.6%', top: '75.3%', size: '5.5vmin', rot: '14deg', flip: -1 },
    { left: '40.2%', top: '74.2%', size: '5.9vmin', rot: '-4deg', flip: 1 },
  ];

  const stoneLayer = stage.layer(0.14);    // 与屋子同深，才像长在桌面上
  stoneLayer.style.opacity = '1';          // 层透明，石头各自淡入——要做错开
  const shadows = [];
  const stones = HOME.map((s, i) => {
    const sh = stage.put(stoneLayer, 'div', 'stone-shadow');
    sh.style.left = s.left;
    sh.style.top = s.top;
    sh.style.setProperty('--s', s.size);
    shadows.push(sh);

    const el = stage.put(stoneLayer, 'img', 'stone');
    el.src = 'assets/stone.png';
    el.alt = '';
    el.draggable = false;
    el.style.left = s.left;
    el.style.top = s.top;
    el.style.setProperty('--s', s.size);
    el.style.setProperty('--r', s.rot);
    el.style.setProperty('--flip', s.flip);
    el.dataset.index = String(i);
    return el;
  });

  await stage.wait(2400);
  shadows.forEach((sh) => stage.fade(sh, 1, 1700));
  for (const el of stones) {
    stage.fade(el, 1, 1700);
    await stage.wait(400);
  }
  await stage.wait(1500);

  // ---------- 内视：空窍浮在眼前。里面那只蝉，很暗，很久没动。 ----------
  const eyeLayer = stage.layer(0.62);
  const eye = stage.put(eyeLayer, 'div', 'inner-eye');
  stage.put(eye, 'div', 'vault-sphere');
  const shell = stage.put(eye, 'div', 'vault-shell');
  stage.put(shell, 'div', 'vault-sea');
  stage.put(eye, 'div', 'vault-bloom');
  const bug = stage.put(eye, 'img', 'vault-cicada');
  bug.src = 'assets/cicada.png';
  bug.alt = '';
  bug.draggable = false;

  A.chime(659, 0.028, 6);
  await stage.fade(eyeLayer, 1, 3400);
  await stage.wait(1000);

  // 它动了一下。很轻，很吃力。它饿。
  const stir = () => {
    bug.classList.remove('nudge');
    void bug.offsetWidth;
    bug.classList.add('nudge');
    setTimeout(() => bug.classList.remove('nudge'), 1200);
  };
  A.chime(1244, 0.018, 2.6);
  stir();

  // ---------- 拖拽 ----------
  const dragRoot = document.getElementById('drag');
  let fed = 0;
  let retreated = false;
  let resolveDone;
  const done = new Promise((r) => { resolveDone = r; });

  const idleTimer = setTimeout(() => eye.classList.add('attract'), 13000);
  const stopIdle = () => clearTimeout(idleTimer);

  const syncEye = () => {
    eye.style.setProperty('--eye-bright', (0.50 + 0.20 * fed).toFixed(2));
    eye.style.setProperty('--eye-rate', (0.58 + 0.17 * fed).toFixed(2));
  };

  const backHome = (el) => {
    const h = HOME[Number(el.dataset.index)];
    el.classList.remove('dragging');
    el.style.position = '';
    el.style.transition = '';
    el.style.left = h.left;
    el.style.top = h.top;
    el.style.width = '';
    el.style.height = '';
    el.style.opacity = '';
    stoneLayer.appendChild(el);
    shadows[Number(el.dataset.index)].style.opacity = '';
    delete el.dataset.taken;
  };

  const feed = (el) => {
    const r = eye.getBoundingClientRect();
    const sh = shadows[Number(el.dataset.index)];
    stage.fade(sh, 0, 420);
    el.classList.remove('dragging');
    el.style.transition =
      'left .5s cubic-bezier(.5, 0, .8, .1), top .5s cubic-bezier(.5, 0, .8, .1), ' +
      'width .5s ease-in, height .5s ease-in, opacity .5s ease-in';
    el.style.left = `${r.left + r.width / 2}px`;
    el.style.top = `${r.top + r.height / 2}px`;
    el.style.width = '0.8vmin';
    el.style.height = '0.8vmin';
    el.style.opacity = '0';
    setTimeout(() => el.remove(), 560);
    setTimeout(() => sh.remove(), 500);

    fed += 1;
    A.swallow(fed - 1);
    syncEye();
    setTimeout(() => { if (fed > 0 && !retreated) stir(); }, 520);

    if (fed >= stones.length) setTimeout(() => resolveDone(), 1400);
  };

  const arm = (el) => {
    el.classList.add('grabbable');
    el.addEventListener('pointerdown', (e) => {
      if (el.dataset.taken) return;
      e.preventDefault();
      stopIdle();
      el.dataset.taken = '1';
      A.stoneTick();

      const r = el.getBoundingClientRect();
      el.classList.add('dragging');
      // 脱离视差层，改用屏幕坐标：层的位移不会再干扰拖拽
      dragRoot.appendChild(el);
      el.style.position = 'fixed';
      el.style.left = `${r.left + r.width / 2}px`;
      el.style.top = `${r.top + r.height / 2}px`;
      el.style.transition = '';
      // 拿起来了，桌面上的接触影就淡下去——它离开地面了
      shadows[Number(el.dataset.index)].style.opacity = '0.28';

      const move = (ev) => {
        el.style.left = `${ev.clientX}px`;
        el.style.top = `${ev.clientY}px`;
      };
      const up = (ev) => {
        window.removeEventListener('pointermove', move);
        window.removeEventListener('pointerup', up);
        const er = eye.getBoundingClientRect();
        const dx = ev.clientX - (er.left + er.width / 2);
        const dy = ev.clientY - (er.top + er.height / 2);
        if (Math.hypot(dx, dy) < er.width * 0.56) feed(el);
        else backHome(el);
      };
      window.addEventListener('pointermove', move);
      window.addEventListener('pointerup', up);
    });
  };

  for (const el of stones) arm(el);
  eye.classList.add('armed');

  // 点空窍 = 收回内视。喂过至少一颗才允许——不然这一场就白过了。
  eye.addEventListener('pointerdown', (e) => {
    e.stopPropagation();
    if (fed === 0) {
      A.chime(988, 0.02, 2.2);
      stir();
      return;
    }
    retreated = true;
    resolveDone();
  });

  await done;
  eye.classList.remove('armed');
  eye.classList.remove('attract');
  for (const el of stones) el.classList.remove('grabbable');

  // ---------- 收束 ----------
  await stage.wait(900);
  A.chime(494, 0.03, 7);
  await stage.fade(eyeLayer, 0, 2600);
  A.fadeRoom('vault', 0, 3000);
  await stage.wait(1200);
  await stage.wait(1600);
}
