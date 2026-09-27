# P3-B1 · 批B 剩余面结果包（Caveman Review Packet）

> 任务：`ai-system/tasks/p3b1-role-curves.md`（2026-09-26 收敛版）
> 裁定依据：`game/world-model/rulings/RUL-2026-09-26-001.json`（RULED）
> 执行：L2（本会话直接执行，未走外部 Worker 派发）
> STATUS：**READY_FOR_P3B1_REVIEW**

## 0. 一句话结论

lab role 曲线已按 RUL-2026-09-26-001 换基（`sqrt_budget_scalar_projection_v1`，attack [1,2,2,3,4] 等六条），
敌方攻击压缩表同批重基（改伤随表，25 处合成意图伤下调），MVP 例外按五字段重基，
check_projection 60/60、check_balance 49/49、测试 264 中 263 过（唯一失败=B 线预存）、
换基后真实整局 seed 103 仍 victory。Q2 批B 验收五条中 ⑤「换基后代表性 encounter 落目标回合区间」
自此**有实义地**成立。

## 1. 交付物对照（包 DELIVERABLE 1–7）

### 1.1 新投影条目（T1）

- `game/wenzhen-web-lab/data/projections.json` PROJ-LAB-ROLE-CURVE-001：
  `policy = "sqrt_budget_scalar_projection_v1"`；value = attack `[1,2,2,3,4]` / defense `[1,2,2,3,4]` /
  healing `[1,1,2,2,3]` / logistics `[1,1,1,2,2]` / movement `[1,1,1,1,1]` / recon `[1,1,1,1,1]`；
  rationale 照抄裁定文本；parents/forbidWriteBack 不动；validation.type 改 `formula_projection`。
- 旧基线 `[2,3,4,5,6]` 已离开全部 Runtime 消费路径（check_projection 新增「无旧基线 silent fallback」
  断言守护生成物）。
- 公式与取整：`max(1, ceil(world_amount / √20))`——attack r1: 4/4.4721=0.894→1；r2: 1.342→2；
  r3: 1.789→2；r4: 2.460→3；r5: 3.578→4，与裁定逐值一致。

### 1.2 敌方攻击压缩表重基（T2）

- `PROJ-LAB-ENEMY-ATTACK-001`：`{1:2,2:3,3:3,4:4,5:4}` → **`{1:1,2:2,3:2,4:3,5:4}`**
  （= 新 LAB attack 曲线逐等值映射；「满足 ≤ 曲线、单调不减两条不变量的最小改动重基」，
  rationale 已登记改伤随表与「无固定 1/4 公式」的去耦裁定）。
- 构建期校验（build_data）：Σ 激活 projected strike == intent.damage 全部通过（重跑零错误）。

### 1.3 enemies.json 逐行推导依据（T3）

**damage（改伤随表，25 处）**——规则：`Σ table_new[rank(gu)]（kind=strike）`，仅 attackSource=gu
合成意图（innate 授权伤不动）：

| 敌人 | 意图 | 旧→新 | 依据（装载蛊 rank × 新表） |
|---|---|---|---|
| neutral_stone_wanderer | stone_palm | 2→1 | bone_atk_1_08 r1→1 |
| ridge_elite_scout | swift_crossbow | 3→2 | fire_atk_2_01 r2→2 |
| miasma_vein_lord（×3 段） | miasma_burst | 2→1 | water_atk_1_08 r1→1 |
| faction_guard | shield_bash | 3→2 | sword_atk_2_12 r2→2 |
| marrow_gu_adept | marrow_lance | 3→2 | water_atk_3_05 r3→2 |
| clan_warden | gate_block | 2→1 | sword_atk_1_05 r1→1 |
| clan_elder | clan_authority | 3→2 | moon_ray_gu r2→2 |
| clan_patriarch（×3 段） | clan_wrath | 4→2 | moonlight r1(1)+sword_atk_1_06 r1(1) |
| rogue_cultivator | wild_strike | 2→1 | sword_atk_1_05 r1→1 |
| slave_path_adept | thrall_lunge | 3→2 | moon_ray_gu r2→2 |
| mo_family_huntsman | mo_hunt_fork | 2→1 | bone_atk_1_08 r1→1 |
| xiong_bear_handler | bear_pounce | 2→1 | white_boar_strength r1→1 |
| bone_gun_marauder | bone_spear_barrage | 3→2 | water_atk_3_05 r3→2 |
| jiangshi_handler_boss（×3 段） | corpse_command | 2→1 | bone_atk_1_08 r1→1 |
| merchant_hall_inquisitor | arrest_chain | 2→1 | sword_atk_1_06 r1→1 |
| slave_path_overseer（×3 段） | overseer_whip | 3→2 | moon_ray_gu r2→2 |
| formation_path_warden | formation_strangle | 3→2 | water_atk_3_05 r3→2 |

