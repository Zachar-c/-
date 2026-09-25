/* 可丢弃玩法探针。独立于 lab.html、正式数据与旧存档。 */
(() => {
  'use strict';
  const KEY = 'wenzhen.fast-loop.v1';
  const G = {
    moon:{name:'月光蛊',text:'3 伤害；炼蛊的共同胚子',damage:3,qi:1},
    needle:{name:'针影蛊',text:'2 伤害；稳定命中，但难破甲',damage:2,qi:1,seek:true},
    pierce:{name:'破甲月芒',text:'5 伤害，穿透重甲',damage:5,qi:2,pierce:true},
    seek:{name:'追风月芒',text:'4 伤害，无视闪避',damage:4,qi:2,seek:true},
    sealblade:{name:'封脉月芒',text:'4 伤害，压制反击',damage:4,qi:2,suppress:true},
    guard:{name:'石壳蛊',text:'杀招附带 2 护盾',shield:2},
    seal:{name:'封息蛊',text:'杀招压制反击',suppress:true},
    wind:{name:'听风蛊',text:'杀招无视闪避',seek:true}
  };
  const M = {stone:'石甲碎片',fang:'封息牙',feather:'逐风羽'};
  const ENEMIES = {
    armor:{name:'石甲守卫',problem:'重甲：普通攻击会被削减 2 点。',hp:12,damage:2,armor:2,drop:'stone',gu:'guard',stones:4},
    counter:{name:'封脉客',problem:'反制：未观察的蛊击会招来 2 点反击。',hp:10,damage:3,counter:true,drop:'fang',gu:'seal',stones:4},
    evade:{name:'风踪客',problem:'闪避：未观察的奇数次攻击会落空。',hp:11,damage:2,evade:true,drop:'feather',gu:'wind',stones:5},
    boss:{name:'三劫守关人',problem:'每回合在重甲、闪避和反制之间切换。读懂本回合形态再出手。',hp:23,damage:3,boss:true,stones:0}
  };
  const ART = {
    armor:'../assets/wenzhen/enemies/enemy_stone_wanderer.png',
    counter:'../assets/wenzhen/enemies/enemy_sanxiu.png',
    evade:'../assets/wenzhen/enemies/enemy_moth.png',
    boss:'../assets/wenzhen/enemies/enemy_thunder_crown_sovereign.png'
  };
  const ROUTES = [['armor','counter'],['evade','armor','counter']];
  const RECIPES = [
    {id:'pierce',mat:'stone',title:'破甲月芒',use:'破甲，重甲敌人变得可直击'},
    {id:'seek',mat:'feather',title:'追风月芒',use:'稳命中，闪避敌人不再拖回合'},
    {id:'sealblade',mat:'fang',title:'封脉月芒',use:'压反击，蛊击不再挨反制'}
  ];
  const SHOP = [{id:'moon',price:4},{id:'guard',price:3},{id:'seal',price:4},{id:'wind',price:4}];
  const $ = document.getElementById('app');
  const fresh = () => ({phase:'start',stage:0,hp:30,maxHp:30,qi:6,maxQi:6,stones:3,materials:{},gu:{moon:1,needle:1,guard:1},active:'moon',support:'guard',loadout:{cores:['moon','needle'],support:'guard'},moves:[{core:'moon',support:'guard'}],battle:null,reward:null,rested:false,guideSeen:{},soundOn:true,log:['新局：月光蛊、针影蛊与石壳蛊在手。'],builds:[],turns:0});
  function valid(s){return s && ['start','route','battle','reward','hub','ending'].includes(s.phase) && Number.isInteger(s.stage) && s.stage>=0 && s.stage<=2 && s.gu && s.materials && Array.isArray(s.log);}
  let state;
  try {state=JSON.parse(localStorage.getItem(KEY));if(!valid(state)) state=fresh();} catch {state=fresh();}
  state.guideSeen ||= {};
  state.soundOn ??= true;
  state.moves ||= [{core:state.active||'moon',support:state.support||'guard'}];
  if(!Object.hasOwn(state.gu,'needle')){state.gu.needle=1;delete state.guideSeen.battle0;delete state.guideSeen.battle1;delete state.guideSeen['boss-battle'];noteExistingSave();}
  if(state.battle){state.battle.thoughts ??= 3;state.battle.timeline ||= [];state.battle.counterWard ??= false;state.battle.focus ??= false;}
  state.loadout ||= {cores:[state.active||'moon','needle'],support:state.support||'guard'};
  function ownedCombat(){return Object.keys(state.gu).filter(id=>state.gu[id]>0&&G[id]?.damage);}
  function ownedSupport(){return Object.keys(state.gu).filter(id=>state.gu[id]>0&&!G[id]?.damage);}
  function normalizeLoadout(){
    const cores=ownedCombat(),supports=ownedSupport();
    state.loadout.cores=[...new Set(state.loadout.cores||[])].filter(id=>cores.includes(id)).slice(0,2);
    if(!state.loadout.cores.length&&cores.length)state.loadout.cores=[cores[0]];
    if(!supports.includes(state.loadout.support))state.loadout.support=supports[0]||null;
  }
  normalizeLoadout();
  function noteExistingSave(){state.log.unshift('实验规则更新：获得针影蛊；现在每回合可连续行动 3 次。');}
  let audioContext;
  function save(){try{localStorage.setItem(KEY,JSON.stringify(state));}catch{}}
  function note(t){state.log.unshift(t);state.log=state.log.slice(0,35);}
  function esc(t){return String(t).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
  function btn(action,label,disabled=false,extra=''){return `<button data-action="${action}" ${disabled?'disabled':''} ${extra}>${esc(label)}</button>`;}
  function stat(name,value){return `<div class="stat">${name}<b>${esc(value)}</b></div>`;}
  function meter(current,max){return `<div class="meter" role="meter" aria-valuemin="0" aria-valuemax="${max}" aria-valuenow="${current}"><i style="width:${Math.max(0,Math.min(100,Math.round(current/max*100)))}%"></i></div>`;}
  function cue(type){
    if(!state.soundOn)return;
    try{
      audioContext ||= new (window.AudioContext||window.webkitAudioContext)();
      const now=audioContext.currentTime, notes=type==='win'?[440,660,880]:type==='miss'?[220,175]:type==='hurt'?[190,145]:[330,440];
      notes.forEach((freq,i)=>{const osc=audioContext.createOscillator(),gain=audioContext.createGain(),at=now+i*.085;osc.type=type==='hurt'?'triangle':'sine';osc.frequency.setValueAtTime(freq,at);gain.gain.setValueAtTime(.001,at);gain.gain.exponentialRampToValueAtTime(.035,at+.012);gain.gain.exponentialRampToValueAtTime(.001,at+.13);osc.connect(gain);gain.connect(audioContext.destination);osc.start(at);osc.stop(at+.14);});
    }catch{/* 音频不可用时仍保留文字与动画反馈 */}
  }
  function currentEnemy(){return ENEMIES[state.battle?.id];}
  function mode(){const b=state.battle;if(!b)return '';return b.id==='boss'?['armor','evade','counter'][(b.turn-1)%3]:b.id;}
  function currentProblem(){const e=currentEnemy(),m=mode();return m==='armor'?`重甲 ${e.boss?2:e.armor}`:m==='evade'?'闪避：奇数次攻击会落空':'反制：未观察蛊击反伤 2';}
  function enemyIntent(){
    const b=state.battle,e=currentEnemy(),heavy=b.turn%2===0;
    return {damage:e.damage+(heavy?2:0),label:heavy?'蓄力重击':'直接攻击'};
  }
  function logHtml(){return `<section class="panel"><h3>战报</h3><ol class="log">${state.log.map(x=>`<li>${esc(x)}</li>`).join('')}</ol></section>`;}
  function header(){if(state.phase==='battle')return `<header class="battle-app-header"><strong>问真 <span>· 战斗</span></strong><div>${btn('show-guide','指引',false,'class="secondary"')}${btn('sound',state.soundOn?'音效开':'音效关',false,'class="secondary"')}</div></header>`;return `<h1>问真 · 快速玩法实验</h1><p class="muted small">独立实验版 · 选择猎物、炼出解法、重构杀招，再战 Boss　${btn('show-guide','查看本页指引',false,'class="secondary"')}${btn('sound',state.soundOn?'音效：开':'音效：关',false,'class="secondary"')}</p><div class="stats">${stat('气血',`${state.hp}/${state.maxHp}`)}${stat('真元',`${state.qi}/${state.maxQi}`)}${stat('元石',state.stones)}${stat('进度',`${state.stage}/3 战`)}${stat('已组杀招',`${state.moves.length} 式`)}</div>`;}
  function guideKey(){if(state.phase==='route')return `route${state.stage}`;if(state.phase==='battle')return state.battle?.id==='boss'?'boss-battle':`battle${state.stage}`;if(state.phase==='hub')return `hub${state.stage}`;return state.phase;}
  function guideHtml(){
    const key=guideKey();if(state.guideSeen[key])return '';
    const tips={
      start:['先学会一局怎么走','选择猎物 → 战斗 → 收取掉落 → 修整与交易 → 炼蛊、装配杀招 → 下一战。两场普通战后挑战 Boss。首次游玩先按按钮走完一局。'],
      route0:['先挑一个要解决的问题','石甲守卫掉破甲材料；封脉客掉压制反击材料。看“胜利”一行决定想炼哪支蛊，再点挑战。两条路线都能继续前进。'],
      route1:['带着目标选第二只敌人','回想刚才的炼蛊配方还缺哪种材料，再挑会掉它的敌人。风踪客掉稳定命中的材料；也可以继续追逐第一条路线。'],
      battle0:['同屏看敌情并出招','敌方意图、双方气血和念头会固定在顶部；下方直接使用蛊虫和杀招，不必回滑。每回合可连续行动 3 次，点“结束回合”后敌人才出手。'],
      battle1:['试试新解法','留意新蛊或新辅蛊是否改变了伤害、命中或反制。敌人出手前，当前形态与伤害已列在上方。'],
      reward:['掉落要先收取','点“收取并修整”，元石、专属材料和蛊才进入背包。材料用于对应炼蛊配方，蛊可以装进杀招或卖掉。'],
      hub1:['整备按这四步走','① 休整回血；② 按材料炼蛊；③ 组装杀招，再选本场上阵的两只攻击蛊和一只辅助蛊；④ 选择下一场敌人。未上阵的蛊仍留在背包。'],
      hub2:['最后检查一次构筑','Boss 每回合轮换重甲、闪避、反制，攻击意图也会预告。先休整，再选本场两只攻击蛊和一只辅助蛊；只有上阵蛊组成的杀招能使用。'],
      'boss-battle':['读形态，再决定出手','Boss 每回合按重甲 → 闪避 → 反制轮换。重甲用破甲或高伤；闪避用追风、听风或先观察；反制用封脉、封息或先观察。当前形态就在敌方气血旁。'],
      ending:['试另一条路线','再开一局时选不同的第一只敌人，炼出另一支月芒；比较你打第二战和 Boss 的行动是否改变。']
    };
    const [title,body]=tips[key]||tips.start;
    return `<section class="panel guide" aria-label="新手指引"><div class="step">新手指引 · ${state.stage+1}/3 战</div><h2>${title}</h2><p>${body}</p>${btn('hide-guide','明白了')}</section>`;
  }
  function startHtml(){return `<section class="panel intro"><div class="intro-layout"><div class="intro-art"><img src="fast-loop-assets/moon-crystal-gu.png" alt="月光水晶弯月灵虫"></div><div><div class="battle-kicker">月下初局</div><h2>以蛊为刃，寻自己的解法</h2><p class="lead">每战选择敌人，获取专属材料与蛊。起手的月光蛊伤害更高，针影蛊命中更稳；炼蛊还能打开破甲、追风或封脉分支。战前选择两只攻击蛊、一只辅助蛊，本场只能使用它们及对应杀招。赢过两场普通战，再击败三劫守关人。</p><p>每回合有 3 次行动：可以先侦查、再攻击、最后防御；点“结束回合”后敌人才按预告出手。战败即终局。</p>${btn('start','踏入此局')}</div></div></section>`;}
  function routeHtml(){const ids=ROUTES[state.stage]||[];return `<section class="panel"><div class="battle-kicker">下一场遭遇</div><h2>第 ${state.stage+1} 战 · 选择猎物</h2><p>先看自己缺哪种材料；每种敌人掉落对应的炼蛊钥匙。</p><div class="cards">${ids.map(id=>{const e=ENEMIES[id];return `<article class="card route-enemy"><div class="enemy-preview ${id==='boss'?'':'art-ink'}"><img src="${ART[id]}" alt="${e.name}立绘"></div><h3>${e.name}</h3><p>${e.problem}</p><p>胜利：${e.stones} 元石 · ${M[e.drop]} · ${G[e.gu].name}</p>${btn('fight','挑战',false,`data-id="${id}"`)}</article>`;}).join('')}</div></section>`;}
  function feedbackHtml(b){const f=b?.last;if(!f)return '';return `<div class="feedback ${f.tone}" role="status" aria-live="polite"><strong>第 ${f.turn} 回合 · ${esc(f.title)}</strong><div class="delta"><span class="dealt">敌方 −${f.enemyLoss} 气血</span>　<span class="hurt">我方 −${f.playerLoss} 气血</span>　<span class="quiet">念头 −${f.thoughtSpent||0} · 真元 −${f.qiSpent} / +${f.qiRecovered}</span></div><ul>${f.events.map(x=>`<li>${esc(x)}</li>`).join('')}</ul></div>`;}
  function arenaHtml(b,e){return `<div class="arena stage-${b.id} ${b.last?.enemyLoss?'art-impact':b.last?.blocked?'art-ward':''}" aria-label="战斗场景"><div class="scene-caption"><span>第 ${b.turn} 回合</span><b>${e.name}</b><span>${currentProblem()}</span></div><div class="actor-art actor-player ${b.last?.playerLoss?'art-hurt':''}"><img src="fast-loop-assets/moon-crystal-gu.png" alt="透明月晶般的月光蛊"></div><div class="actor-art actor-foe ${b.id==='boss'?'art-boss':'art-ink'} ${b.last?.enemyLoss?'art-hurt':''}"><img src="${ART[b.id]}" alt="${e.name}立绘"></div><div class="fighter player ${b.last?.playerLoss?'hit':b.last?.blocked?'blocked':''}"><div class="name">蛊师 · 你</div><div class="number">${state.hp}<small> / ${state.maxHp} 气血</small></div>${meter(state.hp,state.maxHp)}<div>真元 ${state.qi}/${state.maxQi} · 护盾 ${b.shield}</div></div><div class="versus" aria-hidden="true">对峙</div><div class="fighter foe ${b.last?.enemyLoss?'hit':b.last?.missed?'blocked':''}"><div class="name">${e.name}</div><div class="number">${b.hp}<small> / ${e.hp} 气血</small></div>${meter(b.hp,e.hp)}<div>${currentProblem()}</div></div></div>`;}
  function battleStatusHtml(b,e,intent){return `<div class="battle-status" role="status" aria-live="polite"><div class="battle-status-foe"><small>敌方 · ${e.name}</small><strong>${b.hp}/${e.hp} 气血</strong><span>${currentProblem()}</span></div><div class="battle-status-intent"><small>本回合敌意</small><strong>${intent.label} ${intent.damage} 伤害</strong><span>护盾 ${b.shield} · 预计失血 ${Math.max(0,intent.damage-b.shield)}</span></div><div class="battle-status-self"><small>你 · 第 ${b.turn} 回合</small><strong>${state.hp}/${state.maxHp} 气血</strong><span>真元 ${state.qi}/${state.maxQi} · 念头 ${b.thoughts}/3</span></div></div>`;}
  function battleHtml(){
    const b=state.battle,e=currentEnemy(),canAct=b.thoughts>0,intent=enemyIntent();
    const guActions=state.loadout.cores.map(id=>btn('gu',`${G[id].name} · ${G[id].damage} 伤害 / ${G[id].qi} 真元`,!canAct||state.qi<G[id].qi,`data-id="${id}"`)).join('');
    const supportActions=state.loadout.support?[btn('support',`${G[state.loadout.support].name} · ${state.loadout.support==='guard'?'护盾 +3':state.loadout.support==='seal'?'压制本回合反击':'下一击稳命中'} / 1 真元`,!canAct||state.qi<1,`data-id="${state.loadout.support}"`)].join(''):'';
    const moveActions=state.moves.filter(m=>state.loadout.cores.includes(m.core)&&state.loadout.support===m.support).map(m=>btn('move',`${G[m.core].name}＋${G[m.support].name} · ${G[m.core].damage+2} 伤害 / ${G[m.core].qi+1} 真元`,!canAct||state.qi<G[m.core].qi+1,`data-core="${m.core}" data-support="${m.support}"`)).join('');
    const timeline=b.timeline?.length?`<details class="turn-timeline"><summary>近期行动</summary><ol>${b.timeline.map(x=>`<li>${esc(x)}</li>`).join('')}</ol></details>`:'';
    return `<section class="panel enemy battle-screen"><div class="battle-kicker">遭遇 · ${state.stage+1}/3</div><h2>${e.name} · 第 ${b.turn} 回合</h2>${battleStatusHtml(b,e,intent)}<div class="battle-shell"><div class="battle-visual">${arenaHtml(b,e)}${feedbackHtml(b)}${timeline}</div><div class="battle-commands"><p class="command-hint">${e.problem}　先行动，再结束回合。</p><div class="action-group"><h3>基础与侦查</h3><div class="row">${btn('basic','拳脚 · 2 伤害',!canAct)}${btn('inspect','侦查 · 看穿下一击，护盾 +1',!canAct)}</div></div><div class="action-group"><h3>战斗蛊</h3><div class="row">${guActions}</div></div><div class="action-group"><h3>辅助蛊</h3><div class="row">${supportActions||'<span class="muted">未上阵辅助蛊</span>'}</div></div><div class="action-group"><h3>杀招</h3><div class="row">${moveActions||'<span class="muted">本场没有可用杀招</span>'}</div></div>${btn('end-turn',canAct?'结束回合 · 敌人出手':'念头耗尽 · 结束回合',false,'class="secondary"')}</div></div></section>`;
  }
  function rewardHtml(){const r=state.reward;return `<section class="panel"><h2>战斗胜利 · 战利品</h2>${feedbackHtml(state.battle)}<p>你击败了 ${ENEMIES[r.id].name}。获得 <strong>${r.stones} 元石</strong>、<strong>${M[r.drop]}</strong> 和 <strong>${G[r.gu].name}</strong>。</p><p>材料直接指向炼蛊分支；这只蛊也可用于重构杀招或卖出。</p>${btn('claim','收取并修整')}</section>`;}
  function canSell(id){return state.gu[id]>0&&(!G[id].damage||Object.entries(state.gu).filter(([key,n])=>n>0&&G[key].damage).reduce((sum,[,n])=>sum+n,0)>1);}
  function inventoryHtml(){return `<div class="cards"><div class="card"><h3>蛊虫</h3>${Object.entries(state.gu).filter(([,n])=>n>0).map(([id,n])=>`<div>${G[id].name} ×${n} <span class="muted small">${G[id].text}</span> ${btn('sell',`卖出 +2`,!canSell(id),`data-id="${id}"`)}</div>`).join('')}</div><div class="card"><h3>材料</h3>${Object.entries(M).map(([id,name])=>`<div>${name} ×${state.materials[id]||0} <span class="muted small">来自${Object.values(ENEMIES).find(e=>e.drop===id)?.name}</span></div>`).join('')}</div></div>`;}
  function loadoutHtml(){
    const cores=ownedCombat(),supports=ownedSupport(),ready=state.moves.filter(m=>state.loadout.cores.includes(m.core)&&state.loadout.support===m.support);
    return `<h3>本场上阵 · 构筑取舍</h3><p>攻击蛊最多 2 只，辅助蛊 1 只。未上阵的蛊留在背包，无法在下一场使用；只有主辅蛊都上阵的杀招可用。</p><div class="cards"><div class="card"><strong>攻击蛊 ${state.loadout.cores.length}/2</strong><div class="row">${cores.map(id=>btn('equip-core',`${state.loadout.cores.includes(id)?'✓ 上阵':'上阵'} ${G[id].name}`,false,`data-id="${id}" class="${state.loadout.cores.includes(id)?'secondary':''}"`)).join('')}</div><p class="muted small">已满时先撤下一只，再选择替代蛊。</p></div><div class="card"><strong>辅助蛊 ${state.loadout.support?G[state.loadout.support].name:'未选'}</strong><div class="row">${supports.map(id=>btn('equip-support',`${state.loadout.support===id?'✓ 上阵':'换成'} ${G[id].name}`,false,`data-id="${id}" class="${state.loadout.support===id?'secondary':''}"`)).join('')}</div></div></div><p class="notice">下场可用杀招：${ready.map(m=>`${G[m.core].name}＋${G[m.support].name}`).join('、')||'暂无；可先组装或调整上阵'}</p>`;
  }
  function hubHtml(){
    const next=state.stage===2;
    const activeOptions=Object.entries(state.gu).filter(([id,n])=>n>0&&G[id].damage).map(([id])=>`<option value="${id}" ${state.active===id?'selected':''}>${G[id].name} · ${G[id].text}</option>`).join('');
    const supportOptions=Object.entries(state.gu).filter(([id,n])=>n>0&&!G[id].damage).map(([id])=>`<option value="${id}" ${state.support===id?'selected':''}>${G[id].name} · ${G[id].text}</option>`).join('');
    const prepared=state.moves.map(m=>`<div class="prepared-move">${G[m.core].name}＋${G[m.support].name} ${btn('remove-move','拆解',false,`data-core="${m.core}" data-support="${m.support}"`)}</div>`).join('');
    return `<section class="panel"><h2>修整 · 决定下一种解法</h2><p>当前气血 ${state.hp}/${state.maxHp}。休整一次免费恢复 8 气血；也可用元石购买额外治疗。</p>${btn('rest','休整 +8 气血',state.rested||state.hp===state.maxHp)}${btn('heal','药汤 +8 气血 / 2 元石',state.stones<2||state.hp===state.maxHp)}<h3>坊市买卖</h3><div class="cards">${SHOP.map(o=>`<div class="card"><strong>${G[o.id].name}</strong><p>${G[o.id].text}</p>${btn('buy',`买入 ${o.price} 元石`,state.stones<o.price,`data-id="${o.id}"`)}</div>`).join('')}</div><h3>开炉炼蛊</h3><p>消耗一只月光蛊、一份指定材料和 2 元石。成品是新的战斗动词；若还想炼另一支，可在坊市买第二只月光蛊。</p><div class="cards">${RECIPES.map(r=>`<div class="card"><strong>${r.title}</strong><p>${r.use}</p><p>需 ${M[r.mat]} ×1 · 月光蛊 ×1 · 2 元石</p>${btn('forge','炼制',!state.gu.moon||!state.materials[r.mat]||state.stones<2,`data-id="${r.id}"`)}</div>`).join('')}</div><h3>重构杀招</h3><p>可组装多式杀招；只有组成它的主辅蛊都上阵，下场才可使用。杀招多耗 1 真元，伤害 +2，并继承主辅蛊效果。</p><label>主蛊 <select id="active">${activeOptions}</select></label><label>辅蛊 <select id="support">${supportOptions}</select></label>${btn('assemble','新增这一式杀招')}<div class="prepared-moves"><strong>已组杀招</strong>${prepared||'<p>暂无。可先组装杀招。</p>'}</div>${loadoutHtml()}${inventoryHtml()}<p>${next?'下一场是最终 Boss；进入后不能再返回坊市。':'下一场可再次按材料目标选择敌人。'}</p>${btn(next?'boss':'depart',next?'挑战三劫守关人':'选择下一场敌人',false,'class="secondary"')}</section>`;
  }
  function endingHtml(){const win=state.hp>0;return `<section class="panel end"><h2>${win?'问真 · 破关':'此局落败'}</h2>${feedbackHtml(state.battle)}<p>${win?'三劫守关人已败，你带着这条构筑走到终局。':'气血耗尽。下一局可以换一种猎物和炼蛊路线。'}</p><p>走过的构筑：${state.builds.length?state.builds.map(esc).join(' → '):'未完成构筑'}</p><p>总战斗回合：${state.turns}</p>${btn('restart','再开一局，试另一条路线')}</section>`;}
  function render(){let content='';if(state.phase==='start')content=startHtml();else if(state.phase==='route')content=routeHtml();else if(state.phase==='battle')content=battleHtml();else if(state.phase==='reward')content=rewardHtml();else if(state.phase==='hub')content=hubHtml();else content=endingHtml();$.innerHTML=header()+guideHtml()+content+logHtml();save();}
  function fail(){state.hp=0;state.phase='ending';note('气血耗尽，此局落败。');}
  function startFight(id){if(state.phase!=='route'&&!(state.phase==='hub'&&id==='boss'))return;const e=ENEMIES[id];if(!e)return;normalizeLoadout();state.phase='battle';state.battle={id,hp:e.hp,turn:1,thoughts:3,attacks:0,exposed:false,shield:0,counterWard:false,focus:false,timeline:[],last:null};state.qi=Math.min(state.maxQi,state.qi+3);note(`挑战 ${e.name}：${e.problem} 本场上阵 ${state.loadout.cores.map(x=>G[x].name).join('、')}＋${G[state.loadout.support]?.name||'无辅助蛊'}。`);}
  function finishAction(b,f,before){
    f.enemyLoss=before.enemy-b.hp;f.playerLoss=before.hp-state.hp;f.qiSpent=before.qi-state.qi;
    f.tone=f.enemyLoss>0?'good':f.playerLoss>0||f.missed?'bad':'neutral';
    if(b.hp<=0){f.title='敌人倒下';f.tone='good';f.events.push('敌人已败，无需等到回合结束。');}
    if(state.hp<=0){f.title='气血耗尽';f.tone='bad';}
    b.last=f;b.timeline.push(`${f.title}${f.enemyLoss?` · 敌方 −${f.enemyLoss}`:''}${f.playerLoss?` · 我方 −${f.playerLoss}`:''}`);b.timeline=b.timeline.slice(-6);
    if(state.hp<=0){state.turns++;fail();return;}
    if(b.hp<=0){state.turns++;const e=currentEnemy();if(b.id==='boss'){state.phase='ending';state.builds.push(state.moves.map(m=>`${G[m.core].name}＋${G[m.support].name}`).join(' / ')||'单蛊构筑');note('三劫守关人倒下，抵达终局。');}else{state.phase='reward';state.reward={id:b.id,stones:e.stones,drop:e.drop,gu:e.gu};note(`${e.name}倒下，待收取战利品。`);}}
  }
  function strike(kind,id,supportId){
    if(state.phase!=='battle')return;
    const b=state.battle,e=currentEnemy(),m=mode();if(b.thoughts<=0)return;
    const before={hp:state.hp,enemy:b.hp,qi:state.qi};
    const f={turn:b.turn,title:'',events:[],enemyLoss:0,playerLoss:0,qiSpent:0,qiRecovered:0,thoughtSpent:1,blocked:0,missed:false,tone:'neutral'};
    let core=null,support=null,qi=0,power=2,pierce=false,seek=false,suppress=false;
    if(kind==='gu'){if(!state.loadout.cores.includes(id)||!state.gu[id]||!G[id]?.damage)return;core=G[id];qi=core.qi;}
    if(kind==='move'){if(!state.moves.some(x=>x.core===id&&x.support===supportId)||!state.loadout.cores.includes(id)||state.loadout.support!==supportId||!state.gu[id]||!state.gu[supportId])return;core=G[id];support=G[supportId];qi=core.qi+1;}
    if(kind==='support'){if(state.loadout.support!==id||!state.gu[id]||G[id]?.damage)return;support=G[id];qi=1;}
    if(state.qi<qi)return;
    state.qi-=qi;b.thoughts--;
    if(kind==='inspect'){
      f.title='侦查破绽';b.exposed=true;b.shield+=1;f.events.push('下一次攻击看穿闪避和反制。','获得 1 护盾。');note('侦查看穿下一击，并获得 1 护盾。');
    }else if(kind==='support'){
      f.title=`${support.name}辅助`;
      if(id==='guard'){b.shield+=3;f.events.push('防御：获得 3 护盾，可抵挡回合末攻击。');}
      if(id==='seal'){b.counterWard=true;f.events.push('压制：本回合的蛊击不会触发反制。');}
      if(id==='wind'){b.focus=true;f.events.push('聚风：下一次攻击无视闪避。');}
      note(f.events[0]);
    }else{
      if(core){power=core.damage+(support?2:0);pierce=!!core.pierce;seek=!!core.seek;suppress=!!core.suppress;}
      if(support){seek ||= !!support.seek;suppress ||= !!support.suppress;}
      seek ||= b.focus;suppress ||= b.counterWard;
      const action=kind==='basic'?'拳脚':kind==='gu'?core.name:`${core.name}＋${support.name}杀招`;
      f.title=`${action}出手`;b.attacks++;
      let damage=power;
      if(m==='evade'&&!seek&&!b.exposed&&b.attacks%2===1){damage=0;f.missed=true;f.events.push('敌人闪避成功，本次攻击落空。');}
      if(m==='armor'&&!pierce){const reduction=Math.min(damage,e.boss?2:e.armor);damage-=reduction;f.events.push(`重甲挡下 ${reduction} 点伤害。`);}
      if(m==='armor'&&pierce)f.events.push('破甲生效：绕过重甲。');
      if(m==='evade'&&seek)f.events.push('稳定命中：敌人无法闪避。');
      if(m==='evade'&&b.exposed&&!seek)f.events.push('侦查生效：看穿闪避。');
      const enemyBefore=b.hp;b.hp=Math.max(0,b.hp-damage);const dealt=enemyBefore-b.hp;
      f.events.push(`${action}造成 ${dealt} 点伤害。`);note(`${action}造成 ${dealt} 伤害。`);
      if(m==='counter'&&kind!=='basic'){
        if(suppress)f.events.push('压制生效：敌人未能反击。');
        else if(b.exposed)f.events.push('侦查生效：避开敌人反制。');
        else{const beforeCounter=state.hp;state.hp=Math.max(0,state.hp-2);const lost=beforeCounter-state.hp;f.events.push(`触发反制：你受到 ${lost} 点伤害。`);note(`蛊击触发反制，受到 ${lost} 伤害。`);}
      }
      if(support?.shield){b.shield+=support.shield;f.events.push(`辅蛊提供 ${support.shield} 护盾。`);}
      b.exposed=false;b.focus=false;
    }
    finishAction(b,f,before);
  }
  function endTurn(){
    if(state.phase!=='battle')return;
    const b=state.battle,e=currentEnemy(),intent=enemyIntent(),beforeHp=state.hp,beforeQi=state.qi;
    const f={turn:b.turn,title:`${e.name}出手`,events:[],enemyLoss:0,playerLoss:0,qiSpent:0,qiRecovered:0,thoughtSpent:0,blocked:0,missed:false,tone:'neutral'};
    const blocked=Math.min(intent.damage,b.shield),incoming=intent.damage-blocked;
    b.shield-=blocked;state.hp=Math.max(0,state.hp-incoming);f.blocked=blocked;f.playerLoss=beforeHp-state.hp;
    if(blocked)f.events.push(`护盾挡下 ${blocked} 点伤害。`);
    f.events.push(`${intent.label}：你受到 ${f.playerLoss} 点伤害。`);note(`${e.name}${intent.label}：受到 ${f.playerLoss} 伤害。`);
    state.qi=Math.min(state.maxQi,state.qi+2);f.qiRecovered=state.qi-beforeQi;
    f.events.push(`恢复 ${f.qiRecovered} 真元，下一回合重获 3 念头。`);
    f.tone=f.playerLoss>0?'bad':'good';b.last=f;
    b.timeline.push(`${e.name}攻击 · 我方 −${f.playerLoss}${blocked?` · 护盾挡下 ${blocked}`:''}`);b.timeline=b.timeline.slice(-6);
    state.turns++;b.turn++;b.thoughts=3;b.counterWard=false;
    if(state.hp<=0)fail();
  }
  function claim(){if(state.phase!=='reward')return;const r=state.reward;state.stones+=r.stones;state.materials[r.drop]=(state.materials[r.drop]||0)+1;state.gu[r.gu]=(state.gu[r.gu]||0)+1;note(`入账：${r.stones} 元石、${M[r.drop]}、${G[r.gu].name}。`);state.reward=null;state.stage++;state.rested=false;state.phase='hub';}
  function forge(id){if(state.phase!=='hub')return;const r=RECIPES.find(x=>x.id===id);if(!r||!state.gu.moon||!state.materials[r.mat]||state.stones<2)return;state.gu.moon--;state.materials[r.mat]--;state.stones-=2;state.gu[id]=(state.gu[id]||0)+1;state.moves=state.moves.filter(m=>state.gu[m.core]>0&&state.gu[m.support]>0);if(state.gu[state.support]>0&&!state.moves.some(m=>m.core===id&&m.support===state.support))state.moves.push({core:id,support:state.support});state.active=id;if(!state.gu.moon)state.loadout.cores=state.loadout.cores.map(core=>core==='moon'?id:core);normalizeLoadout();note(`炼成 ${G[id].name}。失去月光蛊、${M[r.mat]} 与 2 元石；新蛊可单独使用。`);}
  function buy(id){if(state.phase!=='hub')return;const o=SHOP.find(x=>x.id===id);if(!o||state.stones<o.price)return;state.stones-=o.price;state.gu[id]=(state.gu[id]||0)+1;note(`买入 ${G[id].name}，支付 ${o.price} 元石。`);}
  function sell(id){if(state.phase!=='hub'||!canSell(id))return;state.gu[id]--;state.stones+=2;state.moves=state.moves.filter(m=>state.gu[m.core]>0&&state.gu[m.support]>0);if(!state.gu[state.active])state.active=Object.keys(state.gu).find(key=>state.gu[key]>0&&G[key].damage);if(!state.gu[state.support])state.support=Object.keys(state.gu).find(key=>state.gu[key]>0&&!G[key].damage);normalizeLoadout();note(`卖出 ${G[id].name}，获得 2 元石。`);}
  $.addEventListener('click',ev=>{const el=ev.target.closest('button[data-action]');if(!el||el.disabled)return;const a=el.dataset.action,id=el.dataset.id;
    if(a==='show-guide')delete state.guideSeen[guideKey()];
    else if(a==='hide-guide')state.guideSeen[guideKey()]=true;
    else if(a==='sound')state.soundOn=!state.soundOn;
    else if(a==='start'){state=fresh();state.phase='route';}
    else if(a==='restart'){state=fresh();state.phase='route';}
    else if(a==='fight'&&ROUTES[state.stage]?.includes(id))startFight(id);
    else if(['basic','inspect','gu','support','move'].includes(a)&&state.phase==='battle'){strike(a,a==='move'?el.dataset.core:id,el.dataset.support);const f=state.battle?.last;if(f)cue(f.title==='敌人倒下'?'win':f.missed?'miss':f.playerLoss>0?'hurt':'hit');}
    else if(a==='end-turn'&&state.phase==='battle'){endTurn();cue(state.battle.last?.playerLoss?'hurt':'hit');}
    else if(a==='claim')claim();
    else if(a==='rest'&&state.phase==='hub'&&!state.rested){state.hp=Math.min(state.maxHp,state.hp+8);state.rested=true;note('休整恢复 8 气血。');}
    else if(a==='heal'&&state.phase==='hub'&&state.stones>=2){state.stones-=2;state.hp=Math.min(state.maxHp,state.hp+8);note('药汤恢复 8 气血，支付 2 元石。');}
    else if(a==='buy')buy(id);else if(a==='sell')sell(id);else if(a==='forge')forge(id);
    else if(a==='equip-core'&&state.phase==='hub'&&ownedCombat().includes(id)){const list=state.loadout.cores;if(list.includes(id)){if(list.length>1)state.loadout.cores=list.filter(x=>x!==id);}else if(list.length<2)list.push(id);else note('攻击蛊上阵位已满，先撤下一只。');}
    else if(a==='equip-support'&&state.phase==='hub'&&ownedSupport().includes(id))state.loadout.support=id;
    else if(a==='assemble'&&state.phase==='hub'){const active=document.getElementById('active').value,support=document.getElementById('support').value;if(state.gu[active]>0&&state.gu[support]>0&&G[active].damage&&!G[support].damage){state.active=active;state.support=support;if(!state.moves.some(m=>m.core===active&&m.support===support)){state.moves.push({core:active,support});state.builds.push(`${G[active].name}＋${G[support].name}`);note(`新增杀招：${G[active].name}＋${G[support].name}。`);}else note('这式杀招已组装。');}}
    else if(a==='remove-move'&&state.phase==='hub'){state.moves=state.moves.filter(m=>m.core!==el.dataset.core||m.support!==el.dataset.support);note('杀招已拆解，蛊虫仍保留。');}
    else if(a==='depart'&&state.phase==='hub'&&state.stage<2)state.phase='route';
    else if(a==='boss'&&state.phase==='hub'&&state.stage===2)startFight('boss');
    render();
  });
  render();
})();
