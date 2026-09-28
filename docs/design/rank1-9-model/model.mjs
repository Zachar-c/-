import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
export const dir = path.dirname(fileURLToPath(import.meta.url));
export const P = JSON.parse(fs.readFileSync(path.join(dir, 'parameters.json'), 'utf8'));
export const clamp = (x, lo, hi) => Math.max(lo, Math.min(hi, x));
export const rank = r => { if (!Number.isInteger(r) || r < 1 || r > 9) throw new RangeError('rank 1..9'); return P.ranks[r-1]; };
export function rng(seed) { let s=seed>>>0; s=Math.imul(s^(s>>>16),0x45d9f3b);s=Math.imul(s^(s>>>16),0x45d9f3b);s=(s^(s>>>16))>>>0;return ()=> { s=(Math.imul(s,1664525)+1013904223)>>>0; return s/4294967296; }; }
export function markFactor(marks) { if(marks<0) throw new RangeError('negative marks'); return 1+marks/P.combat.markUnit; }
export function scale(r, progress=0) {
  const x=rank(r); progress=clamp(progress,0,1);
  return x.base*(r<6 ? 1+0.3*progress : markFactor(x.marksStart+(x.marksEnd-x.marksStart)*progress));
}
export function pathFactor(own, foreign) { return Math.max(P.combat.conflictFloor, 1/(1+P.combat.conflictCoefficient*foreign/(own+1000))); }
export function essenceCost(caster, gu, action='strike') {
  rank(caster); rank(gu); if(gu>caster) throw new Error('越阶催动需要专门规则，本模型常规路径拒绝');
  const a=P.actions[action]; if(!a) throw new Error('unknown action');
  if(caster>=6 && gu<6) return {pool:'mortal',cost:a.mortalCost*rank(gu).essenceQuality/rank(5).essenceQuality};
  if(caster<6) return {pool:'mortal',cost:a.mortalCost*rank(gu).essenceQuality/rank(caster).essenceQuality};
  return {pool:'immortal',cost:a.immortalCost*rank(gu).essenceQuality/rank(caster).essenceQuality};
}
export function damageWithGu(caster, gu, marks=0, coefficient=24) {
  if(gu>caster) throw new Error('unsupported over-rank gu');
  // No caster-rank multiplier: low-rank Gu never inherits high-rank core output.
  return coefficient*rank(gu).base*(caster>=6 ? markFactor(marks) : 1);
}
export function schedule(r,years=rank(r).internalYears??0) {
  const x=rank(r); if(!x.tribulations) return [];
  const out=[];
  for(let y=1;y<=years;y++) for(const [kind,t] of Object.entries(x.tribulations))
    if(y%t.every===0) out.push({year:y,kind,marks:t.marks});
  return out;
}
export function tribulationPower(kind, ordinal, count) {
  const [a,b]=P.growth.tribulationBands[kind]; return a+(b-a)*clamp((ordinal-1)/Math.max(1,count-1),0,1);
}
export function aperture({externalYears,speed,ecology=1,adaptation=1,dead=false,r=6}) {
  if(externalYears<0||speed<0) throw new RangeError('time must be nonnegative');
  const internalYears=externalYears*speed;
  const periods=internalYears/50;
  const productive=dead?0:clamp(ecology,0,1)*clamp(adaptation,0,1);
  return {internalYears,essence:periods*P.economy.immortalProductionPerPeriod*productive,
    resources:periods*P.economy.resourceYield*rank(r).priceUnit*productive,
    events:dead?[]:schedule(r,Math.floor(internalYears)),tribulationPeriodKnown:r>=6&&r<=8};
}
export function refinement(r,{attainment=0,prepared=false,complexity=0,uniqueExists=false}={}) {
  rank(r); if(r>=6&&uniqueExists) return {possible:false,success:0,reason:'同种仙蛊已存在'};
  const success=clamp(P.refinement.baseSuccess[r-1]+P.refinement.attainmentBonus*attainment+(prepared?P.refinement.preparationBonus:0)-0.05*complexity,P.refinement.minSuccess,P.refinement.maxSuccess);
  const fee=P.economy.refinementFee*rank(r).priceUnit;
  return {possible:true,success,fee,expectedAttempts:1/success,expectedFee:fee/success};
}
export function ascend({humanQi,steps,prepared=0.5,guard=0.5}) {
  const c=P.growth.ascension; let heaven=0,earth=0,hp=100,irreversible=false;
  if(!Number.isFinite(humanQi)||humanQi<0||steps.some(s=>!Number.isFinite(s.heaven)||!Number.isFinite(s.earth)||s.heaven<0||s.earth<0)) throw new RangeError('invalid qi');
  if(humanQi<c.minimumHumanQi) return {success:false,irreversible,reason:'碎窍前准备不足',hp};
  irreversible=true;
  for(const s of steps){ heaven+=s.heaven; earth+=s.earth;
    if(Math.abs(heaven-earth)>c.imbalanceLimit+1e-9 || Math.max(heaven,earth)>humanQi+c.imbalanceLimit+1e-9 || Math.max(heaven,earth)>c.heavenEarthMax)
      return {success:false,irreversible,reason:'三气失衡',hp:0};
    hp-=c.backlash*Math.max(0,1-clamp(prepared,0,1)*0.6-clamp(guard,0,1)*0.4);
  }
  const success=steps.length===c.steps && hp>0 && Math.min(heaven,earth)>=c.minimumHumanQi;
  return {success,irreversible,hp,heaven,earth,apertureGrade:success?Math.min(3,Math.floor(Math.min(heaven,earth)*3)):0};
}
export function canPromote(r,s={}) {
  rank(r);
  if(r<5) return (s.stage===3 && s.practice>=rank(r).practiceNeed && s.reserve>=P.growth.breakthroughReserve[r] && s.access===true);
  if(r===5) return s.ascensionSuccess===true;
  if(r===6||r===7) return s.internalYears>=300 && s.allTribulationsResolved===true && s.alive===true;
  if(r===8) return s.allTribulationsResolved===true && s.internalYears>=300 && s.marks>=P.growth.venerableMarksThreshold && s.attainment==='无上大宗师' && s.research>=P.growth.venerableResearch && s.heavenSealBroken===true && s.alive===true;
  return false;
}
// v0.2 特殊战斗载体。载体数值是纯游戏假设（设计值），概念锚点仅取自 lore/wiki：
// 魂道（魂魄由虚返实、常规手段难伤）、杀招体系 KM-006（蛊屋本质是固定化杀招、高耐受低机动）、
// 兽潮（多低耐久单位聚合、逐波衰减）。不声称任何原著数值。
export function carrierOf(enemyKey) { const e=P.enemies[enemyKey]; return e?.carrier??'regular'; }
export function damageClass(action) { return P.carriers?.damageClasses?.[action]??'regular'; }
export function marksAt(r,progress=0) { const x=rank(r); return x.marksStart+(x.marksEnd-x.marksStart)*clamp(progress,0,1); }

