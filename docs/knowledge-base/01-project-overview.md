# 项目概览

## 项目性质

- 原作：《蛊真人》，已完本；授权文本精编（出版级深度精编），非连载、非续写、非大纲制作。
- 工作内容：删除站点噪声、修复转码残字、统一硬设定、压缩重复，不新增剧情与解释。
- 分批方式：六部结构 + 批次（编辑与版本单位），批次不代表原作缺失。

## 目录结构

| 路径 | 内容 | 权威性 |
| --- | --- | --- |
| `volumes/01-魔性不改/` | 精编正文 `vol*.edited.txt`（UTF-8）与 EPUB 成品（001-199 已按回修重建） | 交付物 |
| `volumes/02-魔子出山/` | 第二部正文（vol2-sec001.edited.txt 已开局） | 交付物 |
| `working/` | 按批抽取的 CP936 原文底稿（01-199 已补齐；gitignore 临时文件，不入库） | 编辑回溯对照 |
| `notes/` | AGENTS.md 规定的基础台账 5 本 + 卷级专项台账 7 本 + FB 核证表 + 编辑说明 + 全书审查意见 | 权威台账 |
| `index/` | 章节标题索引（724 候选）、序列段审计、源文件元数据 | 结构证据 |
| `outlines/volumes/` | 六部篇章分纲（`01-魔性不改` 等） | 纲目 |
| `outlines/arcs/` | 十场高潮分纲 + 转场图 | 纲目 |
| `outlines/detail/` | 逐节细纲（第 1-199 节全部建立） | 纲目 |
| `scripts/` | 抽取、拆分、建档、校验、EPUB 构建脚本 | 工具 |

## 当前进度（2026-08-08，拉取 b57f821 后）

- 规范：`AGENTS.md` 为唯一完整规范源，含上下文恢复协议、权威层级、内容边界与编辑判据。
- 第一部《魔性不改》：199 节正文精编完成并于 b57f821 回修（掌故/怨怼按规范改写），细纲 1-199 全部建立，EPUB 001-199 已按回修重建。
- 第二部《魔子出山》：第 1 节（黄龙江竹筏）正文已建，物理分卷与第一卷 199 界线已固化。
- 裁决：`notes/vol1-decision-register.md`（DEC-001~）已冻结卷一战力、经济、信息、时间等裁决；全书核证登记表 FB-001~016 在核证/待定位中。
- 台账：人物 28 行、伏笔 30 条、资源 21 行、时间线 16 行、事实争议已扩至 FD012（部分 decided）。

## 脚本命令

| 脚本 | 用途 | 示例 |
| --- | --- | --- |
| `validate_editorial_assets.ps1` | 全资产校验（UTF-8、噪声标记、细纲覆盖 1-199、批次数、链接、CSV、源文不入库） | `-Phase baseline/outline/detail/final` |
| `extract_batch.ps1` | 从源文按行抽取 CP936 底稿 | `-SourcePath -StartLine -EndLine -OutputPath` |
| `create_edited_baseline.ps1` | 由底稿生成精编基线稿 | 见脚本注释 |
| `split_volume_boundary.ps1` | 分卷切割（第一卷 199 / 第二卷起点） | 见脚本注释 |
| `build_index.ps1` | 从源文构建原始标题索引 | `-SourcePath -OutputDirectory` |
| `normalize_source_index.ps1` | 归一化索引、生成审计报告 | `-SourcePath -RawIndexPath -OutputDirectory` |
| `build_epub.ps1` | 从精编正文构建 EPUB（支持多文件合并、BookId 参数） | `-SourcePath @(…) -OutputPath -BookId` |

## 工作流

遵守 `AGENTS.md`：读规范 → 恢复上下文（审计登记/卷级裁决/专项台账/细纲/正文）→ 逐节编辑 → 反向对照 → 同步台账 → 回归验证 → 用户审阅；每批独立校验与提交。

## 源文件与统计

- 路径：仓库根目录 `蛊真人.txt`（授权基准源，tracked）；CP936/GBK；437060 行。
- 临时底稿 `working/*.cp936.txt` 已逐批次补全 1-199 节（gitignore，仅本地对照用）。
- 标题候选 724 个，重复节号 208 个，25 个序列段，41 行待人工审。
- 解码字符（去换行）8320079，用户申报 14577005：两口径分开记录，互不替代（FD006）。