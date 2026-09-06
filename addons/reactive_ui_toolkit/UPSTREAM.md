# Reactive UI Toolkit — 上游记录

- 上游 URL: https://github.com/reactive-ui-toolkit/ruitk-godot
- 锁定提交: 4fe6927222bd5de4094dc39748ff5a248e00962b
- 版本: 0.11.x（depth-1 clone，取当时 HEAD）
- 许可证: Reactive UI Toolkit Community License 1.1（非 MIT）
  - 开发 / 评估免费；公司（含母公司 / 子公司）近 12 个月营收 < US$250,000 可免费发布，超出需商业许可。
  - 全文见 `addons/reactive_ui_toolkit/LICENSE` 与 `LICENSE-COMMERCIAL.md`。
- 引入日期: 2026-08-25
- 用途: UI 表现层统一组件体系（`V.fc` / `RuitkRoot`）与克制动效。
- 编译器可无头调用：`RuitkGuitkx.compile(source, basename, [], {}, self_path, "res://")`；
  本仓库用 `scripts/acceptance_driver.gd`（`-- --mode=smoke`）在 `--script` 下编译并挂载验证（无需编辑器 GUI）。
- 仅提交 `.guitkx` 源；编译产物 `.gd` 由 `.gitignore` 的 `ui/**/*.gd` 忽略，导出前需先编译。