export function fight({r=1,enemy='pressure',build='balanced',aptitude=0.44,progress=0,seed=1,hpFraction=1,energyFraction=1,enemyRank=r,enemyProgress=progress,enemyMultiplier=1,actionMultiplier=1,guActions=null,marks=null,trace=false}={}) {
  const random=rng(seed), s=scale(r,progress), es=scale(enemyRank,enemyProgress), e=P.enemies[enemy];
  if(!e) throw new Error('enemy');
  let hp=P.combat.baseHp*s*hpFraction, ehp=e.hp*es*(1+(random()*2-1)*P.combat.enemyHpVariance);
  const ehp0=ehp;
  const enemyDamageFactor=1+(random()*2-1)*P.combat.enemyDamageVariance;
  const cap=r<6?100*aptitude:P.combat.immortalStock;
  let energy=cap*energyFraction; const cd={},log=[]; let turn=0,spent=0,restored=0;
  const carrier=e.carrier??'regular';
  const packUnits=e.packUnits??P.carriers.packUnits;
  const effMarks=marks??marksAt(r,progress);
  // 构筑模式：guActions[k]={guRank:number|null}。guRank=null 表示 gu:null 占位（沿用 §4.1 占位数值与通用费用）；
  // 无条目=该动作本阶段不可用（basic/guard 为宿主基础手段，始终可用）。resolveStage 产出的 guActions
  // 已为全部动作补全条目（未赋能动作回落占位，登记于 engine-v02.md §8）；仅手工构造部分 guActions 时
  // 才会触发"无条目=不可用"的严格路径。
  const slotOf=k=>guActions?(guActions[k]??null):null;
  const costOf=(k,a)=>{const g=slotOf(k);return g&&g.guRank!=null?essenceCost(r,g.guRank,k).cost:(r<6?a.mortalCost:a.immortalCost);};
  // v0.2 修订（主会话，登记于 engine-v02.md §8、model.md §2.3 增补）：凡人段蛊赋能动作乘同一小境界进度
  // 系数(1+0.3q)。g=r 时精确回到同阶预算 c×S，g<r 仍不继承宿主转数基数（跨转禁令不变）；否则同阶蛊在
  // 阶段后半段恒低于它所替换的占位动作 30%，消耗战系统性失真。仙人段 markFactor 本就同用，无需改动。
  const multOf=k=>{const g=slotOf(k);return g&&g.guRank!=null?rank(g.guRank).base*(r>=6?markFactor(effMarks):1+0.3*clamp(progress,0,1)):s;};
  const canUse=k=>(k==='basic'||k==='guard')||!guActions||slotOf(k)!=null;
  for(turn=1;turn<=P.combat.maxTurns && hp>0 && ehp>0;turn++){
    for(const k of Object.keys(cd)) cd[k]=Math.max(0,cd[k]-1);
    let ap=P.combat.actionsPerTurn,block=0,usedGuard=false;
    // 兽群载体：单回合输出按剩余单位数线性衰减，不低于 packDamageFloor（纯游戏聚合假设）。
    let packScale=1;
    if(carrier==='beastPack'){const unitHp=ehp0/packUnits;packScale=Math.max(P.carriers.packDamageFloor,clamp(ehp/unitHp,0,packUnits)/packUnits);}
    const incoming=(e.windupEvery && turn%e.windupEvery!==0)?0:e.damage*es*enemyMultiplier*enemyDamageFactor*(carrier==='beastPack'?packScale:1);
    while(ap>0 && ehp>0){
      let choices=build==='burst'?['burst','strike','basic']:build==='sustain'?['drain','guard','strike','basic']:['guard','strike','basic'];
      if(incoming===0||usedGuard) choices=choices.filter(k=>k!=='guard');
      choices=choices.filter(canUse);
      const k=choices.find(k=>P.actions[k].ap<=ap && !(cd[k]>0) && costOf(k,P.actions[k])<=energy+1e-9);
      if(!k)break;
      const a=P.actions[k],cost=costOf(k,a); energy-=cost;spent+=cost;ap-=a.ap;cd[k]=a.cooldown;
      if(k==='guard')usedGuard=true;
      let dealt=a.damage*multOf(k)*(1-e.armor)*actionMultiplier*(1+(random()*2-1)*P.combat.damageVariance);
      const cls=damageClass(k);
      if(carrier==='soulBody')dealt*=1-(P.carriers.soulBodyResist[cls]??0); // 魂体：常规类减免，爆发类全额
      // 兽群：范围收益按动作名取系数（parameters.packAoeYield 以动作名 basic/strike/burst/drain 为键）。
      // v0.2 修复（登记于 engine-v02.md #4）：修复前按伤害类别取键，strike/basic/drain 的系数永不命中，
      // 仅 burst 因类别同名偶然生效，兽群「范围收益」群体特征半失效。
      if(carrier==='beastPack')dealt*=P.carriers.packAoeYield[k]??P.carriers.packAoeYield[cls]??1;
      ehp-=dealt;block+=a.block*multOf(k);
      const restore=r<6?(a.restoreMortal??0):(a.restoreImmortal??0);
      const actual=Math.min(cap-energy,restore);energy+=actual;restored+=actual;
      if(trace)log.push({turn,action:k,damage:dealt,energy,enemyHp:Math.max(0,ehp),incoming});
    }
    if(ehp>0){hp-=Math.max(0,incoming*(1+(random()*2-1)*P.combat.damageVariance)-block);
      if(e.energyLoss)energy=Math.max(0,energy-e.energyLoss*(r<6?1:0.1));}
  }
  return {win:ehp<=0&&hp>0,turns:turn-1,hpFraction:Math.max(0,hp/(P.combat.baseHp*s)),energyFraction:Math.max(0,energy/cap),spent,restored,log};
}
export function expedition({r=1,build='balanced',seed=1,aptitude=.44,rewardMultiplier=1,progress=0,startingWallet=P.economy.startingWallet*rank(r).priceUnit,guActions=null,supportUnits=null}={}) {
  const u=rank(r).priceUnit,c=P.economy;
  // v0.2：supportUnits 给出时按构筑槽位逐只计供养（可带每只价格倍率，可为小数），替换固定 guCount=5。
  const feed=supportUnits??c.guCount;
  let hp=1,energy=1,wallet=startingWallet,period=0;const entries=[];
  for(const enemy of ['skirmisher','pressure','armored']){
    const f=fight({r,build,seed:seed+period,aptitude,progress,hpFraction:hp,energyFraction:energy,guActions,marks:guActions?marksAt(r,progress):undefined});period++;
    hp=f.hpFraction;energy=f.energyFraction;if(!f.win)return {success:false,wallet,entries,reason:'战败',supportCost:entries.reduce((a,x)=>a+x.supportCost,0)};
    const gross=c.grossPerPeriod*u*rewardMultiplier;
    const supportCost=c.foodPerGu*feed*u;
    const maintenance=supportCost+(c.fieldCost+(r>=6?c.apertureMaintenance:0))*u;
    wallet+=gross-maintenance;
    // Rest spends finite campaign time; it is not a free extra node.
    if(r<6) energy=Math.min(1,energy+0.09*c.naturalRecoveryHours);
    else energy=Math.min(1,energy+c.immortalProductionPerPeriod/(3*P.combat.immortalStock));
    const cap=r<6?100*aptitude:P.combat.immortalStock;
    const refillCost=(1-energy)*cap*(r<6?c.mortalRefillPerPoint:c.immortalRefillPerUnit)*u;
    const healCost=(1-hp)*c.recoverFullHp*u;
    const cost=refillCost+healCost;
    if(wallet<cost)return {success:false,wallet,entries,reason:'补给破产',supportCost:entries.reduce((a,x)=>a+x.supportCost,0)};
    wallet-=cost;hp=1;energy=1;entries.push({enemy,gross,maintenance,supportCost,refillCost,healCost,wallet});
  }
  const canRefine=wallet>=c.refinementFee*u;
  return {success:true,wallet,entries,canRefine,supportCost:entries.reduce((a,x)=>a+x.supportCost,0)};
}
export function recipeOffer(knownIds,allIds,seed,count=P.meta.offerCount) {
  const pool=[...new Set(allIds)].filter(id=>!knownIds.includes(id)),random=rng(seed);
  for(let i=pool.length-1;i>0;i--){const j=Math.floor(random()*(i+1));[pool[i],pool[j]]=[pool[j],pool[i]];}
  return pool.slice(0,count);
}
export function reincarnate(state) { return {knownRecipes:[...new Set(state.knownRecipes??[])],rank:1,money:0,gu:[],attainment:0}; }

