# 最小可演示 Demo（蛊路求生）

## 构建

- 产物：`build/win/gu-zhenren.exe`（Windows x64，Release 导出，PCK 内嵌，双击即玩）
- 重新导出：`powershell -File tools/export.ps1`（预设 `Windows Desktop`，导出路径 `build/win/gu-zhenren.exe`）
- 排除项：vendor、语料分支、docs、tests、GUT、editor 工具链均不进包
- 调试入口：双重关闭（Release 无 `OS.is_debug_build()`；`data/debug.json` enabled=false）

## 启动

双击 `build/win/gu-zhenren.exe`。开发机调试运行用 `powershell -File tools/play.ps1`。

## 5 分钟演示路径

1. **大厅（30s）**：问眞纸墨界面 → 「入世」开新局（选一个门派，如 force）。
2. **地图（1min）**：雾遮路线选节点——优先走 `combat` 节点，展示节点类型多样（战斗/事件/商店/炼蛊）。
3. **战斗（2min，演示核心）**：
   - 敌方卡片：中文意图（攻击/蓄势/防御）+ 速度 + 伤害，点选目标；
   - 我方手牌：四行卡面（品质/名称/费用/效果），悬停出统一详情 tooltip；
   - 释放蛊虫 → 结束回合看敌方意图结算 → 拳脚/撤退取舍。
4. **合成杀招（1min，可选）**：走到炼蛊节点，用 `小光蛊 + 迹眼蛊` 合成 `脉冲鼓`，战斗中出现组合杀招「明丝合击」（2 真元 1 念头，3 伤害）。
5. **结局（30s）**：受击死亡看死因结算页；或地图指令面「自尽/放弃本局」直接进统一结算，演示「结局归因只看事件日志」。

## 演示边界（如实说明）

- 非 slice 的旧蛊虫效果走 role fallback（可玩但效果朴素）；
- 长局性能未优化（ObjectDB 退出泄漏告警不影响单局演示）；
- 25-seed 平衡数值为初版中央倍率，未按试玩反馈调优。
