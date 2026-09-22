const OK = [
  {
    t: '成长单位 = 力量体系，不是等级/技能条',
    p: '获蛊 → 判断价值 → 用/卖/留/炼 → 组合 → 杀招变化 → 资源 → 修为 → 淘汰/重构。',
  },
  {
    t: '转数 = 力量层级，≠ 装备稀有度',
    p: '同转可差很大：垃圾/普通/优秀/极品。优秀一转可压垃圾二转；五转仍可留一转功能蛊。',
  },
  {
    t: '平衡对象 = 成熟构筑与路线，不是同转单价',
    p: '单蛊可以不公平；长期唯一正确答案才要报警。',
  },
  {
    t: '道 = 资源语法 + 状态语法 + 战斗语法',
    p: '不是元素染色。血=伤势转换；智=念头/推演/信息；力=身体/承伤/低外源。扩道=新绑定，不是复制技能树。',
  },
  {
    t: '蛊 = 元件；杀招 = 运行结构',
    p: '核心+辅助+次序+状态+资源+规则。换核应重推 variant，不是「月光 Plus」。',
  },
  {
    t: '修为 = 能承载什么',
    p: '真元质量/容量/可催动层次/杀招复杂度/资源规模。不是全伤害乘倍率（RUL-008）。',
  },
  {
    t: '经济与掉落是力量循环，不是商店外挂',
    p: '50 石必须同时相对：蛊价、炼耗、失败损失、一场均收、几次成长一次。生态掉配：兽材/蛊师元石秘方/商队货。',
  },
  {
    t: '敌人升转加手段与规则密度',
    p: '识别重复杀招、针对资源、逼你换手段。否则后期杀招是摆设。',
  },
  {
    t: '信息与跨回合代价',
    p: '意图/反制/观察必须改变顺序与资源；强力手段的代价可跨回合（真元/气血/材料/未来机会）。',
  },
  {
    t: '升仙 = 凡人构筑总考试',
    p: '碎窍/渡劫/三气应暴露体系问题，不是过场。工程：Integration First，禁第四套系统。',
  },
];

const SKEW = [
  {
    t: '单局「一转→五转巅峰」与 Roguelike 死亡环的张力未闭合',
    p: '你写的是「一路构筑到五转巅峰」——这更像长战役。若一局即 1→5 且死亡清空，则失败成本极高；若多局继承，又会滑向局外战力（已被红线禁止）。',
    decay: '若不补上 → 变成要么超长一局 roguelite，要么隐形 meta 成长。',
    fix: '需要 L0 明确：五转巅峰是「一局 Run 的终点」还是「多局知识/配方图鉴累积后的大考」？知识类跨局（蛊方图鉴）已允许，力量类不允许。',
  },
  {
    t: '杀招「运行结构」若不能落到可替换组件，会从侧门变回终极技能',
    p: '固定 24 配方卡 + 一键发动 = 换皮大招。真正构筑要求：换核/换辅后消耗、失败条件、反制面、推演成本一起变，并在结算里生效。',
    decay: '若不补上 → 「推演」只是 UI 里的改装菜单。',
    fix: '工程上要有 componentSlots + 重推演规则 + 杀招失效/新 variant 事件；不是再手填 K1–K24 效果表。',
  },
  {
    t: '掉落生态驱动「去哪打」 vs「五域/地图不是优先」矛盾',
    p: '「我缺材料→谁掉→去哪找→用什么构筑打」依赖最小空间结构（节点池/路线向性即可），不依赖完整五域剧情。',
    decay: '若不补上 → 掉落只是随机奖励，寻材闭环断掉。',
    fix: '用现有 map/encounter/pacing：敌人生态绑定节点层与向性即可。',
  },
  {
    t: '「平衡路线」指标还不够',
    p: '无长期唯一答案 ≠ 只看路线胜率。还要：无支配循环（经济套利/单杀招通吃）、无死内容、关键组件可形成。',
    decay: '若不补上 → 三路胜率 33/33/33 但只有一条最优成长路径。',
    fix: 'autoplay + check_balance 增加支配/套利/死内容门；五转出现率仍待 L1（勿自决）。',
  },
  {
    t: '隐藏信息的持久性未定义',
    p: '若反制知识每局清零，「信息是资源」会退化成背板或纯赌；若全跨局永久，又变成图鉴碾压。',
    decay: '若不补上 → 要么 gotcha，要么无效 UI 文案。',
    fix: '局内 KnownCounters 已有；跨局只留「已识别规则类型」级知识（图鉴/秘方），不留本场数值。',
  },
  {
    t: '推演若无代价 = 菜单改配',
    p: '杀招重构应耗洞察/时间/失败/一次实战验证，否则「值不值得这招」不存在。',
    decay: '若不补上 → 最优解静态化，构筑乐趣消失。',
  },
  {
    t: '升仙考试若只验数值门，会奖励短期爆发',
    p: '总考试应测体系性质：循环是否闭合、代价是否真实、手段是否多解、信息是否被使用。',
    decay: '若不补上 → 升仙=装等检定。',
  },
  {
    t: '「单蛊可以不公平」与「死内容」的边界',
    p: '允许垃圾蛊；不允许无炼/无杀招/无经济/无材料用途且全阶段使用率≈0 的死内容（已有 DEAD_CONTENT 口径）。',
    decay: '若不补上 → 不公平被滥用成「这一整系都没用」。',
  },
];

