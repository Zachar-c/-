---
title: RunState 与存档
description: RunState 不可变模式、双 JSON 存档、校验位与 MetaProgress 持久化的实现
date: 2026-09-12
tags: [run-state, save, persistence, serialization]
---

本局状态集中在单一 RunData 纯数据对象，新一局整体重建；序列化只保存 ID 和数值，不保存引擎对象[^1]。

## RunState 关键字段

开局：丙等一转散修，80 血 / 60 寿元 / 魂 1（soul_max 4）/ 12 元石 / 洞天真元 20 / 初始蛊小光蛊（实例 gu_001）[^2]。战斗 hp 经 `sync_battle_hp_to_state` 每命令写回防双源漂移[^3]。Pity 计数器（loot_pity / material_pity / synthesis_fail_streak）在 RunState[^2]。

**已知债务**：`current_battle`、`current_session` 镜像字段（2026-09-12 纠偏计划列为 P1 债）[^2]。

## 存档机制（save_repository.gd 315 行）

| 机制 | 实现 |
|---|---|
| 双档案 | 大厅档 user://nanjiang_smoke_meta.json + Run 档 user://nanjiang_smoke_save.json |
| 版本 | SAVE_VERSION = 4（v3 大厅档迁移保留；v3 Run 档拒绝，返回"大厅进度、蛊方图鉴与已解锁信息已保留"） |
| 原子写 | 写 .tmp → flush → 删旧 → rename_absolute |
| 校验位 | 键名排序后逐值递归 XOR 整数校验和 |
| 事件日志校验 | `event_%04d` 连续 + 末条 after 与 state 一致；容忍 `_` 前缀旁路键 |

拒绝契约 diagnose 返回 9 种 kind：missing / invalid_json / unsupported_version / invalid_state / invalid_route / checksum_missing / checksum_mismatch / invalid_event_log[^2]。

Run 结束时删除进行中 Run 存档；无感自动保存、续玩恢复离开前进度[^1]。

## MetaProgress

11 字段见 [Meta 图鉴](../concepts/meta-progression.md)；全程 `_copy()` 不可变更新；新局注入 `global_codex_ids`[^2]。

## 设计约束

修改 run_state.gd / save_repository.gd 均属 Shared 单写者区，走 5 步协议[^4]；模块接口页 docs/contracts/module-interfaces/05-run-state.md[^5]。

[^1]: AGENTS.md, 技术约定
[^2]: PROJECT_WORLD_MODEL_AUDIT.md, §19/§21
[^3]: PROJECT_WORLD_MODEL_AUDIT.md, §9/§15
[^4]: docs/contracts/2026-09-12-agent-ownership-contract.md
[^5]: docs/contracts/module-interfaces/05-run-state.md