export function resolveTribulation({r,kind,ordinal,count,preparation=1,marks,ecology=1}) {
  const power=tribulationPower(kind,ordinal,count);
  // Encounter changes with class; this scalar is a settlement surrogate, not a combat win rate.
  const capability=1+2.6*clamp(preparation,0,1);
  const margin=capability/power;
  const injury=clamp(P.growth.tribulationDamageFraction/Math.max(.1,margin),0,1);
  const alive=margin>=0.75;
  return {alive,injury,ecology:Math.max(0,ecology-injury*.2),marks:alive?marks+rank(r).tribulations[kind].marks:marks,power,margin};
}

// ---- v0.2 灾劫实战化（纯游戏假设，账本接口与聚合代理一致） ----
// 载体选型：地灾→beastPack（成灾基数大、逐波削弱）、天劫→soulBody（天罚直指魂魄、常规手段减免、
// 需爆发窗口）、浩劫/万劫→guHouse（仙窍级攻城战：高耐受高减伤低机动的阵地战）。
// 单敌引擎内不构造多载体同场组合；逐级增强用 tribulationPower 威能倍率表达。
export function tribulationFight({r,kind,ordinal,count,build='balanced',seed=1,aptitude=.44,progress=0,marks=null,ecology=1,hpFraction=1,energyFraction=1,carrierOverride=null,guActions=null}={}) {
  rank(r);
  if(!P.growth.tribulationBands[kind]) throw new Error('unknown tribulation kind');
  if(!rank(r).tribulations||!rank(r).tribulations[kind]) throw new Error('该转数无此灾劫条目');
  const power=tribulationPower(kind,ordinal,count);
  const carrier=carrierOverride??P.carriers.tribulationCarrier[kind];
  if(!P.enemies[carrier]||!P.enemies[carrier].carrier) throw new Error('carrier template missing');
  const m=marks??marksAt(r,progress);
  const f=fight({r,enemy:carrier,build,seed,aptitude,progress,enemyMultiplier:power,hpFraction,energyFraction,guActions,marks:m});
  // 实战口径：alive=战斗胜利（含30回合超时未胜）；margin=剩余耐受/安全存活参考线(0.75)，仅用于与代理口径同轴对比，
  // 不再作为生死门槛；injury=玩家耐受损失比例；ecology 与修复费公式与代理口径完全一致。
  const margin=f.hpFraction/P.carriers.tribulationMarginRef;
  return {alive:f.win,injury:clamp(1-f.hpFraction,0,1),ecology:Math.max(0,ecology-clamp(1-f.hpFraction,0,1)*.2),
    marks:f.win?m+rank(r).tribulations[kind].marks:m,power,margin};
}

