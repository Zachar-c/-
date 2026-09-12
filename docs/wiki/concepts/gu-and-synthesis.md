---
title: 蛊虫与炼蛊
description: 蛊实例体系、20 流派 802 只目录、三类蛊方（晋升/古方/自由混合）与核心蛊规则
date: 2026-09-12
tags: [gu, synthesis, refinement, schools]
---

蛊虫是永久实例资产（Run 内），同名蛊不同实体，交易/喂养/炼化/催动都针对实例而非定义[^1]。每只蛊单一主功能六分类（攻击/防御/治疗/移动/侦察/辅助），多道标签开放集合，不做全局克制倍率[^1]。持有数量无硬上限——由喂养、炼化、交易成本形成软上限[^2]。

## 目录现状（gu.json）

802 只（含 1 测试蛊）：rank 分布 220/157/180/97/147；20 流派各 40 只（human 42）；稀有度 common 368 / rare 185 / epic 249；角色 attack 379 / defense 100 / movement 92 / healing 80 / recon 78 / logistics 73[^3]。786 只标注小说出处[^3]。

**核心风险**：仅 48 只有显式 v1_effect，其余 754 只由角色兜底表给默认数值——目录的标签多样性进战斗后大多收敛为同一条数值曲线[^4]。

## 蛊方三类（392 条）

| 类别 | 数量 | 机制 |
|---|---|---|
| advance 晋升 | 377 | 同名蛊 + 兽骨 1-2 + 元石 6/10 → 转数+1（封顶 5） |
| fixed 古方 | 14 | 人工设计配方，附小说出处与失败代价（如月芒方=月光蛊+小光蛊×2） |
| free_mix 自由混合 | 1 | 2 蛊起合，成功率 60%+败递增；三结局：毁尽 w5+蛊蚀 / 变异血别蛊 w4 / 炸炉 w1（HP-2 魂-1 寿-1） |

已知配方安全确定成功；随机失败只保留给盲炼/自由混合[^5]。材料去重仅 5 种，兽骨占 378/385——晋升经济单一化是已登记缺口[^4]。

## 核心蛊与构筑

每局一局只能同时确认一只核心蛊，可推迟、可更换（代价显著、通常每局一次）[^1]。实现侧有 `claim_core_token` 核心替换券挂在 2 层 boss/商队节点[^3]。核心权益是"有限补全倾斜 + 少量专属升炼"：改善候选分布但不保证毕业[^1]。

自由组合规则：逐只催动已炼化蛊，每只先按单一功能结算，后续蛊可读取已形成的状态；基础联动无知识门槛、不收组合费、不凭空倍率[^1]。同流派支援 `support_school` 只惠及本回合后续同流派蛊[^6]。

## 关联页面

- 杀招是组合的高级形态 → [杀招系统](kill-move-system.md)
- 配方数据细节 → [数据表全集](../entities/data-tables.md)
- 计价入口 GuBalance → [经济系统](economy.md)

[^1]: docs/superpowers/specs/2026-09-01-gu-system-economy-combat-design.md, §1/§2/§4.1
[^2]: AGENTS.md, 核心业务红线
[^3]: PROJECT_WORLD_MODEL_AUDIT.md, §6
[^4]: PROJECT_WORLD_MODEL_AUDIT.md, §25
[^5]: docs/superpowers/specs/2026-09-01-gu-system-economy-combat-design.md, §5.3
[^6]: docs/superpowers/plans/2026-09-11-sword-school-landing-plan.md, §0 F4
