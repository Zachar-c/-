# 主链写入移交记录 · 2026-09-25 L0 构筑分叉 · Phase 0 / Gate 0

## 移交信号

| 项 | 值 |
| --- | --- |
| 移交者 | 本会话 L2（MiMo）· L0 裁决落盘 + Phase 0 实施 + Gate 0 验收 |
| 接手者 | 下一会话 L2 / Worker（Phase 1 敌人问题轴） |
| HEAD | `7f43b91f7e263e404203228cbc466de91453ba17` |
| 移交时间 | 2026-09-25 |
| 写入权 | 自本记录落盘起，主链写区归接手会话；上一会话无在途写 |
| 工作树 | **脏**（~76 条 status 行，含历史未提交与本批）；**未 commit / 未 push** |

## 权威入口（先读）

1. `docs/superpowers/specs/2026-09-25-l0-build-fork-decision.md` — L0 五项批准 + 两项 HOLD
2. `docs/superpowers/plans/2026-09-25-build-fork-rebuild.md` — Phase 0–11 总计划
3. `working/loop-audit-20260923/current-state.md` — 当前阶段状态
4. `game/wenzhen-web-lab/docs/BALANCE_EVIDENCE_DISCIPLINE.md` — 平衡证据永久纪律

## TASK / STATUS

```text
TASK L0-DECISION-APPROVED-5-1-2 + PHASE0
PHASE 构筑分叉验证 · Gate 0
STATUS READY_FOR_REVIEW
TYPE architecture | implementation | bugfix
ASK ① 是否接受 Phase 0 / Gate 0 为可信基线 ② 是否放行 Phase 1
```

## GOAL

把阶段目标从「验证线性强度」切到「验证构筑分叉」；先建立可信实验基线（Gate 0），不改善乐趣。  
范围外：HOLD-1 战后真元回满、HOLD-2 路线锁未来、UI 仪式感、Godot 线同步、自由杀招自动推导。

## DELTA

```text
+ docs/superpowers/specs/2026-09-25-l0-build-fork-decision.md
+ docs/superpowers/plans/2026-09-25-build-fork-rebuild.md
+ game/wenzhen-web-lab/tests/phase0_gate0.test.mjs
+ game/wenzhen-web-lab/docs/BALANCE_EVIDENCE_DISCIPLINE.md
~ js/gu_rules.js — killMoveGateMissReason / killMoveEffectPlan 条件继承 / liveRecipes / killMoveIsDirectStrike
~ js/describe.js — killMoveEffectText（组件合成权威展示）
~ js/data.js — boss 蛊池补齐；advance_* retired；古方 mechanical:false retired
~ js/main.js — 杀招门禁/直接攻击口径跟合成语义
~ js/battle.js / killmove.js — 展示改 killMoveEffectText
~ js/alchemy.js — liveRecipes 过滤
~ js/shop_rules.js / journey.js — 无机械收益商品不可购
~ tools/build_data.mjs — 不再导出 advance 自环与 gu_fang
~ tests/shop_rules.test.mjs — 古方无机械收益断言
= HOLD-1 / HOLD-2 / Rank 倍率禁令 / 自动推导未授权
```

## STATE

```text
L0 五项裁决     VERIFIED（冻结件落盘）
Phase 0 六项    VERIFIED（代码 + 测试）
Gate 0          VERIFIED（phase0_gate0 7/7）
全量测试        VERIFIED（174 pass / 0 fail）
Phase 1        UNVERIFIED（未开工）
真实走盘        PARTIAL（历史 seed101；本批未重跑 autoplay）
git commit     NONE（工作树脏，待用户确认是否提交）
```

## FILES（本批关键）

```text
docs/superpowers/specs/2026-09-25-l0-build-fork-decision.md
docs/superpowers/plans/2026-09-25-build-fork-rebuild.md
game/wenzhen-web-lab/js/{gu_rules,describe,data,main,battle,killmove,alchemy,shop_rules,journey}.js
game/wenzhen-web-lab/tools/build_data.mjs
game/wenzhen-web-lab/tests/{phase0_gate0,shop_rules}.test.mjs
game/wenzhen-web-lab/docs/BALANCE_EVIDENCE_DISCIPLINE.md
working/loop-audit-20260923/current-state.md
```

## SHA-256（移交时实测）