// ---- v0.2 供应层消费端（schema 由并行车道产出，此处只实现读取与判定） ----
export function hashString(str) { let h=2166136261>>>0; for(let i=0;i<str.length;i++){h^=str.charCodeAt(i);h=Math.imul(h,16777619)>>>0;} return h>>>0; }

// 供应解析器：supply 行 first-match-wins，gu 精确匹配行优先（各自保持文件内相对顺序）；
// availability 按种子对每只蛊一次性判定（整局属性， memo 化后不可反复刷）；key_gu_missing 强制整局不可得；
// supply_limited.channelMultipliers 乘到对应渠道行的 availability 上。无匹配行时默认可得、价格倍率 1。
export function createSupply({supplyJson=null,seed=1,scenario=null}={}) {
  const lines=[...(supplyJson?.supply??[])];
  const guLines=lines.filter(l=>l.match&&l.match.gu!=null),rest=lines.filter(l=>!(l.match&&l.match.gu!=null));
  const ordered=[...guLines,...rest];
  const drop=new Set(scenario?.key_gu_missing?.dropGu??[]);
  const channelMult=scenario?.supply_limited?.channelMultipliers??{};
  const cache=new Map();
  // v0.2 修复（登记于 engine-v02.md #2）：supply.json 以 path:"*"/rarity:"*" 表达泛匹配（supply-model.md §1
  // 「未给出的匹配字段视为通配」），原实现按字面值比较使 rank 泛匹配行与 unique/wild 行全部死行。
  const isWild=v=>v==='*';
  const matchLine=(m,gu)=>{
    if(!m) return false;
    if(m.gu!=null&&!isWild(m.gu)&&gu.id!==m.gu) return false;
    if(m.rank!=null&&gu.rank!==m.rank) return false;
    if(m.path!=null&&!isWild(m.path)&&gu.path!==m.path) return false;
    if(m.rarity!=null&&!isWild(m.rarity)&&gu.rarity!==m.rarity) return false;
    return true;
  };
  function resolve(gu) {
    if(cache.has(gu.id)) return cache.get(gu.id);
    let line=null;
    for(const l of ordered){ if(matchLine(l.match,gu)){line=l;break;} }
    let availability=line?.availability??1;
    const channel=line?.channel??null;
    // v0.2 修复（登记于 engine-v02.md #1）：场景乘数值是 {availability,priceMultiplier} 对象（supply.json 契约），
    // 原实现当标量相乘得 NaN→clamp(NaN)=NaN，使 supply_limited 下所有命中行蛊全部不可得。此处兼容对象与标量。
    if(channel&&channelMult[channel]!=null){
      const cm=channelMult[channel];
      const mult=typeof cm==='number'?cm:(cm&&typeof cm==='object'?cm.availability:null);
      if(mult!=null)availability=clamp(availability*mult,0,1);
    }
    let available=availability>0&&!drop.has(gu.id);
    if(available&&availability<1) available=rng((hashString(gu.id)^Math.imul(seed,0x9E3779B1))>>>0)()<availability;
    const out={available,availability,priceMultiplier:line?.priceMultiplier??1,channel,matched:!!line,forcedMissing:drop.has(gu.id)};
    cache.set(gu.id,out); return out;
  }
  return {resolve,lines:ordered,dropGu:[...drop],channelMult};
}

