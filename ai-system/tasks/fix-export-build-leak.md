# 修复 Release 导出包含构建产物的技术债

在 `game/` 工程内处理一个小而明确的发布边界问题：

- 阅读 `game/AGENTS.md` 中与导出、测试和改动范围有关的规则。
- 阅读 `game/export_presets.cfg` 与 `game/tests/unit/test_export_presets_exclude_filter.gd`。
- Windows Desktop 和 Android 两个 Release 预设都必须排除 `build/*`，避免旧 EXE/APK 或其他构建产物被嵌入新的 PCK。
- 为测试补充明确断言，确保两个预设都包含 `build/*`；不要只检查第一个预设。
- 只修改完成这个目标所需的导出配置和对应测试，不改游戏玩法、数据、正文或其他技术债。
- 不提交、不推送，不运行会覆盖用户文件的命令。

验收：

1. 运行 `game/tests/unit/test_export_presets_exclude_filter.gd` 对应的 GUT 单测，或使用仓库现有的最小单测命令。
2. 运行 `git diff --check`。
3. 返回修改文件、测试命令和结果，并说明两个预设是否都被断言。
