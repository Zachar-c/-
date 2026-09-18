/* 第二幕 · 青茅山
   他从空窍里出来，回到世界。玩家还是只能看。
   这一场不做任何事，只是让人相信这个村子在雨里活着。 */

export async function rainScene(stage) {
  const A = stage.audio;

  A.fadeRoom('rain', 1, 3600);
  A.startAmbientDrops();

  const bg = stage.layer(0.16);
  const img = stage.put(bg, 'img', 'village');
  img.src = 'assets/village_rain.png';
  img.alt = '';
  img.draggable = false;

  const rainLayer = stage.layer(0.34);
  stage.put(rainLayer, 'div', 'rain');

  await stage.wait(60);
  img.classList.add('settle');       // 极慢地推远，镜头不是死的

  await stage.fade(bg, 1, 3000);
  await stage.fade(rainLayer, 0.36, 2400);

  await stage.wait(1600);

  const lineLayer = stage.layer(0.08);
  stage.put(lineLayer, 'div', 'narration', '青茅山。落雨。');
  await stage.fade(lineLayer, 1, 2400);

  await stage.wait(4400);
  await stage.fade(lineLayer, 0, 2400);
}