// 构筑槽位解析：主蛊不可得（供应/越阶/未知）时按 fallbacks 顺序取第一只可得蛊或 gu:null 占位；
// 同一动作多个槽位时取数值最强（同系数下即 gu 转数最高）；gu:null 占位不覆盖任何已赋能动作。
// 返回 supportUnits 为本阶段实际携带蛊的供养单位合计（逐只×价格倍率，按 gu id 去重——一只蛊一份供养）。
export function resolveStage({lib,buildId,r,supply=null}={}) {
  const stage=lib?.builds?.[buildId]?.ranks?.[String(r)];
  const guIndex=new Map((lib?.gu??[]).map(g=>[g.id,g]));
  const guActions={},carried=new Map();
  for(const slot of stage?.slots??[]){
    const prim=guIndex.get(slot.gu);
    let chosen=null,source=null;
    if(prim&&prim.rank<=r&&(!supply||supply.resolve(prim).available)){chosen=prim;source='primary';}
    else for(const fb of slot.fallbacks??[]){
      if(fb.gu==null){chosen={id:null,rank:null,poweredAction:fb.poweredAction??slot.poweredAction};source='placeholder';break;}
      const fbg=guIndex.get(fb.gu);
      if(fbg&&fbg.rank<=r&&(!supply||supply.resolve(fbg).available)){chosen={...fbg,poweredAction:fb.poweredAction??slot.poweredAction};source='fallback';break;}
    }
    if(!chosen) continue; // 无蛊可用且无占位：该动作本阶段不可用
    const action=chosen.poweredAction;
    if(!P.actions[action]) continue;
    const prev=guActions[action];
    if(chosen.rank!=null&&(!prev||prev.guRank==null||chosen.rank>prev.guRank)) guActions[action]={guRank:chosen.rank,source};
    if(chosen.rank!=null&&!carried.has(chosen.id)) carried.set(chosen.id,{gu:chosen.id,priceMultiplier:supply?supply.resolve(chosen).priceMultiplier:1});
  }
  const supportSlots=[...carried.values()];
  // 集成收口（主会话裁决，登记于 engine-v02.md §8）：未赋能动作回落 §4.1 占位口径，而不是从动作菜单
  // 移除。构筑是占位工具组的增量替换：有来源的蛊逐动作按 g 赋能输出，缺内容的动作保留宿主基础手段；
  // 内容缺口应体现在账本（供养/炼制/供应）与高转输出缺口上，不应让策略脚本本身失效。
  for(const k of Object.keys(P.actions)) if(!guActions[k]) guActions[k]={guRank:null,source:'placeholder'};
  return {guActions,supportSlots,supportUnits:supportSlots.reduce((a,s)=>a+s.priceMultiplier,0)};
}

