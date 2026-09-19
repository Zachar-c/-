# Batch 20：Semantic Boundary Normalization（人物页）

## 目标

对人物页的 `## 原著明确内容` 做逐条证据层级收敛。目标不是重写人物资料，而是消除“只有 notes/memory 支撑的陈述因所在区块而像 Canon”的语义误导。

## 允许修改的文件（仅限以下四个）

- `lore/wiki/characters/fang-yuan.md`
- `lore/wiki/characters/star-constellation.md`
- `lore/wiki/characters/dragon-duke.md`
- `lore/wiki/log.md`

禁止修改其他文件；禁止新增人物页、来源文件、索引系统、脚本、数据库或游戏代码。

## 核心规则

1. 先读 `AGENTS.md` → `PROJECT_MAP.md` → `lore/wiki/README.md` → `lore/wiki/AGENTS.md`，再读 `ai-system/WORKER_PROTOCOL.md` 与 `ai-system/WORKER_HANDOFF_TEMPLATE.md`。
2. 修改前执行 `git status --porcelain`。Batch 19 已独立提交；保护所有其他项目改动，不回滚、不格式化、不覆盖。
3. 逐条审查三个页面的 `## 原著明确内容`，不能机械地整段搬家：
   - 有可直接回查的本地原文行号/段落，或正文明确绑定的已核验 `canon-index:CAN-*` 依据，并且陈述范围没有超过证据：可以保留在 `## 原著明确内容`；必要时只补最小证据定位。
   - 只有 `notes:` / `memory:` 锚点，或正文明确写“整理资料/读书笔记/记忆库”，且本批没有逐段原文核验：移入 `## 资料整理`，保留原文、锚点、轮次和限制语；不得改成新的事实。
   - 多条事实之间的归纳、人物弧光、价值判断放在 `## 分析与解读`，并明确它是归纳/解读，不要因为来自笔记就全部塞进 `资料整理`。
   - 证据冲突、同一性不明、轮次未确认继续留在 `## 待核对`，不得为了区块完整而升级。
4. 如果页面新增 `## 资料整理`，使用统一降级说明：资料来自读书笔记/记忆整理，尚未完成逐段原文核验，不得当作原著原文事实。Run 1 / Run 2 仍然分开。
5. 不为了满足区块形式而新增事实。不得扩写方源、星宿、龙公经历，不得把人物写作约束或分析资料升级成原著事实。
6. 只在必要时更新正文内“见原著明确内容/见资料整理”指针；不重写无关链接，不改 frontmatter，除非发现现有来源字段本身失效（发现时停止并报告，不自行修架构）。
7. 更新 `lore/wiki/log.md`，记录每个页面逐条分层的结果、保留/降级依据、未处理的证据缺口和未触碰范围；不要改写 Batch 11–19 历史记录。

## 逐条审查要求

交付报告必须列出每个页面：

- 保留在 `原著明确内容` 的条目及其证据类型（source 行号或 canon-index ID）。
- 移入 `资料整理` 的条目及原有 notes/memory 锚点。
- 放入 `分析与解读` 的跨事实归纳（如有）。
- 留在 `待核对` 的条目（如有）。
- 无法判定的条目不得猜测，标为未核验并说明原因。

## 验收命令

从仓库根目录运行：

- `pwsh -NoProfile -File lore/wiki/tools/check.ps1`
- `git diff --check`
- `git status --short -- lore/wiki`

必须逐项记录结果。不要提交、推送或合并；本批提交由协调方在评审通过后另行处理。

## 交付

严格按 `ai-system/WORKER_HANDOFF_TEMPLATE.md` 输出完整 Review Handoff。最终状态只能为 `READY_FOR_REVIEW` 或 `BLOCKED`。
