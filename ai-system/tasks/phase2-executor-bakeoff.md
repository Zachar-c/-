# Phase 2 Executor Bake-off：强化确定性重放验收

## 目标

修复 `game/tests/unit/test_battle_save_load_semantics.gd` 中的重放测试，使它真正验证每条脚本命令都被接受并产生有效结果，而不是只比较最终快照。

## 背景

`test_same_seed_and_command_sequence_replay_to_the_same_battle` 当前调用 `controller.submit_command(command)` 后忽略返回值。这样即使中间命令被拒绝、没有改变状态或没有产生事件，只要两次运行最终结果一致，测试仍可能通过。该问题已在 `game/docs/superpowers/reports/2026-09-17-battle-core-audit.md` 的 F-05 中记录。

## 要求

1. 阅读相关测试、`RunController.submit_command` 的返回契约和现有测试惯例。
2. 修改重放测试，使每条脚本命令的返回值都得到明确断言：命令必须被接受，且返回结构必须表明成功/有效执行。
3. 保留现有的最终战斗状态和事件日志确定性比较。
4. 若现有返回契约无法支持上述断言，只做达到验收所需的最小测试辅助调整；不得重构战斗系统。
5. 只修改与本任务直接相关的文件，优先限制在 `game/tests/unit/test_battle_save_load_semantics.gd`。
6. 运行聚焦 GUT 测试：

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File tools/godot.ps1 --headless --path . -s addons/gut/gut_cmdln.gd -gtest res://tests/unit/test_battle_save_load_semantics.gd -gexit -glog=1
   ```

7. 不提交、不推送、不修改 `ai-system` 配置、不调用 CCR。

## 验收

- 聚焦测试通过。
- `git diff --check` 通过。
- diff 不越界到无关产品逻辑或配置。
- 返回 Worker Protocol 要求的改动摘要、测试结果和未验证风险。