// 终审辅助：静态审计构筑数据。fallback 不得强于本体（同动作域内 系数×蛊转数 比较）；越阶槽位、
// 未知蛊、未知 fallback 一律登记为 issue，由验证器呈现，不静默修正。
export function auditBuilds(lib) {
  const issues=[];
  const guIndex=new Map((lib?.gu??[]).map(g=>[g.id,g]));
  const strength=(action,gRank)=>(P.actions[action]?.damage??0)*rank(clamp(gRank,1,9)).base;
  for(const [buildId,b] of Object.entries(lib?.builds??{}))
    for(const [rStage,stage] of Object.entries(b?.ranks??{})){
      const r=Number(rStage);
      // v0.2 补充审计（登记于 engine-v02.md #3）：槽位组合复杂度超心智容量（§4.3 L=n(n−1)/2；容量=基础
      // 心智容量+2×构筑声明境界，未声明按 0 的静态保守口径）与槽位缺 fallback（主蛊不可得时无降级路径）。
      const slotCount=stage?.slots?.length??0;
      if(Number.isInteger(r)&&r>=1&&r<=9){
        const capacity=(P.combat.thoughtCapacity[r-1]??0)+2*(stage?.attainment??0);
        const complexity=slotCount*(slotCount-1)/2;
        if(complexity>capacity)issues.push({buildId,r,type:'capacity-exceeded',complexity,capacity});
      }
      for(const slot of stage?.slots??[]){
        if(slot.gu==null){
          // 明示的匿名动作预算；不代表存在一只可获取的原著蛊。
          if(!P.actions[slot.poweredAction])issues.push({buildId,r,slot:null,type:'unknown-action',action:slot.poweredAction});
          continue;
        }
        const prim=guIndex.get(slot.gu);
        if(!prim){issues.push({buildId,r,slot:slot.gu,type:'unknown-gu'});continue;}
        if(!Array.isArray(slot.fallbacks)||slot.fallbacks.length===0)issues.push({buildId,r,slot:slot.gu,type:'no-fallback'});
        if(prim.rank>r)issues.push({buildId,r,slot:slot.gu,type:'over-rank-slot',guRank:prim.rank,stageRank:r});
        if(!P.actions[slot.poweredAction])issues.push({buildId,r,slot:slot.gu,type:'unknown-action',action:slot.poweredAction});
        for(const fb of slot.fallbacks??[]){
          if(fb.gu==null) continue; // gu:null 占位的强弱依赖局内尺度，静态不可比，由防套利口径单独说明
          const fbg=guIndex.get(fb.gu);
          if(!fbg){issues.push({buildId,r,slot:slot.gu,fallback:fb.gu,type:'unknown-fallback'});continue;}
          if(P.actions[fb.poweredAction]&&P.actions[slot.poweredAction]){
            const sFb=strength(fb.poweredAction,fbg.rank),sPrim=strength(slot.poweredAction,prim.rank);
            if(sFb>sPrim+1e-9)issues.push({buildId,r,slot:slot.gu,fallback:fb.gu,type:'fallback-stronger',sFb,sPrim});
          }
        }
      }
    }
  return issues;
}

