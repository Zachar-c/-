/* 第四幕 · 窗外站着一个人
   他送来一颗元石，理由只有一句：「你昨天帮过我。」
   玩家前三幕什么都没做过——这件事玩家自己知道。
   所以这一幕不给旁白、不给证据、不给结论。它只负责让玩家开始问：
   他为什么帮我？

   这一幕整幅换掉（换机位就是换一幅画），因为要的是近景：
   隔着窗台看出去，他在雨里，脸看不清。 */

const GIVE = '你昨天帮过我。';
const ANSWER = '……坡上。昨天傍晚。';

const OPTIONS = [
  { key: 'take', text: '收下' },
  { key: 'ask', text: '问他，帮了什么' },
  { key: 'refuse', text: '不要' },
];

export async function visitScene(stage) {
  const A = stage.audio;

  // 同一场雨，只是这次离得近。空窍那点低频从第一幕起就没真的停过。
  A.soundVault(); A.soundRain(); A.soundRoom();
  A.fadeRoom('rain', 0.62, 4400);
  A.fadeRoom('room', 0.18, 4400);
  A.fadeRoom('vault', 0.11, 5000);
  A.startAmbientDrops();

  // 先把上一幕的屋子退干净，中间留一小段黑。机位换了，人也该喘一口气。
  await stage.fadeOutAll(2600);
  await stage.wait(950);

  const plateLayer = stage.layer(0.18);
  const plate = stage.put(plateLayer, 'div', 'visitor-plate');

  const img = stage.put(plate, 'img', 'visitor');
  img.src = 'assets/visitor.png';
  img.alt = '';
  img.draggable = false;

  // 窗上那层雨雾。开场它把整扇窗糊住——人一直都在，只是看不见。
  const haze = stage.put(plate, 'div', 'haze');
  haze.style.opacity = '1';

  // 他搁在窗台上的那颗元石。比屋里那三颗离眼睛近，所以大一点。
  const stone = stage.put(plate, 'img', 'stone sill-stone');
  stone.src = 'assets/stone.png';
  stone.alt = '';
  stone.draggable = false;
  stone.style.opacity = '0';

  await stage.fade(plateLayer, 1, 3800);     // 一整面雨，什么都看不出来
  plate.classList.add('settle');             // 极慢推近，镜头不是死的
  await stage.wait(700);

  // 雨里有人在说话。听不清，也不需要听清。声音在画面之外。
  A.murmur(2, 0, -0.44, 0.075);
  A.murmur(3, 0.6, -0.24, 0.05);
  await stage.wait(1300);

  // 雾散开。他一直站在那儿。
  await stage.fade(haze, 0.20, 6000);
  await stage.wait(1900);

  // 他把手伸到窗台上，放下一样东西。
  A.stoneTick();
  await stage.fade(stone, 1, 1500);

  await stage.wait(1700);

  // 唯一的一句台词。他说的，不是旁白。
  const lineLayer = stage.layer(0.06);
  stage.put(lineLayer, 'div', 'spoken', GIVE);
  await stage.fade(lineLayer, 1, 2600);

  await stage.wait(1500);

  // 玩家自己的三个动作，还没说出口。不是菜单——选完就没了。
  const choiceLayer = stage.layer(0.06);
  choiceLayer.style.opacity = '1';
  const box = stage.put(choiceLayer, 'div', 'choices');
  const els = OPTIONS.map((o) => {
    const el = stage.put(box, 'div', 'choice', o.text);
    el.dataset.key = o.key;
    return el;
  });

  for (const el of els) {
    stage.fade(el, 1, 900);
    await stage.wait(320);
  }
  await stage.wait(900);

  const pick = await new Promise((res) => {
    els.forEach((el) => el.addEventListener('pointerdown', () => res(el.dataset.key), { once: true }));
  });

  // 选完了，三个动作一起收回去。留在画面上的只有他说的那两句。
  els.forEach((el) => stage.fade(el, 0, 700));

  if (pick === 'ask') {
    await stage.wait(1700);                  // 他停了一下才回答
    A.murmur(2, 0, -0.30, 0.05);
    const ansLayer = stage.layer(0.06);
    stage.put(ansLayer, 'div', 'spoken dim', ANSWER);
    await stage.fade(ansLayer, 1, 1900);
  } else if (pick === 'refuse') {
    await stage.wait(900);
    A.stoneTick();
    await stage.fade(stone, 0, 1100);
  } else {
    stone.classList.add('taken');
    A.chime(880, 0.02, 5.5);
  }

  stage.state.act4 = pick;

  await stage.wait(2100);

  // 他还站在窗外。另一个人也还在雨里。谁都没动。
  A.murmur(2, 0, -0.5, 0.055);
  A.fadeRoom('rain', 0.4, 3000);
  await stage.wait(2600);
}
