import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {P,dir,rank,scale,markFactor,pathFactor,essenceCost,damageWithGu,schedule,aperture,refinement,ascend,canPromote,fight,expedition,recipeOffer,reincarnate,tribulationPower,tribulationFight,resolveTribulation,campaign,combo,controlDuration,refineAttempt,rng,createSupply,auditBuilds,carrierOf,damageClass,marksAt} from './model.mjs';
const t0=Date.now();

// ---------- CLI（v0.2）----------
const USAGE=`用法：node validate.mjs [--builds <gu-library.json>] [--supply <supply.json>] [--scenarios supply_limited,key_gu_missing,refine_tail] [--campaign-seeds N]

无参数：运行全部不变量检查（v0.1 21 项 + v0.2 新增项）、载体矩阵节与灾劫两口径节；不依赖 gu-library.json 存在。
--builds <file>        构筑库文件（gu-library.json 语义）。文件缺失或解析失败时打印说明并跳过「真实构筑×供应」节。
--supply <file>        供应数据文件（默认读本目录 supply.json）。缺失时供应数据边界检查跳过，构筑×供应节按「全部可得、价格倍率 1」基线运行。
--scenarios <list>     逗号分隔：supply_limited,key_gu_missing,refine_tail（默认全部三个）。
--campaign-seeds <N>   灾劫两口径节与构筑×供应节的账本种子数（默认 30，1..2000）。`;
const argv=process.argv.slice(2);
if(argv.includes('--help')||argv.includes('-h')){console.log(USAGE);process.exit(0);}
const argOf=flag=>{const i=argv.indexOf(flag);return i>=0&&i+1<argv.length?argv[i+1]:null;};
const buildsArg=argOf('--builds');
const supplyArg=argOf('--supply');
const scenariosArg=argOf('--scenarios');
const seedsArg=argOf('--campaign-seeds');
const SCENARIO_KEYS=['supply_limited','key_gu_missing','refine_tail'];
const scenarioKeys=scenariosArg?scenariosArg.split(',').map(s=>s.trim()).filter(Boolean):[...SCENARIO_KEYS];
for(const k of scenarioKeys)if(!SCENARIO_KEYS.includes(k)){console.error(`错误：未知 scenario「${k}」（可用：${SCENARIO_KEYS.join(',')}）`);process.exit(2);}
const campaignSeeds=seedsArg?Number(seedsArg):30;
if(!Number.isInteger(campaignSeeds)||campaignSeeds<1||campaignSeeds>2000){console.error('错误：--campaign-seeds 需为 1..2000 的整数');process.exit(2);}

const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const supplyFile=supplyArg?path.resolve(supplyArg):path.join(dir,'supply.json');
let supplyData=null,supplyFileHash=null,supplyNote=null;
if(fs.existsSync(supplyFile)){
  try{supplyData=JSON.parse(fs.readFileSync(supplyFile,'utf8'));supplyFileHash=hash(supplyFile);}
  catch(e){supplyNote=`供应文件解析失败（${supplyFile}）：${e.message}。供应数据边界检查跳过；构筑×供应场景臂按全可得基线运行。`;}
}else supplyNote=`供应文件不存在（${supplyFile}）。供应数据边界检查跳过；构筑×供应场景臂按「全部可得、价格倍率 1」基线运行。`;
let lib=null,buildsFileHash=null,libNote=null;
if(buildsArg!=null){
  const bf=path.resolve(buildsArg);
  if(fs.existsSync(bf)){
    try{lib=JSON.parse(fs.readFileSync(bf,'utf8'));buildsFileHash=hash(bf);}
    catch(e){libNote=`构筑库解析失败（${bf}）：${e.message}。跳过「真实构筑×供应」节。`;}
  }else libNote=`构筑库不存在（${bf}）。跳过「真实构筑×供应」节；gu-library.json 尚未交付时这是预期状态，默认运行不依赖该文件。`;
}
for(const n of [libNote,supplyNote])if(n)console.error('提示：'+n);