export function campaign({build='balanced',seed=1,aptitude=.44,preparation=1,rewardMultiplier=1,tribulationCombat=false,lib=null,supplyJson=null,scenario=null}={}) {
  let wallet=P.economy.startingWallet,archiveMortalWallet=0,marks=0,totalBattles=0,practiceActions=0;
  const ledger={support:0,refine:0};
  // v0.2：lib=gu-library 消费端（构筑槽位供养、poweredAction）；supply=供应解析（availability 一次判定/局）；
  // scenario={supply_limited?,key_gu_missing?,refine_tail?}。refine_tail 只切换炼制记账口径，不改成功率。
  const supply=lib?createSupply({supplyJson,seed,scenario}):null;
  const useTail=scenario?.refine_tail!=null;
  const stages=[];
  for(let r=1;r<=9;r++){
    const x=rank(r);
    if(r===6){archiveMortalWallet=wallet;wallet=0;marks=x.marksStart;}
    const stage=lib?resolveStage({lib,buildId:build,r,supply}):null;
    const guActions=stage?.guActions??null;
    const events=schedule(r);const counts={};for(const e of events)counts[e.kind]=(counts[e.kind]??0)+1;
    const seen={};let ecology=1,research=0;
    for(let period=1;period<=x.periods;period++){
      // Immortal chapters have one advance against the next three encounter rewards, not money conversion.
      let loan=0;if(r>=6&&wallet===0){loan=24*x.priceUnit;wallet+=loan;}
      const progress=r<6?(period-1)/3:r<=8?(marks-x.marksStart)/(x.marksEnd-x.marksStart):(period-1)/4;
      const ex=expedition({r,build,seed:seed+r*100+period*10,aptitude,rewardMultiplier,progress,startingWallet:wallet,guActions,supportUnits:stage?stage.supportUnits:null});
      if(!ex.success)return {success:false,r,period,reason:ex.reason,stages,totalBattles,ledger:{...ledger,support:ledger.support+ex.supportCost}};
      wallet=ex.wallet-loan;totalBattles+=3;ledger.support+=ex.supportCost;
      let cost=0;
      if(r<6){
        const acts=Math.ceil(x.practiceNeed/P.growth.practicePerAction);practiceActions+=acts;
        cost+=acts*P.growth.practiceMoneyCost*x.priceUnit;
        // Each practice action has an 8h recovery interval; no combat-rest duplication.
        if(period===x.periods&&r<5){
          const deficit=Math.max(0,P.growth.breakthroughReserve[r]-100*aptitude);
          if(deficit>P.growth.breakthroughAid)return {success:false,r,period,reason:'破境真元准备不足',stages,totalBattles,ledger:{...ledger}};
          cost+=deficit*.5*x.priceUnit;
          if(!canPromote(r,{stage:3,practice:acts*P.growth.practicePerAction,reserve:100*aptitude+deficit,access:true}))
            return {success:false,r,period,reason:'凡人晋阶条件不足',stages,totalBattles,ledger:{...ledger}};
        }
      }
      // One planned paid refinement per chapter, stochastic attempts are handled separately in budget analysis.
      if(period===2){
        const q=refinement(r,{prepared:true});
        const attempts=useTail?Math.ceil(Math.log(.05)/Math.log(1-q.success)-1e-12):q.expectedAttempts;
        const fee=attempts*q.fee;cost+=fee;ledger.refine+=fee;
      }
      if(r>=6&&r<=8){
        const lower=(period-1)*50,upper=period*50;
        let idx=0;
        for(const e of events.filter(e=>e.year>lower&&e.year<=upper)){
          idx++;seen[e.kind]=(seen[e.kind]??0)+1;
          const t=tribulationCombat
            ?tribulationFight({r,kind:e.kind,ordinal:seen[e.kind],count:counts[e.kind],build,seed:seed+r*100+period*10+idx*7,aptitude,progress,marks,ecology,guActions})
            :resolveTribulation({r,kind:e.kind,ordinal:seen[e.kind],count:counts[e.kind],preparation,marks,ecology});
          if(!t.alive)return {success:false,r,period,reason:tribulationCombat?'灾劫战斗失败':'灾劫准备不足',stages,totalBattles,ledger:{...ledger}};
          marks=t.marks;ecology=t.ecology;
          cost+=t.injury*P.growth.rebuildCost*x.priceUnit;
        }
        // Restoration is paid above; without payment the run fails rather than gaining free ecology.
        ecology=1;
      }
      if(r===8&&period>=3){research+=P.growth.researchPerProject;cost+=8*x.priceUnit;}
      if(r===9){marks+=x.campaignProjectMarks;research+=P.growth.researchPerProject;cost+=8*x.priceUnit;}
      wallet-=cost;
      if(wallet<0)return {success:false,r,period,reason:'长期筹备破产',stages,totalBattles,ledger:{...ledger}};
      stages.push({rank:r,period,wallet,marks,cost,ecology});
    }
    if(r===5){
      const a=ascend({humanQi:1,steps:Array.from({length:5},()=>({heaven:.2,earth:.2})),prepared:preparation,guard:preparation});
      if(!a.success)return {success:false,r,reason:'升仙失败',stages,totalBattles,ledger:{...ledger}};
    }
    if(r>=6&&r<=8&&!canPromote(r,{internalYears:300,allTribulationsResolved:true,alive:true,marks,attainment:'无上大宗师',research,heavenSealBroken:preparation>=.8}))
      return {success:false,r,reason:'晋阶条件不足',stages,totalBattles,ledger:{...ledger}};
  }
  return {success:true,stages,totalBattles,practiceActions,wallet,archiveMortalWallet,marks,ledger,reason:'九转四个目标完成；不推导十转或永生'};
}

