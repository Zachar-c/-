# 长尾蛊转换规则（GEN-5 起）

> 地位：Game Semantics 层的长尾批量化规则（B2 批先例的一般化）。本文件回答" bare 蛊何时、按什么证据、转成什么分类"。
> 真源链不变：kind=canon/名语义（本文件），amount=balance.effect_budget 曲线投影（消费时解析），分类受 C5 审计。

## 1. 普查基线（2026-09-26，GEN-5 批）

| 层 | 数量 | 定义 | 收敛路径 |
|---|---|---|---|
| explicit | 74 | 已带 v1_effect（含 P5 各批） | 已收敛 |
| bare·runtime 身份 | 139 | roster-3 已蒸馏（156 实体内）、有名有 E:V 锚点、无 effect | **主收敛池**：Tier A/B 直接转换 |
| bare·novel 未入册 | 104 | source:novel 但未进 roster-3 表 | 前置=roster 扩充蒸馏（GEN-6+），不可跳步 |
| bare·game 内容 | 487 | school_derived/original_game_content 程序化蛊 | 无 canon 工作量；进入 loot/pack 消费面时按 Tier B 显式化 |

## 2. 分类阶梯（按证据强度）

- **Tier A（系列页级证据）→ `canon_driven_v1`**：蛊名属于某个 wiki 已核验系列（如皮甲系：铁/铜/石/玉/兽皮同一护防系列，M0 六蛊原著边界 9614–9618），系列机制覆盖成员 → kind 取系列语义，canon_anchors 指向系列锚点。石皮蛊/玉皮蛊为库内先例。
- **Tier B（名+role 对齐）→ `school_derived` 显式**：名语义与 game role 一致（骨盾蛊 defense→shield、骨翼蛊 movement→shift、草蛊 healing→heal），kind 按 role、amount-less（消费时走 KIND_TO_CURVE_ROLE 曲线投影）、effect_note 记名语义依据。身份锚点有则附，无则 names.json 层。
- **Tier C（名 role 冲突或语义弱）→ 维持 fallback**：金甲蛊（甲=防具名但 role=attack）、雷盾蛊（盾但 attack）、借力蛊/群力蛊/定力蛊（力蛊族中语义歧义成员）——转换需逐只回原文取证，禁止按名硬套。
- **Tier D（对齐但零读路）→ 机会性转换**：名+role 对齐但不进任何 loot/pack 消费面的蛊（如力蛊族主体）——转换仅为元数据增益，待进入消费面时顺手做，不做无读路空转。

## 3. 语义规则（kind 映射）

| 名关键词/系列 | kind | 依据 |
|---|---|---|
| 皮甲系（铁/铜/石/玉/兽皮）、甲、盾（defense role） | shield | M0 皮甲系列锚点 + role |
| 翼（movement role） | shift | 飞行/位移名语义 + role |
| 草（healing role） | heal | 草蛊疗伤系（九叶生机草先例）+ role |
| 力（attack role，无歧义成员） | strike | 增力系（白豕蛊 strike 先例）+ role |
| 其余 | role→default kind | strike/heal/shield/shift/inspect 按 v1_battle role 默认 |

amount 一律不写在 gu.json（消费方按 KIND_TO_CURVE_ROLE 从 PROJ-LAB-ROLE-CURVE-001 投影），存量子手填 amount 保留（P4 冻结）。

## 4. 门禁

- 每批转换重跑：web 全量（C1-2 显式保全自动覆盖新成员）+ check_balance + 消费面存在时对应基准。
- 分类断言：C5-2（school_derived 不得自称 canon_driven_v1）自动审计。