// ---------- v0.1 不变量检查（保持原序与原文） ----------
const checks=[];
function check(name,fn){fn();checks.push(name);}
if(lib)check('酒虫仅作一转真元品质提纯，不映射战斗回复',()=>{
  const wine=lib.gu?.find(g=>g.id==='wine-insect-gu');
  assert(wine,'构筑库缺少酒虫条目');
  assert.notEqual(wine.poweredAction,'drain','酒虫不能映射为 drain 战斗动作');
  assert(wine.effects?.some(e=>e.kind==='essence-quality'&&/一个小境界/.test(e.note??'')),'酒虫须登记一转真元提纯一个小境界');
  assert(!wine.effects?.some(e=>e.kind==='recovery'),'酒虫不得登记真元回复效果');
  const visit=node=>{
    if(Array.isArray(node))return node.forEach(visit);
    if(!node||typeof node!=='object')return;
    assert(node.gu!=='wine-insect-gu','构筑战斗槽位不能绑定酒虫；酒虫是修炼阶段真元提纯蛊');
    for(const value of Object.values(node))visit(value);
  };
  visit(lib.builds);
});
check('九转与各阶仙元名称',()=>{assert.equal(P.ranks.length,9);assert.equal(rank(9).essence,'黄杏仙元');assert.throws(()=>rank(10));});
check('七到八转基准差距大于六到七，不制造晋阶道痕',()=>{assert(scale(8)/scale(7)>scale(7)/scale(6));assert(scale(8)/scale(7,1)>scale(7)/scale(6,1));});
check('一至三转真元10倍不等于伤害10倍',()=>{assert.equal(essenceCost(2,1).cost,1);assert.equal(essenceCost(3,1).cost,.1);assert.equal(scale(2)/scale(1),2);});
check('下位蛊不继承宿主的转数输出',()=>assert.equal(damageWithGu(5,1),damageWithGu(1,1)));
check('禁常规越阶催动，凡仙资源池分离',()=>{assert.throws(()=>essenceCost(1,6));assert.equal(essenceCost(6,5).pool,'mortal');assert.equal(essenceCost(6,6).pool,'immortal');});
check('道痕增幅与异道冲突边界',()=>{assert.equal(markFactor(1000),2);assert.equal(pathFactor(1000,0),1);assert(pathFactor(1000,10000)<1);assert(pathFactor(1000,1e9)>=.35);});
check('六七八转灾劫次数和道痕守恒',()=>{const expected={6:[30,3,0,0],7:[30,6,3,0],8:[0,30,6,3]};for(let r=6;r<=8;r++){const s=schedule(r);assert.deepEqual(['earth','heaven','grand','myriad'].map(k=>s.filter(e=>e.kind===k).length),expected[r]);assert.equal(rank(r).marksStart+s.reduce((a,e)=>a+e.marks,0),rank(r).marksEnd);assert.equal(rank(r).marksEnd,rank(r+1).marksStart);}});
check('灾劫各级内部增长且不越级',()=>{const kinds=['earth','heaven','grand','myriad'];for(let i=0;i<4;i++){assert(tribulationPower(kinds[i],1,30)<=tribulationPower(kinds[i],30,30));if(i<3)assert(tribulationPower(kinds[i],30,30)<tribulationPower(kinds[i+1],1,30));}});
check('内外时间同向增加生产与灾劫；超过300年仍计时',()=>{const a=aperture({externalYears:10,speed:10}),b=aperture({externalYears:10,speed:20});assert.equal(b.essence,a.essence*2);assert(b.events.length>a.events.length);assert.equal(aperture({externalYears:400,speed:1}).events.filter(e=>e.kind==='earth').length,40);});
check('死窍不自产不招灾，九转周期不伪造已知',()=>{const a=aperture({externalYears:10,speed:30,dead:true});assert.equal(a.essence,0);assert.equal(a.events.length,0);assert.equal(aperture({externalYears:10,speed:1,r:9}).tribulationPeriodKnown,false);});
check('仙蛊唯一和炼制概率上限',()=>{assert.equal(refinement(6,{uniqueExists:true}).possible,false);assert(refinement(9,{attainment:100}).success<1);assert(refinement(9,{prepared:true}).success>refinement(9).success);});
check('升仙均衡成功、贪吸失败、失败不可逆、非法输入拒绝',()=>{const steps=Array.from({length:5},()=>({heaven:.2,earth:.2}));assert(ascend({humanQi:1,steps,prepared:1,guard:1}).success);const fail=ascend({humanQi:1,steps:[{heaven:.5,earth:0}]});assert(!fail.success&&fail.irreversible);assert.throws(()=>ascend({humanQi:1,steps:[{heaven:-1,earth:0}]}));});
check('成尊多条件，不靠道痕或三次万劫自动晋升',()=>{const s={internalYears:300,allTribulationsResolved:true,alive:true,marks:316000,attainment:'无上大宗师',research:100,heavenSealBroken:true};assert(canPromote(8,s));for(const key of ['heavenSealBroken','allTribulationsResolved','alive'])assert(!canPromote(8,{...s,[key]:false}));assert(!canPromote(8,{...s,attainment:'宗师'}));assert(!canPromote(9,s));});
check('轮回保留知识，不保留属性；已知配方不稀释未知发现',()=>{const s=reincarnate({knownRecipes:['a','a'],rank:9,money:1000,gu:['x'],attainment:5});assert.deepEqual(s,{knownRecipes:['a'],rank:1,money:0,gu:[],attainment:0});assert.deepEqual(recipeOffer(['a'],['a','b'],1),['b']);assert.deepEqual(recipeOffer(['a'],['a'],1),[]);});
check('战斗确定性与资源边界',()=>{const a=fight({seed:99,trace:true});assert.deepEqual(a,fight({seed:99,trace:true}));assert(a.energyFraction>=0&&a.energyFraction<=1);assert(a.turns<=P.combat.maxTurns);});
check('买卖和失败残值无直接套利',()=>{assert(P.economy.resaleFraction<1);assert(P.economy.failureSalvageFraction<1);assert.equal(P.refinement.refundInputGu,false);});
check('杀招心智容量和控制递减',()=>{assert(combo({r:1,components:2}).legal);assert(!combo({r:1,components:8}).legal);assert(controlDuration(2,3)<controlDuration(2,0));assert(combo({r:9,components:6,attainment:5}).multiplier<=1.6);});
check('炼蛊交易原子性、投入消耗、本命蛊失败保留',()=>{
  const args={r:9,maxRank:9,inventory:['a','b'],inputs:['a','b'],output:'c',known:true,wallet:1000,prepared:true};
  assert.throws(()=>refineAttempt({...args,maxRank:8}));
  assert.throws(()=>refineAttempt({...args,inputs:['a','a']}));assert.throws(()=>refineAttempt({...args,registry:['c']}));
  const seed=Array.from({length:100},(_,i)=>i).find(seed=>!refineAttempt({...args,seed}).success);
  const bad=refineAttempt({...args,seed}),bond=refineAttempt({...args,seed,bondedId:'a'});
  assert.deepEqual(bad.inventory,[]);assert.deepEqual(bond.inventory,['a']);assert(bond.injury>0&&bond.bondedInjured);assert.equal(args.wallet,1000);
});
check('随机种子相邻不会集中在极窄区间',()=>{const a=Array.from({length:100},(_,i)=>rng(i)());assert(Math.max(...a)-Math.min(...a)>.9);});
const mean=a=>a.reduce((x,y)=>x+y,0)/a.length;
const summary=a=>({samples:a.length,winRate:mean(a.map(x=>+x.win)),turns:mean(a.map(x=>x.turns)),remainingHp:mean(a.map(x=>x.hpFraction)),spent:mean(a.map(x=>x.spent))});
const builds=['burst','balanced','sustain'],enemies=Object.keys(P.enemies),matrix=[];
for(let r=1;r<=9;r++)for(const enemy of enemies)for(const build of builds){const a=[];for(let i=0;i<P.validation.seeds;i++)a.push(fight({r,enemy,build,seed:P.validation.fixedSeed+i}));matrix.push({rank:r,enemy,build,...summary(a)});}
const sensitivity=[];
for(const factor of P.validation.perturbations)for(const key of ['enemyMultiplier','actionMultiplier'])for(const build of builds){const a=[];for(let r=1;r<=9;r++)for(const enemy of enemies)for(let i=0;i<30;i++)a.push(fight({r,enemy,build,seed:i,[key]:factor}));sensitivity.push({key,factor,build,...summary(a)});}
const crossRank=[];for(let r=1;r<9;r++){crossRank.push({from:r,to:r+1,...summary(Array.from({length:100},(_,i)=>fight({r,enemyRank:r+1,enemy:'pressure',build:'burst',seed:i})))});}
const economy=[];for(let r=1;r<=9;r++)for(const build of builds){const a=Array.from({length:100},(_,i)=>expedition({r,build,seed:i}));economy.push({rank:r,build,survival:mean(a.map(x=>+x.success)),meanWallet:mean(a.map(x=>x.wallet)),refineAffordable:mean(a.map(x=>+!!x.canRefine))});}
const campaigns=[];for(const build of builds)for(const preparation of [0,.5,1])for(const rewardMultiplier of [.8,1,1.2]){const a=Array.from({length:30},(_,i)=>campaign({build,preparation,rewardMultiplier,seed:i}));const failures={};for(const x of a)if(!x.success){const k=`${x.r}转:${x.reason}`;failures[k]=(failures[k]??0)+1;}campaigns.push({build,preparation,rewardMultiplier,samples:a.length,completion:mean(a.map(x=>+x.success)),meanBattles:mean(a.map(x=>x.totalBattles)),failures});}
const representative=campaign({build:'sustain',seed:1});
check('基准筹备路线可以实际走通一至九转',()=>{assert(representative.success,JSON.stringify(representative));assert.equal(representative.totalBattles,126);assert.equal(representative.marks,1000000);});
const aptitudes=Object.entries(P.aptitudes).map(([name,aptitude])=>({name,aptitude,...summary(Array.from({length:100},(_,seed)=>fight({r:1,build:'balanced',aptitude,seed})))}));
const refinementRisk=P.ranks.map(x=>{const q=refinement(x.rank,{prepared:true}),a=[];for(let i=0;i<10000;i++){const u=rng(i)();a.push(Math.ceil(Math.log(1-u)/Math.log(1-q.success)));}a.sort((a,b)=>a-b);return {rank:x.rank,probability:q.success,meanAttempts:mean(a),p95Attempts:a[9499],p95Fee:a[9499]*q.fee,theoreticalP95:Math.ceil(Math.log(.05)/Math.log(1-q.success)-1e-12)};});
const boundaryCrossRank=[];for(let r=1;r<9;r++)boundaryCrossRank.push({from:r,to:r+1,...summary(Array.from({length:100},(_,i)=>fight({r,progress:1,enemyRank:r+1,enemyProgress:0,enemy:'pressure',build:'burst',seed:i})))});
check('炼蛊Monte Carlo均值接近理论期望，95%分位检验尾概率',()=>{for(const x of refinementRisk){assert(Math.abs(x.meanAttempts-1/x.probability)<.08);assert(x.p95Attempts>=1);assert(Math.pow(1-x.probability,x.p95Attempts)<=.06);}});