```text
af9805f1962d330f6ef5877772418936fa2537dca319fc36dd947408f0c1dff0  game/wenzhen-web-lab/js/gu_rules.js
5ef2a48e5b87ccd758fc973436f9ae1c341f96df76d2a4fcfdc804bfac405cbe  game/wenzhen-web-lab/js/describe.js
91cdf345550ca7e7c1f4a17b042c151f53565e6605588b783b16c6b8e9ac2048  game/wenzhen-web-lab/js/data.js
d4e899bfe78bbc80c22f38ddddf3366e418971310482acbc5901404ed1c88299  game/wenzhen-web-lab/js/main.js
da05f595450a69e395b15b5829769ae8ed8e0b8b6adf11e3bd4ae84aedc897a9  game/wenzhen-web-lab/js/shop_rules.js
512d7cc4472952a3eed7b7b3969ed41993e3ecca46f528d6f1095bcc77cb0ff3  game/wenzhen-web-lab/tests/phase0_gate0.test.mjs
6274f2a1c8225ed28889d06a2557fe80815c631c0d7345b77e29a3404b0b4a2b  docs/superpowers/specs/2026-09-25-l0-build-fork-decision.md
abf5b02d52b07279ca46ecf6e901ef133873c43fe8371356d82483bd8d9b25eb  docs/superpowers/plans/2026-09-25-build-fork-rebuild.md
```

## TEST（V1：只认输出文本）

```text
focused: node --test tests/phase0_gate0.test.mjs tests/shop_rules.test.mjs tests/gu_rules.test.mjs
         → PASS 27 / FAIL 0
full:    node --test tests/*.test.mjs
         → PASS 174 / FAIL 0
diff-check: PASS（只动声明文件；未 commit）
```

Gate 0 断言覆盖：

1. Boss 蛊池非空且 id 可解析  
2. advance 自环 retired 且不在 liveRecipes  
3. 古方 mechanical:false 不可购  
4. 杀招展示/门禁/结算同源组件 battleEffect  
5. 组件条件默认继承；`componentConditionOverride` 显式突破  
6. 预制 `m.effect` 不驱动结算  
7. 正式掉落 gu 可解析；正式购买有 gu/material  

## DECISIONS（已生效，接手者不得推翻）

| ID | 裁决 |
| --- | --- |
| D1 | 阶段目标 = 验证构筑分叉与完整力量循环 |
| D2 | vertical 仅解冻 inspect / suppress / armorBreak\|pierce / ignoreEvasion |
| D3 | 杀招权威 = 组件 battleEffect 合成；展示=门禁=结算 |
| D4 | 材料主角色 = 炼蛊配方钥匙 / 定向获得力量 |
| D5 | Build identity = 蛊替换 + 炼蛊分支 + 杀招重构；Rank 只承载 |
| HOLD-1 | 战后真元回满 — **NOT APPROVED** |
| HOLD-2 | 路线节点锁未来 — **NOT APPROVED** |

## RISK

- 工作树脏且未提交：接手前先 `git status`，不要覆盖未核对改动。  
- `data.js` 注释写「不要手改」，但本批为 Phase 0 语义修复直接改了生成物；`build_data.mjs` 已同步，**下次再生会丢掉 boss 池手补内容**，除非把 boss 池也写进 `game/data/loot_tables.json`。  
- 血昙满血现已正确被门禁挡；若 UI 未提示「条件未满足」，玩家可能误以为按钮坏了（体验问题，非 Gate 0 失败）。  
- 本批未重跑 autoplay 真实走盘；策略坍缩（refine≡balanced）仍未验证。

## UNPROVEN

- Gate 1（三种敌人问题可辨识）  
- Build Mutation 节奏（3–6 战一次）  
- 炼蛊二选一分支  
- 材料 Consumer 闭环  
- 可赢性（30/30 defeat 是否仍是结构必然）

## GIT

```text
status: dirty ~76 lines（历史 + 本批）
commit: NONE
merge: NONE
push: NO
```

## DECISION REQUESTS

```text
D1 本批是否独立提交？ | recommend YES | Gate 0 已绿，应留下可回滚点
D2 是否放行 Phase 1 敌人三轴？ | recommend YES | 基线可信后才该出题
D3 boss 蛊池是否迁入 loot_tables.json 真源？ | recommend YES | 避免 build_data 再生丢失
```

## NEXT

1. 确认后提交本批（或按批拆 commit）  
2. Phase 1：三敌人问题轴（信息反制 / 重甲 / 闪避）× 四动词  
3. Gate 1：隐藏名字只看 trace 能辨三题  

## STOP

- 不改 HOLD-1 / HOLD-2  
- 不把复写引擎结果当平衡证据  
- 不顺带扩容 vertical  
- 不把 Rank 做成万能倍率  
- 不先调胜率  

## EVIDENCE

- 裁决：`docs/superpowers/specs/2026-09-25-l0-build-fork-decision.md`  
- 计划：`docs/superpowers/plans/2026-09-25-build-fork-rebuild.md`  
- 测试：`game/wenzhen-web-lab/tests/phase0_gate0.test.mjs`  
- 状态：`working/loop-audit-20260923/current-state.md`  
- 证据纪律：`game/wenzhen-web-lab/docs/BALANCE_EVIDENCE_DISCIPLINE.md`  