不变行（7 处）：blood_vein_bishop vein_whip ×3、soul_path_reaper soul_bell ×3 + soul_burst ×1
——装载蛊均为 r5（blood_droplet / blood_atk_5_02，新表 r5=4=旧值）。

**hp（零改动，推导依据）**：真实战斗玩家伤害源 = gu.json 显式 amount（P4 冻结切片，本批只读），
真实 kit DPR **不变** → 真实层 envelope 比率 = 1.0 → 45 只 hp 逐只比对全部落在 ≤20% 带内，
无 override 需要，零手调（ANSWER Q2「不因此手调全部敌人」在最严格意义上成立）。

### 1.4 MVP 例外重基（T6）

`js/mvp_content.js` 七条动作全部补齐五字段（parentProjection/baselineValue/overrideValue/
overrideReason/forbidWriteBack=true）：

| 蛊 | baseline（role×rank） | 旧值 | 新值 | 说明 |
|---|---|---|---|---|
| moonlight_gu | attack r1 = 1 | damage 2 / supported 3 | **1 / 2** | 回归 baseline；supported 保持 +1 光道增益关系 |
| small_light_gu | （不消费 amount） | inspect/support | 不变 | 语义例外：布尔位；gu.json 为 strike+support，lab 不取伤害面 |
| stone_shell_gu | defense r1 = 1 | block 5 | **1** | 回归；chargeGuard 语义保留 |
| vitality_grass_gu | healing r1 = 1 | heal 1 | 1 | baseline 与原值一致（重基确认，无差异） |
| jade_skin_gu | defense r1 = 1 | block 3 | **1** | 回归 |
| white_boar_strength_gu | attack r1 = 1 | damage 2 / wounded 5 | **1 / 4** | 回归；wounded 保持 +3 破绽关系 |
| moon_glow_gu | attack r2 = 2 | damage 4 | **2** | 回归；suppressWhenRevealed 保留 |

重基后 refDpr **2.5 → 1.5**；参考层代表性敌 HP 自动重推导：battle_1 8→**5**、battle_2 9→**5**、
elite 14→**8**、boss 15→**9**（旧值由旧 refDpr=2.5 同公式复核；新值为 check_balance 实际输出），
四个冻结窗口全部落内（见 1.5）。旧 pinned 值未自动继承（Q4）；「overrideValue==旧值」仅 vitality_grass
一处且 baseline 相等、非保留差异。

### 1.5 ⑤ 窗口验收（T4 硬门禁）

```
check_balance.mjs   49/49 PASS
  battle_1  3~5   hp=5  dpr=1.50 zero=0.25 → 4.44 回合 ✓（H1 偏差 0）
  battle_2  4~6   hp=5  dpr=1.50 zero=0.33 → 5.00 回合 ✓
  elite     4~6   hp=8  dpr=1.50 zero=0.00 → 5.33 回合 ✓
  boss      6~9   hp=9  dpr=1.50 zero=0.25 → 8.00 回合 ✓
  威胁窗（survival/handle 冻结值）4/4 ✓
check_projection.mjs 60/60 PASS（新增 AUTOACCEPT 六断言：
  parent 在案 / 公式复算 30 值逐值 / 单调不减 / policy 名 /
  生成物实值一致 / 无旧基线 silent fallback；敌方表 ≤ 曲线 + 单调）
node --test        264 中 263 PASS；唯一失败 = 「node type labels…」（B 线预存，
                   COORDINATION 已有登记，与本批无关）
```