// ---------- v0.2 新增检查（载体、灾劫实战口径、构筑审计、供应解析） ----------
const carriers=['soulBody','guHouse','beastPack'];
check('载体战斗按种子确定，且与常规模板结果有差异',()=>{
  for(const enemy of carriers){
    assert.deepEqual(fight({r:3,enemy,build:'burst',seed:77,trace:true}),fight({r:3,enemy,build:'burst',seed:77,trace:true}));
    assert.notDeepEqual(fight({r:3,enemy,build:'burst',seed:77,trace:true}),fight({r:3,enemy:'pressure',build:'burst',seed:77,trace:true}));
    assert.equal(carrierOf(enemy),enemy);
  }
  assert.equal(damageClass('burst'),'burst');assert.equal(damageClass('strike'),'regular');
});
check('soulBody 对常规动作减伤可观测，爆发类全额承伤',()=>{
  const strikes=[],bursts=[];
  for(let i=0;i<100;i++)for(const e of fight({r:1,enemy:'soulBody',build:'burst',seed:i,trace:true}).log){
    if(e.action==='strike')strikes.push(e.damage);
    if(e.action==='burst')bursts.push(e.damage);
  }
  assert(strikes.length>=40&&bursts.length>=40,'soulBody 追踪样本不足');
  const mStrike=mean(strikes),mBurst=mean(bursts);
  const resistFactor=1-P.carriers.soulBodyResist.regular;
  assert(mStrike>24*resistFactor*0.95&&mStrike<24*resistFactor*1.05,`soulBody 常规减伤不可观测：strike 均值 ${mStrike.toFixed(2)}`);
  assert(mBurst>66*0.9&&mBurst<66*1.1,`soulBody 爆发未全额承伤：burst 均值 ${mBurst.toFixed(2)}`);
});
check('guHouse 高耐受低输出，beastPack 群体衰减与范围收益',()=>{
  const gh=Array.from({length:30},(_,i)=>fight({r:1,enemy:'guHouse',build:'balanced',seed:i,trace:true}));
  assert(mean(gh.map(x=>+x.win))>0.8,'guHouse 高耐受模板在基准构筑下胜率异常低');
  const ghIncoming=gh.flatMap(x=>x.log.map(e=>e.incoming));
  assert(mean(ghIncoming)<5.5,`guHouse 输出未体现低攻：incoming 均值 ${mean(ghIncoming).toFixed(2)}`);
  const prTurns=Array.from({length:30},(_,i)=>fight({r:1,enemy:'pressure',build:'balanced',seed:i}).turns);
  assert(mean(gh.map(x=>x.turns))>mean(prTurns),'guHouse 战斗未体现高耐受（回合数应显著更长）');
  const bp=Array.from({length:30},(_,i)=>fight({r:1,enemy:'beastPack',build:'balanced',seed:i,trace:true}));
  const first=bp.map(x=>x.log[0].incoming),last=bp.map(x=>x.log[x.log.length-1].incoming);
  assert(mean(last)<mean(first)*0.8,`beastPack 输出未随剩余单位衰减：first ${mean(first).toFixed(2)} last ${mean(last).toFixed(2)}`);
  const bpStrikes=bp.flatMap(x=>x.log.filter(e=>e.action==='strike').map(e=>e.damage));
  assert(mean(bpStrikes)>24*P.carriers.packAoeYield.strike*0.95&&mean(bpStrikes)<24*P.carriers.packAoeYield.strike*1.05,`beastPack 范围收益系数不可观测：strike 均值 ${mean(bpStrikes).toFixed(2)}`);
  const bpb=Array.from({length:30},(_,i)=>fight({r:1,enemy:'beastPack',build:'burst',seed:i,trace:true}));
  const bpBursts=bpb.flatMap(x=>x.log.filter(e=>e.action==='burst').map(e=>e.damage));
  assert(mean(bpBursts)>66*P.carriers.packAoeYield.burst*0.95&&mean(bpBursts)<66*P.carriers.packAoeYield.burst*1.05,`beastPack 爆发范围收益不可观测：burst 均值 ${mean(bpBursts).toFixed(2)}`);
});
check('灾劫实战口径与聚合代理返回同形，账本接口一致',()=>{
  const cases=[[6,'earth',30],[6,'heaven',3],[7,'earth',30],[7,'heaven',6],[7,'grand',3],[8,'heaven',30],[8,'grand',6],[8,'myriad',3]];
  for(const [r,kind,count] of cases){
    const m=marksAt(r,.5),inc=rank(r).tribulations[kind].marks;
    const a=resolveTribulation({r,kind,ordinal:1,count,preparation:1,marks:m});
    const b=tribulationFight({r,kind,ordinal:1,count,seed:1,marks:m});
    assert.deepEqual(Object.keys(b).sort(),Object.keys(a).sort());
    assert.equal(typeof b.alive,'boolean');
    for(const k of ['injury','ecology','marks','power','margin'])assert.equal(typeof b[k],'number',k);
    assert(b.injury>=0&&b.injury<=1&&b.ecology>=0&&b.ecology<=1);
    assert.equal(b.marks,b.alive?m+inc:m,'存活/失败的道痕记账应与聚合代理一致');
    assert.equal(b.power,tribulationPower(kind,1,count));
  }
  assert.deepEqual(tribulationFight({r:7,kind:'heaven',ordinal:2,count:6,seed:9}),tribulationFight({r:7,kind:'heaven',ordinal:2,count:6,seed:9}));
});
check('构筑审计：未知蛊、越阶、缺fallback、超心智容量、fallback强于本体全部登记',()=>{
  const gus=[{id:'a',rank:1},{id:'b',rank:1},{id:'c',rank:1},{id:'d',rank:1},{id:'hi',rank:5}];
  const mk=slots=>({gu:gus,builds:{t:{ranks:{1:{slots}}}}});
  const types=slots=>auditBuilds(mk(slots)).map(i=>i.type);
  assert(types([{gu:'nope',poweredAction:'strike',fallbacks:[{gu:'b'}]}]).includes('unknown-gu'));
  assert(types([{gu:'hi',poweredAction:'strike',fallbacks:[{gu:'b'}]}]).includes('over-rank-slot'));
  assert(types([{gu:'a',poweredAction:'strike',fallbacks:[{gu:'ghost',poweredAction:'strike'}]}]).includes('unknown-fallback'));
  assert(types([{gu:'a',poweredAction:'strike'}]).includes('no-fallback'));
  assert(types([{gu:'a',poweredAction:'strike',fallbacks:[{gu:'b'}]},{gu:'b',poweredAction:'strike',fallbacks:[{gu:'a'}]},{gu:'c',poweredAction:'strike',fallbacks:[{gu:'a'}]},{gu:'d',poweredAction:'strike',fallbacks:[{gu:'a'}]},{gu:'a',poweredAction:'basic',fallbacks:[{gu:'b'}]}]).includes('capacity-exceeded'));
  const fb=auditBuilds(mk([{gu:'a',poweredAction:'burst',fallbacks:[{gu:'hi',poweredAction:'burst'}]}]));
  assert(fb.some(i=>i.type==='fallback-stronger'&&i.sFb>i.sPrim),'fallback 强于本体必须登记');
  assert.deepEqual(auditBuilds(mk([{gu:null,poweredAction:'drain',fallbacks:[{gu:null,poweredAction:'drain'}]}])),[],'明示的匿名预算不是未知蛊');
  assert(types([{gu:null,poweredAction:'unknown'}]).includes('unknown-action'),'匿名预算仍须合法动作');
  assert.deepEqual(auditBuilds(mk([{gu:'a',poweredAction:'strike',fallbacks:[{gu:'b',poweredAction:'strike'}]}])),[]);
});
check('供应解析：gu精确匹配优先于泛匹配，同级行内 first-match-wins，key_gu_missing 强制整局不可得',()=>{
  const sup={supply:[
    {match:{rank:1},channel:'market',availability:0.9,priceMultiplier:1},
    {match:{gu:'ml'},channel:'condition',availability:0.85,priceMultiplier:1}
  ]};
  const s=createSupply({supplyJson:sup,seed:1});
  assert.equal(s.resolve({id:'ml',rank:1}).channel,'condition','gu 精确行应优先于泛匹配行（与数组顺序无关）');
  assert.equal(s.resolve({id:'rc',rank:1}).channel,'market');
  const s2=createSupply({supplyJson:{supply:[{match:{gu:'ml'},availability:.2,channel:'drop'},{match:{gu:'ml'},availability:.8,channel:'market'}]},seed:1});
  assert.equal(s2.resolve({id:'ml',rank:1}).availability,.2,'同 gu 多行时保持文件内相对顺序取第一行');
  const s3=createSupply({supplyJson:sup,seed:1,scenario:{key_gu_missing:{dropGu:['ml']}}});
  const r3=s3.resolve({id:'ml',rank:1});
  assert.equal(r3.available,false);assert.equal(r3.forcedMissing,true);
  assert.deepEqual(createSupply({supplyJson:null,seed:1}).resolve({id:'any',rank:1}),{available:true,availability:1,priceMultiplier:1,channel:null,matched:false,forcedMissing:false});
});
check('availability 有界且不可刷：场景乘数截断到[0,1]，同一供应实例内同蛊判定恒定',()=>{
  const sup={supply:[{match:{rank:1},channel:'market',availability:.9,priceMultiplier:1}]};
  const scenario={supply_limited:{channelMultipliers:{market:{availability:.6,priceMultiplier:1.4}}}};
  const s=createSupply({supplyJson:sup,seed:1,scenario});
  const r=s.resolve({id:'z',rank:1});
  assert(r.availability>0&&r.availability<1,'availability 必须落在 [0,1]');
  assert(Math.abs(r.availability-.54)<1e-9,`场景乘数应作用于 availability（0.9×0.6=0.54），实际 ${r.availability}`);
  assert.deepEqual(s.resolve({id:'z',rank:1}),r,'同一供应实例内同蛊重复解析结果恒定（一局一次判定，不可刷）');
  assert.deepEqual(createSupply({supplyJson:sup,seed:5}).resolve({id:'z',rank:1}),createSupply({supplyJson:sup,seed:5}).resolve({id:'z',rank:1}),'同种子判定可复现');
  const s2=createSupply({supplyJson:sup,seed:1,scenario:{supply_limited:{channelMultipliers:{market:{availability:1.4}}}}});
  assert.equal(s2.resolve({id:'z',rank:1}).availability,1,'乘积截断到 1');
});
if(supplyData)check('supply.json 数据边界：availability∈[0,1]，渠道与场景键合法',()=>{
  const KNOWN=['market','drop','condition','production'];
  for(const [k,c] of Object.entries(supplyData.channels??{})){
    assert(KNOWN.includes(k),'未知渠道：'+k);
    assert(typeof c.availability==='number'&&c.availability>=0&&c.availability<=1,'渠道 availability 越界：'+k);
    assert(c.priceMultiplier===null||(typeof c.priceMultiplier==='number'&&c.priceMultiplier>0),'渠道价格倍率非法：'+k);
  }
  for(const [i,row] of (supplyData.supply??[]).entries()){
    assert(row.match&&typeof row.match==='object'&&Object.keys(row.match).length>0,`supply 行 ${i} 缺 match`);
    assert(typeof row.availability==='number'&&row.availability>=0&&row.availability<=1,`supply 行 ${i} availability 越界`);
    assert(row.channel===null||row.channel===undefined||KNOWN.includes(row.channel),`supply 行 ${i} 渠道非法`);
    assert(row.priceMultiplier===null||row.priceMultiplier===undefined||(typeof row.priceMultiplier==='number'&&row.priceMultiplier>0),`supply 行 ${i} 价格倍率非法`);
  }
  const sc=supplyData.scenarios??{};
  for(const m of Object.values(sc.supply_limited?.channelMultipliers??{})){
    const av=typeof m==='number'?m:m?.availability;
    assert(av==null||(typeof av==='number'&&av>=0&&av<=1),'场景 availability 乘数越界');
    const pm=typeof m==='object'?m?.priceMultiplier:null;
    assert(pm==null||(typeof pm==='number'&&pm>0),'场景价格乘数非法');
  }
  for(const g of sc.key_gu_missing?.dropGu??[])assert.equal(typeof g,'string');
  if(sc.refine_tail)assert.equal(sc.refine_tail.budgetMode,'p95','refine_tail 只允许 p95 记账口径');
});

