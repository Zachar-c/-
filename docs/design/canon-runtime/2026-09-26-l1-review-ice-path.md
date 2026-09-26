# L1 评审提案：冰道蛊入池与 bai_ice_warden 持蛊化

> 提出日期：2026-09-26。状态：**已裁决（L0 2026-09-26，A'）**——见文末裁决记录；语义实现仍待后续批次。
>
> **L0 裁决记录（2026-09-26，A'）**：①批准新增 `ice` school（不挂靠 water）；②批准 `bing_ji_gu`/`shuang_yao_gu` 拼音式 id；③否决 `bing_ji_gu=shield`/`shuang_yao_gu=strike` 作为最终 canon-driven 语义；④bai_ice_warden 可登记持有双蛊，冰道 Game Semantics 实现前 `frost_javelin` 维持 `attackSource:"innate"`（显式债务，不视为持蛊化完成）；⑤否决仅凭 rank3 曲线将 intent.damage 1→3；⑥最小冰道语义=冰肌蛊持续/被动防御（无需持续真元）+ 霜妖蛊变身/破特定防御/自爆可后置；⑦完成门禁=敌人真实使用核心差异机制后 `attackSource` 方可 innate→gu。原则：**持蛊化不是挂 gu_id，而是让持有的蛊真实改变战斗语法。**
> 背景：P5 敌人持蛊化批中 `bai_ice_warden`（frost_javelin，dmg 1）因白名单无冰道蛊暂判 `attackSource:"innate"`（登记 P5 判定文档长尾队列 + debt.md）；GEN-4 批已在 `lore/wiki/gu/roster.md` 落盘冰道谱系（canon 前提就绪）。本提案补齐 game 侧决策项。

## 1. Canon 事实（已核验，见 roster.md 冰道系）

| 蛊 | 转数 | 机制 | 锚点 |
|---|---|---|---|
| 冰肌蛊 | 三转 | 练成冰肌、防御卓绝、耐冰霜寒冷；一经练成无须真元支持（如黑白豕蛊增力永久留存）；冰晶成护甲 | 原文 23066/23114/23222/23502 |
| 霜妖蛊 | 三转 | 变身类（女用）；可洞穿白玉蛊防御；绝境可自爆 | 原文 23110/23148/23464 |
| 冰晶蛊 | 三转 | 变身类（男用）；白凝冰以紫荆令牌二万八千元石购得 | 原文 50264–50296 |
| 冰道定位 | — | "冰道的话，优势在于防御"（明文） | 原文 50250 |

## 2. 决策项

1. **是否新建 game 侧 `ice` school**：schools.json / school_pools.json / build_data `ICON_BY_SCHOOL` / loot_tables 均按 school 组织，新增 school 牵动四处数据结构（机械但面广）。
2. **新增蛊 id**（建议两只，均三转=game rank 3 压缩）：
   - `bing_ji_gu`（冰肌蛊）：role=defense，effect=shield（amount 走 lab 曲线 defense r3=5 / world 曲线 8）；canon_driven_v1，锚点同上。
   - `shuang_yao_gu`（霜妖蛊）：role=attack，effect=strike（变身类在游戏侧按攻击表达）；canon_driven_v1。
3. **bai_ice_warden 转化**：attackSource `innate` → `gu`；装载 [霜妖蛊]（主战）+ [冰肌蛊]（辅，护甲语义）；frost_javelin intent 两个选项——
   - A：dmg 1 → 改由装载蛊合成（霜妖蛊 rank3 → 敌方压缩投影 T[3]=3），intent.damage 1→3（**改世界数值，Godot 侧可见**）；
   - B：frost_javelin 维持 intent 级 innate（凡兵冰矛）+ 装载蛊只作身份——零数值漂移，但"持蛊而不用"语义弱。
4. **命名方案**：`bing_ji_gu`/`shuang_yao_gu` 拼音 id vs 语义 id（`ice_muscle_gu`）——全库 canon 蛊 id 现为拼音式（moonlight_gu 除外，系历史命名）。

## 3. 影响面与成本

- A 选项数值漂移：bai_ice_warden 非四遭遇窗口敌人（check_balance 不咬），漂移仅 Godot 参考实现可见；世界数据 dmg 1→3 与同转敌人（r2→3）对齐。
- 新 school 的 loot/school_pools 为空池起步，不影响现有抽取。
- 估算工作量：数据 4 文件 + build_data 图标映射 + C 系断言 + 实体页 2 张 + pack 实体 2 只（GEN-5 出题联动）≈ 半个批次。

## 4. 建议

选 A（真持蛊化）+ 拼音 id + 新 ice school。理由：canon 证据充分（三转+机制+定价先例 28000 元石）、敌人持蛊化是 RUL P5 主张、"持蛊而不用"违背批次语义。若 L1 判 ice school 成本过高，退 B（单蛊挂 water school + intent innate 维持）并登记 debt。

## 5. 关联

- `docs/design/canon-runtime/2026-09-26-p5-scaleout-gate.md` GEN-4 节 / 长尾队列 #3
- `lore/wiki/gu/roster.md` 冰道系（canon 取证落点）
- `lore/runtime/rules.json` CAN-*（冰道规则暂无专条；若 L1 批准，冰道攻防规则随 pack 扩容走 GEN-5 出题）