const LOOP = `获得蛊
  → 判断价值（战斗/炼蛊/杀招/市场/保值）
  → 使用 / 出售 / 保留 / 炼化
  → 与已有蛊组合（元件替换）
  → 形成或修改杀招（重推演）
  → 战斗方式变化
  → 新资源（元石/材/食/秘方）
  → 修为提升（能承载更高层）
  → 再次淘汰、替换、重构

反模式：
一转装备 → 二转装备 → 三转装备 → 数字变大`;

const ENG = `盘点现有实现 → 找重复/冲突 → 概念定 Owner
→ 打通数据流 → 复用 balance/check/autoplay
→ 仅在确认无已有实现后才新增

Owner（摘要）：
  Rank/HP/念头/石     game/data/balance.json + gu_balance.gd
  蛊身份/效果         game/data/gu.json
  炼方/杀招/敌/店/掉  game/data/*
  市价                market_rules.gd
  Web 桥              build_data.mjs → data.js
  校验                check_balance.mjs · autoplay.mjs

禁止：
  第三套 Rank / 第三套定价 / 第三套战斗结算器
  第四套 canonical framework
  把 30/24/50 手填表当真源（只作 Golden 校准）

详见 game/wenzhen-web-lab/EXISTING_CAPABILITY_MAP.md`;

const $ = (s) => document.querySelector(s);
$('#okCards').innerHTML = OK.map(
  (x) => `<article class="card ok"><h3>${x.t}</h3><p>${x.p}</p></article>`
).join('');
$('#skewCards').innerHTML = SKEW.map(
  (x) =>
    `<article class="card skew"><h3>${x.t}</h3><p>${x.p}</p>
     <div class="decay">退化 → ${x.decay}</div>
     ${x.fix ? `<p style="margin-top:8px">补法 → ${x.fix}</p>` : ''}</article>`
).join('');
$('#loopText').textContent = LOOP;
$('#engText').textContent = ENG;

$('#tabs').addEventListener('click', (e) => {
  const b = e.target.closest('button[data-tab]');
  if (!b) return;
  document.querySelectorAll('.tabs button').forEach((x) => x.classList.remove('on'));
  document.querySelectorAll('.panel').forEach((x) => x.classList.remove('on'));
  b.classList.add('on');
  $('#' + b.dataset.tab).classList.add('on');
});