export function combo({r,components,attainment=0,compatible=true}) {
  rank(r);if(!Number.isInteger(components)||components<2)throw new RangeError('combo requires >=2 Gu');
  const complexity=components*(components-1)/2;
  const capacity=P.combat.thoughtCapacity[r-1]+2*attainment;
  const overload=Math.max(0,complexity-capacity);
  return {complexity,capacity,legal:compatible&&overload===0,
    multiplier:compatible?1+Math.min(P.combat.comboMaximumBonus,.12*(components-1)+.03*attainment):1,
    energyMultiplier:1+.15*(components-1),backlashFraction:Math.min(.75,overload*.05)};
}
export function controlDuration(base,previousUses) {return base/(1+P.combat.controlResistancePerUse*previousUses);}
export function refineAttempt({r,inventory,inputs,output,known,maxRank=8,registry=[],wallet,bondedId=null,seed=1,attainment=0,prepared=false}) {
  if(r>maxRank)throw new Error('超出该蛊方品阶上限');
  if(!known)throw new Error('蛊方未知');
  if(new Set(inputs).size!==inputs.length)throw new Error('同一实体不能重复充当投入');
  if(inputs.some(id=>!inventory.includes(id)))throw new Error('投入不足');
  const quote=refinement(r,{attainment,prepared,uniqueExists:registry.includes(output)});
  if(!quote.possible)throw new Error(quote.reason);
  if(wallet<quote.fee)throw new Error('费用不足');
  const success=rng(seed)()<quote.success;
  const remain=inventory.filter(id=>!inputs.includes(id)||(id===bondedId&&!success));
  if(success)remain.push(output);
  return {success,inventory:remain,wallet:wallet-quote.fee,
    registry:success&&r>=6?[...registry,output]:[...registry],
    injury:success?0:P.refinement.failureInjuryFraction,
    bondedInjured:!success&&inputs.includes(bondedId)};
}