// ---------- v0.2 载体矩阵、灾劫两口径、真实构筑×供应 ----------
const carrierMatrix=[];
for(let r=1;r<=9;r++)for(const enemy of carriers)for(const build of builds){
  const a=[];for(let i=0;i<P.validation.seeds;i++)a.push(fight({r,enemy,build,seed:P.validation.fixedSeed+i}));
  const base=matrix.find(x=>x.rank===r&&x.enemy==='pressure'&&x.build===build);
  const s=summary(a);
  carrierMatrix.push({rank:r,enemy,build,...s,pressureWinRate:base?base.winRate:null,winRateDelta:base?+(s.winRate-base.winRate).toFixed(4):null});
}
const caliberOf=runs=>{const failures={};for(const x of runs)if(!x.success){const k=`${x.r}转:${x.reason}`;failures[k]=(failures[k]??0)+1;}
  return {samples:runs.length,completion:mean(runs.map(x=>+x.success)),meanBattles:mean(runs.map(x=>x.totalBattles)),failures};};
const tribulationCalibers=[];
for(const build of builds){
  tribulationCalibers.push({build,caliber:'aggregate',...caliberOf(Array.from({length:campaignSeeds},(_,i)=>campaign({build,preparation:1,rewardMultiplier:1,seed:i})))});
  tribulationCalibers.push({build,caliber:'live-combat',...caliberOf(Array.from({length:campaignSeeds},(_,i)=>campaign({build,preparation:1,rewardMultiplier:1,tribulationCombat:true,seed:i})))});
}
let buildsSupply=null;
if(buildsArg!=null&&lib){
  buildsSupply={buildsFile:path.resolve(buildsArg),buildsFileHash,supplyFile,supplyFileHash,ran:true,auditIssues:auditBuilds(lib),rows:[],arms:[]};
  const arms=[{key:'baseline',scenario:null}];
  if(supplyData)for(const k of scenarioKeys){const sc=supplyData.scenarios?.[k];if(sc)arms.push({key:k,scenario:{[k]:sc}});}
  else buildsSupply.arms.push('未提供供应数据：场景臂与基准臂合并（全部可得、价格倍率 1）');
  buildsSupply.arms.push(...arms.map(a=>a.key));
  for(const id of Object.keys(lib.builds??{})){
    const covered=Object.keys(lib.builds[id]?.ranks??{}).map(Number).filter(x=>Number.isInteger(x)&&x>=1&&x<=9).sort((a,b)=>a-b);
    const missing=[1,2,3,4,5,6,7,8,9].filter(r=>!covered.includes(r));
    for(const arm of arms){
      const runs=Array.from({length:campaignSeeds},(_,i)=>campaign({build:id,preparation:1,rewardMultiplier:1,seed:i,lib,supplyJson:supplyData,scenario:arm.scenario}));
      const failures={};for(const x of runs)if(!x.success){const k=`${x.r}转:${x.reason}`;failures[k]=(failures[k]??0)+1;}
      buildsSupply.rows.push({build:id,scenario:arm.key,samples:runs.length,completion:mean(runs.map(x=>+x.success)),meanBattles:mean(runs.map(x=>x.totalBattles)),meanSupport:mean(runs.map(x=>x.ledger?.support??0)),meanRefine:mean(runs.map(x=>x.ledger?.refine??0)),ranksCovered:covered,missingRanks:missing,failures});
    }
  }
}
const runMs=Date.now()-t0;

