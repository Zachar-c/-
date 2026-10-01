# HANDOFF 2026-09-30 — Wiki 知识库 / 站点 / 表结构

> 本文件为历史快照，当前状态与下一步以[2026-10-01交接](HANDOFF-2026-10-01-wiki.md)为准。下文未提交状态已过期，不作为当前执行依据。

> 交接对象：下一任 L2 / MiMo 会话
> 工作区：`C:\Users\Zachary\DevEnv\06_个人项目\gu-zhenren`
> 日期：2026-09-30
> STATUS：**PARTIAL — 站点已可用，大量改动未提交**

---

## 0. 一句话现状

Wiki 已完成 EPUB 切源、盲测补库、人向导航、L1 表结构 `kind` 落地；本地站点 `问真·知识库` 可浏览。**工作区约 300 文件待提交**（主要是 194 页 frontmatter `kind` + 站点前端/构建脚本）。

## 1. 已完成（均已验收门禁）

| 阶段 | 提交 | 内容 |
|---|---|---|
| EPUB 切源 + B1–B7 | `ec7ccbb3` | runtime 绑 EPUB；首轮盲测缺口补库 |
| 人向导航 | `1dbcf020` | 五条阅读路径、分类 index、paths/、导读 |
| 全库盲测结论 | `57a5a3f4` | 6/40；缺心理层与后期高章；**不批全库 IA 重写** |
| 盲测缺口补库 | `03b9c6c6` | 东海/卷六/开门蛊/判断层/Q16 两层裁定 |
| **L1 表结构**（未提交） | — | 10 kind 写入 frontmatter；站点按 kind 分栏 |

## 2. L1 裁决（权威，勿再自行改表）

文件：`ai-system/RESEARCH-REQUEST-2026-09-30-wiki-table-taxonomy.md`

- **仅 10 kind**：`character` `gu` `event` `world` `path` `rule` `theme` `index` `relation` `reference`
- frontmatter 单字段 `kind`；**禁止**物理拆目录；不增 `subkind`
- 实体页=主落点；总表只导航/对照；关系页只写关系
- world=舞台环境；path=力量分类；rule=normative / world=descriptive
- 站点侧栏两组：知识（7）/ 索引与资料（3）；URL 不变

## 3. 站点

| 项 | 值 |
|---|---|
| 入口 | http://127.0.0.1:8877/ （`python -m http.server 8877 --directory lore/wiki/web/app/dist`） |
| 前端源 | `lore/wiki/web/app/{index.html,app.js,style.css}` |
| 构建 | `python lore/wiki/web/build_app.py`（需系统 Python：yaml/bs4/markdown_it/PIL） |
| 产物 | `lore/wiki/web/app/dist/`（data.json 16MB + 142 webp + 前端拷贝） |
| 远程 | ChatGPT Site `https://wenzhen-wiki-2026.czhmail2026.chatgpt.site/`（需单独同步） |

**站点 debug 已修**：曾因补丁误删 `AUDIT_COLOR`/`TAGS` 导致「数据载入失败」；已恢复常量并 Edge headless 验证首页可渲染。

## 4. 未提交（请分批 commit）

1. **L1 kind 落地**：194 概念页 `kind:` + `build_app.py` + `app.js` + `style.css` + `_kind_map.json` + RESEARCH-REQUEST
2. **建议排除**：Godot `*.import`、`game/wenzhen-web-lab/assets/wenzhen/` 大图（约 96MB）
3. 样本 kind 分布：gu 82 / path 41 / index 18 / world 17 / event 14 / reference 14 / character 7 / rule 7 / theme 7 / relation 3

## 5. 硬约束（继承 AGENTS.md + L1）

- 不 `git reset --hard`；不 push 未经 L0 确认
- 不把 `source/` 原文入库（例外：`source/蛊真人-epub-canon.txt`）
- 全库 IA 重写 / 物理拆目录 / 二级 taxonomy：**禁止**
- 验收看真实门禁输出，不只看退出码
- 设计顺序：原文取证 → Wiki 蒸馏 → L1（改造/数值）→ 计划 → Worker

## 6. 建议下一步

1. **L0 浏览站点五栏**（人物/蛊/事件/世界/流派 + 总表/关系）验收 L1 落地
2. **提交** kind 批（勿混 .import）
3. 远程 ChatGPT Site 同步（若仍需要公开窗口）
4. 盲测复测小样本（可选）；心理层可继续按 `2026-09-30-wiki-full-corpus-conclusion.md` 补厚事件页

## 7. 关键路径速查

```
ai-system/RESEARCH-REQUEST-2026-09-30-wiki-table-taxonomy.md  # L1 裁决
ai-system/tasks/2026-09-30-wiki-full-corpus-conclusion.md     # 盲测结论
ai-system/tasks/2026-09-30-wiki-knowledge-gap-batches.md      # B1–B7 方案
lore/wiki/web/build_app.py                                   # 站点构建
lore/wiki/web/app/                                           # 站点前端源
lore/wiki/tools/check.ps1                                    # G1 门禁
```

## 8. 工作区卫生

- 临时脚本已删；保留 `lore/wiki/web/_kind_map.json` 作 L1 双人分类审计底稿
- `check.ps1` / `docs-lint` 在 kind 写入后全绿（194 概念页 / 21126 E-ID）
