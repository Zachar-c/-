# Q8_GRAMMAR_DECISION_LOG.md — Q8-R1→R2 裁定变更记录

> - **日期**：2026-09-12
> - **范围**：只记录「用户裁定导致的规格变更」，不承载规格本体。语法唯一权威：`GU_EFFECT_GRAMMAR_V2_FINAL.md`。
> - **格式**：每条 = R1 立场（`GU_EFFECT_GRAMMAR_V2_REVISED.md`）→ R2 裁定 → 理由 → 影响。

| # | 主题 | R1 立场 | R2 裁定 | 理由（用户裁定） | 影响 |
| --- | --- | --- | --- | --- | --- |
| D1 | condition 落空的成本 | 成本语义未定稿（存在「资格不成立仍消耗资源」的歧义） | **零成本资格判断**：miss → 不扣成本、无部分结算、事件 `condition_miss` | condition 是资格不是效果；「没打中还掏钱」违背成本可见直觉 | FINAL §5；B1 类「残血才起效」构筑成立 |
| D2 | consume_status 落空 | 拟资源照扣 | **`consume_miss` + 不扣成本**，与 D1 同构 | 线性公式只定义命中情形；落空走资格路径 | FINAL §3；引爆流可放心携带 |
| D3 | weaken_intent 作用域 | battle 全局 `next_intent_mod` | **per-target**：写目标身上 `intent_weaken`；只降低目标**下一次 damage intent**；用后立即清零；selector 必填默认 `enemy_first`；不做全局 debuff | 全局 debuff 产生跨目标涟漪，违反一效果一操作与 per-target 纪律 | FINAL §2；词典 §6.2 已同步 |
| D4 | 触发器集合 | on_play / on_hit_taken / on_turn_end / on_kill 四钩子 | **第一版只有 on_play / on_hit_taken**；on_turn_end / on_kill 降为未来候选（只记录不实现） | 候选 ≠ 批准实现；先证最小集 | FINAL §4；词典 §5.2 已同步 |
| D5 | 操作集 | 9 操作（含 move、复合等） | **冻结 5 个**：strike / shield / heal / status(marked+sealed) / weaken_intent；其余撤出第一版 | 先证明 5 操作能承载 802 蛊的纵切，再谈扩容 | FINAL §2 |
| D6 | sealed 范围 | R1 已定「提前进纵切」，范围未定稿 | **最小纵切**：只做敌方 damage intent 门禁；封蛊、封技、封印持续体系一律不做 | 防止 sealed 长成第二套控制世界观 | FINAL §2 |
| D7 | 修饰符集合与形态 | support / consume_status / delay 三件（R1 已定） | **冻结 3 个**；delay 形态锁定：只允许 `on_play + delay + operation`，与他层组合 schema 拒绝 | 防 modifier 组合滥用 | FINAL §3 |
| D8 | 验证蛊规模 | 36 只 | **12 只**：基础×4 / 组合×4 / 信息反制×2 / 高成本×2 | 纵切目的是证明语法表达力，不是铺内容 | `Q8_12_GU_VERTICAL_SLICE.md` |
| D9 | 决策场景规模 | 12 个 | **6 个**：全部 A/B 双合理、理由差异非纯数值 | 场景验证的是决策结构，不是数量 | 同上 §F |
| D10 | active_permanents 定位 | 未明确定位 | **技术容器，非世界模型**；蛊生命周期（hunger / loyalty / ferocity / flee）本阶段冻结 | 容器不承载世界观承诺 | FINAL §7 |
| D11 | 管线顺序与集合定稿 | 管线 trigger→condition→cost→selector→operation→modifier（operation 先于 modifier）；condition 谓词 5 件（hp_below/hp_above/enemy_hp_below/enemy_status_present/own_status_present）；selector 未成文集 | **R2 验收定稿（2026-09-12 PASS）**：管线 = `can_activate → trigger → condition(false→结束) → cost commit → selector → modifier → operation`（modifier 先定参、operation 后结算）；condition 冻结 3 谓词 `self_hp_below / enemies_alive_gte / turn_gte`；selector 冻结 3 项 `self / enemy_first / enemy_all` | H1：cost commit 是第一笔不可逆变更，资格 miss 必须在 commit 前短路，杜绝 cost-then-check | FINAL §1 / §5 |
| D12 | 实现硬约束 | 未成文 | **H1–H4**：H1 成本提交顺序（禁 cost-then-check）；H2 consume_status 原子事务（验证→计算→提交→清除，禁 clear-then-strike）；H3 sealed 数据化（敌意图带 `damage_intent` 属性，禁硬编码 skip）；H4 enemy_first = 敌人行动队列第一个存活目标（≠数组首位、≠最危险） | 用户验收裁定 4 条，作为 Q8-IMPLEMENT 全程硬门槛 | FINAL §12 |

## R1→R2 重申（非变更）

- shift 只作历史兼容（→ shield 转译保留，v1_battle_resolver.gd:419-424），新内容禁用。
- support 维持 **modifier** 层级（R1 裁定不变）。
- 杀招多段走 `steps`，不加新 effect kind。
- 行为保持承诺不变：显式化前后**逐只**蛊对拍，非抽查。
- 引擎改动上限仍为 4 处（sealed 门禁 / intent_weaken / delayed_effects / trigger 泛化）。
