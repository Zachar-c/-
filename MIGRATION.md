# MIGRATION.md

> Monorepo 迁移来源登记。执行计划：`docs/superpowers/plans/2026-09-18-gu-zhenren-monorepo-migration.md`；设计：`docs/superpowers/specs/2026-09-18-gu-zhenren-monorepo-migration-design.md`。

## Baseline

- 父仓库不可重写历史基线：`5f3fbfc6d303ad2885175a896e4218036f99230e`（`origin/master`，Task 1 门禁确认值）。
- 当前迁移分支：`codex/gu-zhenren-monorepo-migration`；Task 2 基于 `072a818`（`docs: add monorepo migration implementation plan`）工作，提交后以 Verification Log 为准。
- 远程基线状态：以下为计划中记录的观测值，**尚未在本次 Task 2 中重新抓取**；Task 3 Step 2 将以 `git ls-remote` 重新核对，漂移则以实测值替换并在此记录变化：
  - `gu-zu`（`master`）观测 `84b8ce8`
  - Gitee 游戏（`master`）观测 `c982fe9`
  - GitHub `gu-zhenren-editor`（`main`）观测 `dbf6615`
  - `fortune-app`（`master`）观测 `a039639`
  - `fortune-server`（`main`）观测 `6a5eed2`
  - `my-ai-production-system`（`main`）观测 `fbe67e2`

## Repository Mapping

| 当前来源 | URL | 来源分支 | 目标目录 | 迁移方式 | 过滤参数 | 阶段提交 |
|---|---|---|---|---|---|---|
| `gu-zu` | `https://github.com/Zachar-c/gu-zu.git` | `master` | `lore/research/` | 过滤历史后 subtree 导入；保留完整资料包 | Task 4：`*蛊真人-clean.txt`、`*《人祖传》.txt`（`--invert-paths`，以前缀由 `git subtree add --prefix` 提供，不用 `--to-subdirectory-filter`） | 待 Task 5 |
| 当前 `wenzhen-lore/` | 父仓库 `5f3fbfc` 快照（本地） | — | `lore/wiki/` | `git mv` 扁平移动；只做机械路径更新 | 不适用（工作树移动；原文候选按 Task 3 清单排除） | 待 Task 5 |
| GitHub `gu-zhenren-editor` | `https://github.com/Zachar-c/gu-zhenren-editor.git` | `main` | `editorial/` | 过滤历史后 subtree 导入 | 同上 Task 4 过滤组 | 待 Task 6 |
| `fortune-app` | `https://github.com/Zachar-c/fortune-app.git` | `master` | `fortune/app/` | 过滤历史后 subtree 导入；不带外层本地包装目录 | 同上 Task 4 过滤组 | 待 Task 6 |
| `fortune-server` | `https://github.com/Zachar-c/fortune-server.git` | `main` | `fortune/server/` | 过滤历史后 subtree 导入 | 同上 Task 4 过滤组 | 待 Task 6 |
| `my-ai-production-system` | `https://github.com/Zachar-c/my-ai-production-system.git` | `main` | `ai-system/` | 过滤历史后 subtree 导入 | 同上 Task 4 过滤组 | 待 Task 6 |
| Gitee 游戏 | `https://gitee.com/chen-dong-s/gu-zhenrens-pigeon-meat.git` | `master` | `game/` | 最后过滤历史后 subtree 导入；保留 Godot 工程结构 | 同上 Task 4 过滤组 | 待 Task 7 |

- 历史保留方式：外部仓库先在临时镜像中过滤禁止原文路径，再以不带 `--squash` 的 `git subtree add --prefix` 导入，保留作者、日期和提交历史；临时镜像不进入父仓库。
- 已发布历史不重写：`master` / `origin/master` 不被改写；各阶段提交只落在 `codex/gu-zhenren-monorepo-migration`。
- 回退信息：每阶段提交前均可 `git status --short` 核对；回退即 revert 对应阶段提交，不改写已发布历史。

## Source Namespace Mapping

Wiki 当前 frontmatter 中的 `source:`、`notes:`、`memory:` 是逻辑来源命名空间，不是名为 `source/notes/memory` 的目录。迁移采用以下机械映射（Task 5 执行）：

```text
source:gu-zhenren-editor/...  -> source:source/...
notes:gu-zhenren-editor/...   -> notes:game/...
memory:gu-zhenren-editor/...  -> memory:game/...
notes:gu-zu/...               -> notes:lore/research/...
memory:gu-zu/...              -> memory:lore/research/...
```

- `lore/wiki/source/README.md` 和 `lore/wiki/source/chapter-index.md` 使用新的仓库相对路径 `source/...`、`game/...` 和 `lore/research/...`。
- 完整原文只保留在本地 `source/`；公开克隆校验允许标记为 `LOCAL_ONLY`，本地完整资料校验必须在 `source/` 存在时解析通过。

## Verification Log

- Task 2（本提交）：根边界验证，命令见计划 Task 2 Step 5：
  - `Set-Content -LiteralPath 'source\probe.txt' -Value 'local-only'` → `git check-ignore -v` 命中根 `/source/` 规则 → `Remove-Item` 删除探针。
  - `git diff --check`（根文档无行尾空白）。
  - `git status --short`（只出现本 Task 预期修改）。
  - 输出见 Task 2 worker 报告；本节在后续 Task 追加阶段提交、验证命令、失败原因和回退方式。