### 1.6 测试期望值更新（4 处，逐处依据）

| 文件 | 断言 | 旧→新 | 依据 |
|---|---|---|---|
| tests/balance.test.mjs | refDpr 带宽 | (1.5,3) → (0.75,2) | Q4 重基后 refDpr 2.5→1.5 |
| tests/conformance.test.mjs | C4-2 notEqual | small_light_gu 豁免 | 换基后其显式 amount=1 与新曲线 r1=1 数值重合，判别失效；防兜底由全对象相等断言承担（生成 effect 含 inspect/support 字段，兜底产物不可能同形） |
| tests/gu_rules.test.mjs | 兜底镜像 | 6/7 → 4/4 | role 兜底镜像随新曲线 r5 |
| tests/mvp_logic.test.mjs | supportedDamage | 3→2 | Q4 重基，+1 关系保持 |

### 1.7 真实整局证据（T5）

`node tools/acceptance_lab.mjs --seed 103 --difficulty normal --policy gu_first`：
**victory**，55 节点走尽至 L5B，7 例异闻精确结算，两次重载 0 diff，旧种子复走一致，
0 console error（JSON 与截图同 2026-09-26 验收目录）。真实玩家伤害不变（gu.json 只读）、
敌方合成伤下调后整局仍可通——注意此为**运行证据**，非难度结论（RUL Q2：整局通关不作为
单项硬门禁）。

## 2. 范围合规

`git diff --stat` 证明零改动：balance.json / v1_battle.json / gu.json / gu_names.json /
js/balance.js / Godot 全侧。本批实际改动 = projections.json、enemies.json（25 处 damage）、
mvp_content.js、check_projection.mjs、js/data.js（重生成）、4 个测试文件的期望值。
snapshot.py 已不存在（world-model 清理时删除）——git 干净树即回滚点（包注记条款适用）。

## 3. 批外异常事件（如实登记）

执行中途 `game/data/gu.json` 与 `game/data/gu_names.json` 被批外进程覆写为
「BOM + 空容器 + CRLF」签名（8 字节 / 4 字节；非 node 写出特征，测试运行前后哈希对照
**不复现**）。两文件均为本批只读输入、零预期改动，已 `git restore --source=HEAD` 恢复
（804 蛊 / 802 名），恢复后全量测试与完整性校验通过。建议留意环境侧是否有并行进程
触碰 game/data。

## 4. 预存项（非本批引入）

- build_data 输出注记：`thunder_crown_wolf 的 counter_status="sparked" 无规则实现`（数据/规则漂移 1）。
- 测试失败 1 项：node type labels（B 线预存）。

## 5. 剩余风险与后续

1. 真实层节奏：敌方合成伤下调 25–50%、真实 hp 不变（比率 1.0）→ 真实局**变易**；
   参考层窗口/威胁门按裁定冻结值全部成立。若 L0 认为过易，属于下一轮校准（V5）议题，
   不在本批权限内。
2. 参考层与真实层的 kit 量纲现在显式分叉（MVP 重基 1.5 vs 真实 gu.json 不变）——
   五字段记录已把两者关系写明；后续若收敛需世界侧决策。
3. soul_path_reaper 等纯 r5 合成敌伤害不变——其威胁占比相对上升，已在窗口/威胁门内。

## 6. 判定

包 ACCEPTANCE 逐项满足；无 ESCALATE 条件触发（窗口全部在少量 override=0 下成立）。
建议 L2 复核后按 COORDINATION 批B 段登记收口。