const rankRows=P.ranks.map(x=>({rank:x.rank,essence:x.essence,scaleStart:scale(x.rank),scaleEnd:scale(x.rank,1),hpStart:100*scale(x.rank),strikeStart:24*scale(x.rank),marksStart:x.marksStart,marksEnd:x.marksEnd,refineSuccess:refinement(x.rank,{prepared:true}).success,refineExpectedFee:refinement(x.rank,{prepared:true}).expectedFee,tribulations:schedule(x.rank).length}));
const sourcePaths=['lore/wiki/world/cultivation-system.md','lore/wiki/world/primeval-essence.md','lore/wiki/world/aptitude-and-aperture.md','lore/wiki/world/gu-care-and-refinement.md','lore/wiki/rules/dao-marks.md','lore/wiki/rules/tribulation.md','lore/wiki/rules/venerables.md','lore/wiki/rules/refinement.md','lore/wiki/rules/path-realms.md','lore/wiki/rules/killer-moves.md','lore/wiki/gu/moonlight-gu.md','lore/wiki/events/royal-court.md','lore/wiki/world/economy-roster.md','game/docs/lore/canon-index.md'];
const root=path.resolve(dir,'../../..');
const report={modelVersion:P.version,parameterHash:hash(path.join(dir,'parameters.json')),modelHash:hash(path.join(dir,'model.mjs')),checks,rankRows,matrix,sensitivity,crossRank,boundaryCrossRank,economy,campaigns,representative,aptitudes,refinementRisk,sourceHashes:Object.fromEntries(sourcePaths.map(p=>[p,hash(path.join(root,p))])),carrierMatrix,tribulationCalibers,buildsSupply,cli:{builds:buildsArg,supply:supplyArg,scenarios:scenarioKeys,campaignSeeds},runNotes:{libNote,supplyNote,supplyFileUsed:supplyData?supplyFile:null},runMs};
fs.writeFileSync(path.join(dir,'results.json'),JSON.stringify(report,null,2)+'\n');
const pct=x=>(100*x).toFixed(1)+'%',num=x=>Number(x.toFixed(2)).toLocaleString('en-US');
let md=`# 一至九转模型：可复算验证报告\n\n日期：2026-09-27。由 [validate.mjs](validate.mjs) 生成；主说明见 [README](README.md)。仅验证此模型，不代表玩家体验或既有游戏验收。burst/balanced/sustain 是数值测试配置，不是已完成的流派蛊虫构筑；现有 69 蛊的构筑证据盘点见[库存关系](inventory-combinations.md)。\n\n参数 SHA-256：\`${report.parameterHash}\`。\n\n## 规则与边界\n\n${checks.map(s=>'- 通过：'+s).join('\n')}\n\n## 九转标尺\n\n所有生命/伤害/概率都是游戏设计值。生命是战斗耐受，不是原著肉身实测。\n\n|转数|仙元/真元|初始耐受|标准攻击|道痕起点→终点|准备后炼制率|完整周期灾劫事件|\n|---|---|---:|---:|---|---:|---:|\n`;
md+=rankRows.map(x=>`|${x.rank}|${x.essence}|${num(x.hpStart)}|${num(x.strikeStart)}|${x.marksStart}→${x.marksEnd}|${pct(x.refineSuccess)}|${x.tribulations}|`).join('\n');
md+='\n\n六至八转的事件为完整账本，重合时间同时记入；九转的 0 表示未编造周期，不表示无灾劫。\n\n## 战斗矩阵\n\n每行100个种子；同转初始道痕、满状态；策略为固定脚本，无配方抽取、玩家学习或实战操作。\n\n|转|敌人|构筑|胜率|平均回合|剩余耐受|\n|---|---|---|---:|---:|---:|\n';
md+=matrix.map(x=>`|${x.rank}|${x.enemy}|${x.build}|${pct(x.winRate)}|${num(x.turns)}|${pct(x.remainingHp)}|`).join('\n');
md+='\n\n## 越转基准（低转爆发，对高一转持续压力）\n\n|转数|胜率|平均回合|\n|---|---:|---:|\n'+crossRank.map(x=>`|${x.from}→${x.to}|${pct(x.winRate)}|${num(x.turns)}|`).join('\n');
md+='\n\n## 敏感性\n\n每行1350次战斗，包含九转、五类敌人、30个种子。\n\n|扰动对象|倍率|构筑|胜率|剩余耐受|\n|---|---:|---|---:|---:|\n'+sensitivity.map(x=>`|${x.key}|${x.factor}|${x.build}|${pct(x.winRate)}|${pct(x.remainingHp)}|`).join('\n');
md+='\n\n## 低转末期对高一转初期\n\n与初入转数对比不同，此表保留前一转积累；没有自动越阶禁伤。\n\n|转数|胜率|平均回合|\n|---|---:|---:|\n'+boundaryCrossRank.map(x=>`|${x.from}→${x.to}|${pct(x.winRate)}|${num(x.turns)}|`).join('\n');
md+='\n\n## 炼蛊尾部预算\n\n每转10000个随机样本；单位为该转货币。投入蛊重置成本另计，不包含在费用列。经验分位受有限样本影响，正式预算使用理论分位；例如九转五次失败尾概率5.0328%，须准备六次才达到理论95%覆盖。\n\n|转|准备后概率|平均尝试次数|样本95%次数|样本95%费用|理论95%次数|\n|---|---:|---:|---:|---:|---:|\n'+refinementRisk.map(x=>`|${x.rank}|${pct(x.probability)}|${num(x.meanAttempts)}|${x.p95Attempts}|${num(x.p95Fee)}|${x.theoreticalP95}|`).join('\n');
md+='\n\n## 126场完整账本压力测试\n\n一至五转每转4期、六至八转每转6期、九转4期；每期3场。炼蛊按期望费用计账，晋阶/境界/知识资格由测试情景提供，因此不是完整游戏通关率。灾劫用聚合结算代理，不是逐场战斗。\n\n|构筑|筹备|收入倍率|完成率|失败位置与原因|\n|---|---:|---:|---:|---|\n'+campaigns.map(x=>`|${x.build}|${x.preparation}|${x.rewardMultiplier}|${pct(x.completion)}|${JSON.stringify(x.failures)}|`).join('\n');
md+=`\n\n基准路线：${representative.totalBattles}场、${representative.practiceActions}次修炼行动、终局${representative.marks}道痕、余${num(representative.wallet)}仙元石、封存${num(representative.archiveMortalWallet)}元石（不兑换）。这条可行路线只证明模型无必然资源死锁。\n\n## 已知验证限制\n\n- 高阶同转战斗沿用相同战术模板；相同胜率是尺度归一化的结果，不是九个阶段内容都已平衡。\n- 所有脚本都可购买完全恢复，尚未测试稀缺商店、随机掉落、关键蛊缺失、社会风险及玩家决策。\n- 炼蛊使用几何分布期望费用，不把均值冒充尾部风险；尾部预算见模型正文。\n- 升仙气量、人气折算与成尊研究门槛属设计假设。独立 L1 审查和实玩尚未完成。\n- 原文未确证或本 Wiki 未收录的九转周期及成尊第四条件保持未知。\n\n完整矩阵、账本、来源哈希见 [results.json](results.json)。\n`;

