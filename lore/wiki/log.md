# Wiki 更新日志

## 2026-09-18

- 创建最小 Markdown Wiki 骨架。
- 接入现有事实索引、记忆库和分卷读书笔记作为蒸馏输入。
- 新增 15 个知识页，覆盖修炼、资质、真元、养蛊、南疆、主要人物、核心蛊虫、事件和《人祖传》。
- 知识页统一使用 `type`、`name`、`aliases`、`sources` 四个 frontmatter 字段；不确定内容放入“待核对”。
- 原文继续留在现有 `source` 路径，本批只建立引用入口，没有复制整部小说。
- 未引入数据库、向量索引、图谱、运行时或 Quartz。
- 验收结果：15 个知识页、26 个 Markdown 文件；frontmatter 完整；相对链接全部可解析；无双括号链接和行尾空白。
- 验收命令：`git diff --check`、frontmatter/link PowerShell 校验、`rg -n '\[\[' wenzhen-lore`、`rg -n '[ \t]+$' wenzhen-lore`。
- 第二阶段深化 `方源.md` 与 `人祖传.md`：加入人物阶段、行动逻辑、叙事意义、38 节索引和跨剧情互文；没有新增页面或游戏设计目录。
- 修正方源资质记录：27 步对应丙等，真元海约四成四；修正依据来自当前资料索引和已有章节记录，最终仍需回原文核验。
- 为《人祖传》增加整理状态：摘要覆盖 1–38 节，但原文逐节核验和跨剧情互文仍处于未完成/初稿状态。
- README 目标表述调整为“创作中优先获得稳定、结构化的世界知识，并在需要时回查原文”，明确 Wiki 不是原文替代品。
- Phase 2 新增 3 个核心主题页：`宿命`、`自由`、`坚持`，并接入主题索引；主题页只记录原著输入和分析，不写玩法数值。
- 修正资料入口：补齐 F2a、I2a、A2b 的实际“补读”文件名，并替换不存在的 C-30001-45000 笔记引用。
- 最新验收结果：18 个知识页、29 个 Markdown 文件；frontmatter、source/notes 路径、相对链接和 `git diff --check` 全部通过。
- 根据 Phase 2 评审，为 4 个主题页统一增加“核心定义、相关人物、相关事件、主题冲突、游戏设计边界”等导航区块。
- 补齐方源、逆流河、春秋蝉与主题页之间的反向链接；缺少独立页面的红莲、天庭、宿命大战和坚持蛊只保留待建文字，不提前扩张目录。
- Phase 3 新增核心人物页 `红莲魔尊.md` 与组织/世界页 `天庭.md`；记录红莲遗产、天庭组织逻辑和两次轮回边界，不新增游戏系统。
- Phase 3 接通人物、世界和主题索引；红莲、天庭与方源、春秋蝉、宿命、自由、人祖传之间的相对链接已补齐。
- Phase 3 验收结果：20 个知识页、31 个 Markdown 文件；20/20 frontmatter 字段完整；source/notes/memory 路径、相对链接和主题模板通过；无 `connections/`、双括号链接或行尾空白。
- 工作流修正：后续以“主题簇 / 叙事冲突 / 世界规则链”为最小评审单元；页面、索引、反向链接、来源边界和验收应在同一批次内完成，不再按单页制造阶段性审阅。
- 下一统一批次定义为“宿命冲突簇”：宿命蛊、宿命大战、星宿仙尊、龙公，并与既有红莲、天庭、方源、春秋蝉和宿命主题页一次性接通。
- “宿命冲突簇”已完成：新增宿命蛊、宿命大战、星宿仙尊、龙公四页；补齐分类索引和相关主题、人物、蛊虫、世界页的反向链接。
- “宿命冲突簇”验收结果：24 个知识页、35 个 Markdown 文件；24/24 frontmatter 字段完整；核心节点待建立引用为 0；source/notes/memory 路径、相对链接、主题模板和 `git diff --check` 全部通过。
- Wiki 解冻：用户决定按 `lore/wiki/AGENTS.md` 的编辑约定继续蒸馏，冻结期结束；续作计划见 `docs/superpowers/plans/2026-09-18-wenzhen-lore-wiki-continuation.md`。
- 修正迁移遗留的 12 处 `source:` 引用（`source:source/分支：六卷精编版/...` 残尾），并把 canon 命名空间统一为 `canon-index:`。
- 新增验收脚本 `lore/wiki/tools/check.ps1`，本批全部检查项通过。
- Batch 0 收尾：根 `README.md` 去掉 wiki「冻结」措辞；`check.ps1` 增加 check6（概念页被分类索引收录）与 check7（`type` 与目录一致）两条门禁，全部通过。
- Batch 4 天庭冲突簇：新增 `中洲炼蛊大会.md`（`events/central-plain-refinement-conference.md`）、`石莲岛与红莲真传争夺.md`（`events/stone-lotus-island-contest.md`）、`天庭入侵琅琊福地.md`（`events/langya-blessed-land-invasion.md`）三页；来源边界为 `source:source/蛊真人-clean.txt` 加对应 G/H1/H2 读书笔记（琅琊页仅 H1），Run 1 缺口一律入「待核对」。
- Batch 4 反向链接：`world/heavenly-court.md` 3 条待建立清零并指向新页；`events/index.md` 收录 3 页；`events/fate-war.md` 关键转折接通 3 页；`characters/red-lotus.md` 关联页面追加石莲岛页；`characters/fang-yuan.md` 关联页面追加 3 页。
- Batch 4 验收结果：27 个知识页、38 个 Markdown 文件；`check.ps1` 7 行 PASS、`ALL CHECKS PASSED`、退出码 0；`git diff --check` 无输出；`heavenly-court.md` 内「待建立」0 命中；Wiki 页面内 source 直引分支路径 0 命中（仅本日志的历史叙述行保留旧字样）。