// ---------- v0.2 报告小节（载体矩阵、灾劫两口径、真实构筑×供应） ----------
let mdV02=`## 载体战斗矩阵（v0.2）\n\nsoulBody/guHouse/beastPack 为特殊防御载体模板，数值全部是纯游戏设计假设，概念锚点只取自 lore/wiki（魂道：常规手段难伤；KM-006：蛊屋高耐受低机动；兽潮：多单位聚合逐波衰减），不声称原著数值。每行 ${P.validation.seeds} 个种子，与上方战斗矩阵同种子（fixedSeed=${P.validation.fixedSeed}）。胜率差 = 载体胜率 − 同转同构筑 pressure 模板胜率；机制断言（魂体减伤、蛊屋低攻、兽群衰减与范围收益）见「规则与边界」。\n\n|转|载体|构筑|胜率|平均回合|剩余耐受|对pressure胜率差|\n|---|---|---|---:|---:|---:|---:|\n`;
mdV02+=carrierMatrix.map(x=>`|${x.rank}|${x.enemy}|${x.build}|${pct(x.winRate)}|${num(x.turns)}|${pct(x.remainingHp)}|${x.winRateDelta==null?'—':(x.winRateDelta>=0?'+':'')+(100*x.winRateDelta).toFixed(1)+'pp'}|`).join('\n');
mdV02+=`\n\n## 灾劫两口径对照（v0.2）\n\n同一账本接口（alive/injury/ecology/marks/power/margin）下的两种结算：聚合代理（resolveTribulation，v0.1 口径）与实战口径（tribulationFight：敌人=载体模板×tribulationPower 威能倍率）。实战口径 margin=剩余耐受/${P.carriers.tribulationMarginRef} 仅用于与代理口径同轴对比，不再作为生死门槛；存活后道痕记法与生态修复费公式与代理口径完全相同。preparation=1、rewardMultiplier=1、每行 ${campaignSeeds} 个种子；实战口径未接蛊库（§4.1 占位动作口径），升仙与成尊仍是聚合代理。\n\n|构筑|口径|完成率|平均场次|失败位置与原因|\n|---|---|---:|---:|---|\n`;
mdV02+=tribulationCalibers.map(x=>`|${x.build}|${x.caliber==='aggregate'?'聚合代理':'实战载体'}|${pct(x.completion)}|${num(x.meanBattles)}|${JSON.stringify(x.failures)}|`).join('\n');
if(buildsSupply){
  mdV02+=`\n\n## 数值测试配置×供应（v0.2，--builds）\n\n测试配置库：\`${buildsSupply.buildsFile}\`（SHA-256 \`${buildsSupply.buildsFileHash??'—'}\`）；供应：\`${buildsSupply.supplyFile}\`${buildsSupply.supplyFileHash?`（SHA-256 \`${buildsSupply.supplyFileHash}\`）`:'（未提供，按全可得基线）'}。场景臂：${buildsSupply.arms.filter(a=>a!=='baseline'&&a.startsWith('未提供')===false).join('、')||'无'}；每行 ${campaignSeeds} 个种子；preparation=1、rewardMultiplier=1；灾劫用聚合代理口径。槽位静态审计问题 ${buildsSupply.auditIssues.length} 条${buildsSupply.auditIssues.length?'（明细见 results.json 的 buildsSupply.auditIssues）':'（防套利口径全部通过）'}。供养合计与炼制费为全程账本累计（一至五转元石、六至九转仙元石混计，仅作同表量级对照，不跨币相加解读）；complete 与失败分布见下表，缺失转数指该配置未声明槽位的阶段（引擎退回基础动作、供养按 0 计）。\n\n|测试配置|场景|样本|完成率|平均场次|供养合计均值|炼制费合计均值|缺档转数|失败位置与原因|\n|---|---|---:|---:|---:|---:|---:|---|---|\n`;
  mdV02+=buildsSupply.rows.map(x=>`|${x.build}|${x.scenario}|${x.samples}|${pct(x.completion)}|${num(x.meanBattles)}|${num(x.meanSupport)}|${num(x.meanRefine)}|${x.missingRanks.length?x.missingRanks.join('/'):'—'}|${JSON.stringify(x.failures)}|`).join('\n');
}
const cutIdx=md.indexOf('## 已知验证限制');
md=md.slice(0,cutIdx)+mdV02+'\n\n'+md.slice(cutIdx);
const v02Limits=[
  '载体模板（soulBody/guHouse/beastPack）与灾劫实战化数值全部是纯游戏设计假设；概念锚点只取自 lore/wiki，不声称原著数值（登记见 [engine-v02](engine-v02.md)）。',
  '升仙、八转后研究与成尊条件仍是聚合代理；实战口径只替换六至八转灾劫结算，替换后完成率显著下降是如实记录的漂移，不为变绿调参。',
  '高阶同转沿用同一战术模板，载体矩阵跨转的相似结果是尺度归一化的产物，不是独立的高阶内容证据。',
  '场景 priceMultiplier（如 supply_limited 的 market ×1.4 稀缺溢价）未进入引擎记账：v0.2 引擎无购置扣费，供养按行内价格倍率计；渠道稀缺表现为当期不可得→构筑 fallback/占位，未实现「等待期数」报告。',
  buildsSupply?'「数值测试配置×供应」节来自命令行指定的蛊库，检验旧动作槽与供应回落；不构成完整流派蛊虫构筑或玩家体验的证据。':`未运行「数值测试配置×供应」节：未给 --builds${libNote?'（'+libNote+'）':''}；需以 --builds 接入研究蛊库，默认运行不依赖该文件。`,
  supplyData?`供应数据取自 ${supplyFile}；未命中任何 supply 行的蛊落到 market 默认（可得、价格倍率 1）。`:'本轮未加载供应数据文件：供应数据边界检查跳过，场景臂按全可得基线运行。',
  'model.mjs 存在四处登记在案的修复级改动（供应乘数形态、通配匹配、审计覆盖、兽群系数键域，见 [engine-v02](engine-v02.md) §4）；模型哈希因此与 v0.1 报告不同，beastPack 相关行数字随之漂移。',
];
md+=`\n### v0.2 追加限制\n\n${v02Limits.map(s=>'- '+s).join('\n')}\n`;
fs.writeFileSync(path.join(dir,'validation.md'),md);
console.log(JSON.stringify({checks:checks.length,combatSamples:matrix.reduce((a,x)=>a+x.samples,0),sensitivitySamples:sensitivity.reduce((a,x)=>a+x.samples,0),campaignSamples:campaigns.reduce((a,x)=>a+x.samples,0),refinementSamples:90000,representative:{success:representative.success,battles:representative.totalBattles,marks:representative.marks},campaignBaselines:campaigns.filter(x=>x.preparation===1&&x.rewardMultiplier===1),carrierSamples:carrierMatrix.reduce((a,x)=>a+x.samples,0),tribulationSamples:tribulationCalibers.reduce((a,x)=>a+x.samples,0),buildsSupply:buildsSupply?{ran:true,auditIssues:buildsSupply.auditIssues.length,rows:buildsSupply.rows.length}:null,supplyFileUsed:supplyData?supplyFile:null,runMs},null,2));
