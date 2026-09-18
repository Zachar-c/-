# 技术债解决实施计划（2026-09-09）

> 依据：`docs/audit/2026-09-09-technical-audit.md`（基线 `7f3dde6`）。
> ~~**未闭环工单的原子任务拆解**（W11.3 / W12 / W10）~~ → **全部闭环（2026-09-10）**：W11.3=轨道 A（`49ffbe5` 合入）、W12=轨道 B（`fc7cb3e` 合入）、W10=轨道 C（`158aef4`）。拆解与逐任务回执见 `docs/superpowers/plans/2026-09-09-tech-debt-atomic-tasks.md` 与 `2026-09-10-tech-debt-atomic-execution.md`。
> 本计划按工单卡组织，**每张卡可直接分配给一个工作会话独立执行**，不依赖历史对话。
> 执行模式：一卡一会话；完成一张回写一张状态；提交保持聚焦（AGENTS 工作流程第 8 条）。
> 时间基准日：2026-09-10。D+n 表示基准日后第 n 天。并行视觉会话活跃期间（`ls -lt scripts/presentation/screens/` 半小时内有人动）**不得执行 W2/W7/W11/W12**。

---

## 1. 债务分类与优先级总表

| 类别 | 工单 | 来源（审计章节） | 级别 | 预估工时 | 计划完成 |
|---|---|---|---|---|---|
| 发布卫生 | W1 导出隔离（.gdignore + exclude） | P0-2 | **P0** | 0.5h | D0 |
| 仓库健康 | W2 停止跟踪 build/ + gc | P0-1 | **P0** | 1h | D1 |
| 合规 | W3a LICENSE + W3b 游戏内署名 | P0-3 | **P0** | 0.5h + 3h | D1 / D4 |
| 测试安全网 | W4 快照契约测试 | P1-2 | **P1** | 4h | D3 |
| 性能 | W5 开新局重复加载（先实测） | P1-3 | **P1** | 1h（含实测） | D2 |
| 架构 | W6 display_text 校验盲区 | P2-1 | P2 | 2h | D5 |
| 架构 | W7 map_generator fallback 告警 | P2-2 | P2 | 0.5h | D5 |
| 守门 | W8 契约漂移守门入 check.ps1（含遗留 P4） | P2-3 | P2 | 2h | D5 |
| 流程 | W9 分支清理 + .claude gitignore | P2-4 | P2 | 0.5h | D1 |
| 视觉会话 | ~~W10 continue_run 语义~~ ✅ 闭环（2026-09-10 方案甲，`158aef4`） | 审计 §5.1 | P1 | 视觉会话自估 | ✅ 视觉会话收工时 |
| 大重构 | ~~W11 resolver 拆分 + 基础动作表迁移（含遗留 P3）~~ ✅ 闭环（轨道 A，2026-09-10，`49ffbe5`） | P1-1 | P1 | 8h+ | ✅ |
| 大重构 | ~~W12 snapshot_builder / controller 拆分~~ ✅ 闭环（轨道 B，2026-09-10，`fc7cb3e`；controller <900 未达，转后续债务） | P1-1 | P1 | 12h+ | ✅ |
| 死代码 | W13 school_rules 删除（遗留 P5） | 工单2 | P2 | 1h | W11 同批 |
| 观察项 | W14 audio randi 豁免说明 | P3-1 | P3 | 0.2h | 随手 |

**排序原则**：先止损失（W1/W2 阻止仓库与包体继续恶化）→ 再铺安全网（W4 是一切大改的前置）→ 最后动刀（W11/W12）。

---

## 2. 工单卡

### W1 导出隔离 —— 立刻执行，性价比最高

- **负责人**：任一 AI 会话
- **时间**：D0，0.5h
- **措施**
  1. 在 `build/`、`.preview/`、`.superpowers/`、`.workbuddy/`、`.claude/` 各放一个空 `.gdignore` 文件
  2. `export_presets.cfg` 两个 preset（Windows / Android）的 `exclude_filter` 追加：`battle_screenshot*.png, encounter_screenshot*.png, ending_screenshot*.png, map_screenshot*.png, reference_*.png, memory/*`
  3. 根目录 12 张开发截图移入 `docs/screenshots/`（`docs/*` 已被排除）——**同步修正 png.import 的引用路径**或直接删 import 让 Godot 重生成
- **风险与应对**：截图被场景引用？已核实 0 引用（纯开发留档）；`.gdignore` 导致某目录其实需要打包？已核实 5 处目录均为纯开发产物
- **验收标准**
  - [ ] `find . -maxdepth 2 -name ".gdignore"` 命中 build/.preview/.superpowers/.workbuddy/.claude
  - [ ] `grep -c "battle_screenshot" export_presets.cfg` ≥ 1
  - [ ] `tools/test.ps1 -Suite unit` 中 `test_export_presets_exclude_filter` 保持绿
- **验证方法**：上述三条命令 + `git status` 确认移动的截图成对出现（删旧增新）
- **交付物**：1 个提交（`.gdignore` ×5 + export_presets + 截图迁移）

### W2 停止跟踪构建产物

- **负责人**：任一 AI 会话（**需用户知悉**：产物此后不经 git 分发）
- **时间**：D1，1h
- **前置**：W1 已合入；`git ls-remote` 确认与远端同步；确认无并行会话正在提交
- **措施**
  1. `git rm --cached build/android/gu-zhenren.apk build/android/gu-zhenren-signed.apk build/win/gu-zhenren.exe.part1 build/win/gu-zhenren.exe.part2`
  2. `.gitignore`：删除 `!build/win/*.part*` 与 `!build/android/*.apk` 两行放行，保留 `build/*` 忽略
  3. `git gc --aggressive --prune=now` 回收松弛对象（**注意**：只做 gc，绝不 `filter-branch`/`filter-repo`——历史里的 460M 存量保留，重写历史风险不可接受）
  4. 若用户仍需 git 内分发：另开工单启用 git-lfs（本机 3.7.1 已装未启用），存量 blob 不迁移
- **风险与应对**：gitee 有单文件/容量限制 → 停止跟踪后不再恶化；`gc` 中断导致锁残留 → 删 `.git/gc.pid` 重试；视觉会话同时打包推送 → 前置检查 mtime
- **验收标准**
  - [ ] `git ls-files build/ | wc -l` = 0
  - [ ] `git check-ignore build/win/gu-zhenren.exe.part1` 有输出
  - [ ] `git ls-remote origin refs/heads/master` = 本地 HEAD
- **验证方法**：上述三条；另记录 gc 前后 `du -sh .git` 对比（预期首次仅小幅下降，增量停止恶化即达标）
- **交付物**：1 个提交 + gc 执行记录（写入工单回执）

### W3a 项目 LICENSE

- **负责人**：**用户拍板许可类型** → AI 会话 10 分钟落地
- **时间**：D1
- **措施**：用户选定（MIT / 专有 / 其他）→ 根目录放 `LICENSE` → README 补声明段
- **验收标准**：根目录存在 LICENSE；README 有一节说明项目许可与第三方许可的关系
- **交付物**：1 个提交

### W3b 游戏内「关于」署名界面

- **负责人**：AI 会话（UI 实现走视觉会话线框流程则由其承接）
- **时间**：D4，3h
- **前置**：W3a 完成
- **措施**
  1. 设置屏或标题屏增加「关于」入口，内容含：game-icons.net（CC BY 3.0 + 作者 + 链接）、GUT / dialogue_manager / ReactiveUI Toolkit / beckett / GDQuest Open RPG（各自许可与 URL，取自 CREDITS.md）
  2. 加守门断言：`assets/wenzhen/icons/game-icons/` 非空 ⇒ 关于屏文本必须含 "game-icons" 与 "CC BY"（新测试 `test_about_attribution.gd`）
- **风险与应对**：AGENTS 要求 UI 改动真窗键鼠验收 → 交互部分标注「headless 断言过，真窗验收待用户」，列入验收遗留
- **验收标准**：新守门测试绿；unit 全量无新增红
- **交付物**：关于屏 + 1 个守门测试 + 1 个提交

### W4 快照契约测试（一切大改的安全网）

- **负责人**：任一 AI 会话
- **时间**：D3，4h
- **措施**
  1. 新建 `tests/unit/test_snapshot_contract.gd`：按屏幕枚举必备快照键（从 `docs/contracts/2026-09-02-domain-ui-contract.md` 提取清单），断言存在性 + 类型 + 取值域
  2. 契约文档是活文档：发现键缺失/多出时**先改契约再改测试**（AGENTS 契约优先）
  3. 参考既有范式：断言不硬编码数值基线，从 catalog 取
- **风险与应对**：`run_snapshot_builder.gd` 2372 行，逐屏枚举工作量大 → 首版只覆盖 5 个主屏（hall/map/battle/rest/shop）的核心键，渐进补全
- **验收标准**：新测试对当前代码**一次通过**（它是安全网不是红灯）；unit 全量绿
- **验证方法**：`-gtest=res://tests/unit/test_snapshot_contract.gd` + 全量
- **交付物**：测试文件 + 契约文档查漏补缺（如有漂移一并修）+ 1 个提交
- **注意**：W12（拆分）未获本测试保护前不得开工

### W5 开新局重复加载实测与修复

- **负责人**：任一 AI 会话
- **时间**：D2，1h
- **措施**
  1. **先实测**：headless 计时 `start_new_run` 全程与其中 `load_and_validate_all()` 耗时（`Time.get_ticks_msec()`），写进工单回执
  2. 耗时 < 200ms：不改代码，只在 `run_controller.gd:180` 加注释记录实测值，工单关闭
  3. 耗时 ≥ 200ms：启动加载结果缓存为静态字典，`start_new_run` 复用；保留 `force_reload` 参数；跑全量回归
- **风险与应对**：缓存导致热重载失效 → force_reload 参数兜底；`meta.new_empty()` 等依赖 catalog 之外的东西不受影响（只缓存 catalog）
- **验收标准**：实测数据落档；若改码，unit + integration 全绿
- **交付物**：实测记录（+可选 1 个提交）

### W6 display_text 校验盲区

- **负责人**：任一 AI 会话
- **时间**：D5，2h
- **措施**
  1. `content_catalog.load_all()` 纳入 `names.json` 与 `gu_names.json`（带缓存字段沿用现有 `_names_loaded` 模式）
  2. `_validate_*` 补两文件的结构校验（必需键、类型）
  3. `display_text.gd` 改从 catalog 取，删除两处 `FileAccess` 直读
- **风险与应对**：`display_text` 有测试引用文件路径 → 同步改测试；加载顺序（catalog 在 display_text 首次调用前就绪）→ catalog 是启动即载，成立
- **验收标准**：`grep -rn "res://data/" scripts/presentation/` 0 命中；unit 全量绿
- **交付物**：1 个提交

### W7 map_generator fallback 告警

- **负责人**：任一 AI 会话
- **时间**：D5，0.5h
- **措施**：`map_generator.gd:24/30/41` 三处 `_load_json` fallback 分支加 `push_warning("map_generator bypassed catalog for " + path)`；确认现有测试不因此产生噪音（测试多走无 catalog 路径，必要时测试里临时静音该 warning）
- **验收标准**：unit 全量绿；警告触发路径仅限测试/工具
- **交付物**：1 个提交

### W8 契约漂移守门（含遗留 P4）

- **负责人**：任一 AI 会话
- **时间**：D5，2h
- **措施**
  1. 审计报告 §8 的 python 比对逻辑移植为 `tools/check_contract_drift.gd`（或 PowerShell 片段嵌入 check.ps1——**注意 commit message 里避免敏感词**，脚本文件名避开 psh 字样）
  2. 白名单：`test_command_rejections_v2`（契约里的测试名引用）等已核实的非命令项
  3. `tools/check.ps1` 末尾追加调用，命中即 exit 1
  4. 顺手处置真漂移项 `beastiality_endpoint_check`：查项目决策浓缩对话确认是废弃（删契约行）还是未实现（登记待办）
- **风险与应对**：白名单过宽会掩盖未来漂移 → 白名单逐项写注释说明豁免理由
- **验收标准**：`tools/check.ps1` exit 0；人为从契约删一个真命令名能变红（手工验证一次后还原）
- **交付物**：守门脚本 + check.ps1 接线 + 1 个提交

### W9 分支与忽略卫生

- **负责人**：任一 AI 会话
- **时间**：D1，0.5h
- **措施**
  1. `git branch -d "测试，用完就丢"` 前先 `git log 该分支 -3` 确认无未合入成果；有则先报用户
  2. `worktree-battle-visual-implementation` 属视觉会话在制品 → **不删**，只在分支列表标注归属
  3. `.gitignore` 追加 `.claude/`
- **验收标准**：`git check-ignore .claude` 有输出；临时分支已删或已标注
- **交付物**：1 个提交

### W10 continue_run 语义（✅ 已闭环：2026-09-10 视觉会话，方案甲，`158aef4`）

- **负责人**：**视觉会话**（AI 会话仅在回执中催办）
- **时间**：视觉会话下一工作时段
- **背景**：`run_snapshot_builder.gd:833` 把 Title 的 `primary_action` 定为「读档继续」，`run_command_builder.gd:103` 却接到 `_show_hall_subview("schools")`。需其定夺语义并接线，使 `test_map_exit_persistence` 回绿
- **验收标准**：unit 1100/1100 全绿
- **交付物**：1 个提交；交接文档 §5 第 1 条闭环
- **闭环记录**：方案甲落地——`continue_run` 经 `submit_command({"type":"load_run"})` 直读恢复；失败留原屏显拒绝文案；unit 1167 + integration 31 全绿；`verify_interaction_loop` 全屏 `dead=[]`；交接文档 §5 第 1 条已标闭环。真窗键鼠验收待办

### W11 resolver 拆分 + 基础动作表迁移（✅ 已闭环：轨道 A，2026-09-10，合入 `49ffbe5`）

- **负责人**：AI 会话，**独立 git worktree**（按项目纪律）
- **时间**：下一迭代，8h+
- **前置**：W4 已合入
- **措施**
  1. 先补 `tests/unit/test_v1_basic_actions.gd`：attack 2 / defense 3 / heal 2 / shift 1 / marked 1 / bound 1 逐项断言（**迁移前置，别裸迁**）
  2. `v1_battle_resolver.gd:23-28` 基础动作表迁 `data/*.json`（新键在 `_validate_balance.positive_keys` 登记）
  3. `resolver.gd`（2407 行）按命令族切分模块，主文件保留路由
  4. `school_rules.gd` 死代码删除（遗留 P5）随本工单同批：先确认 `is_soul` 那处外部引用
- **风险与应对**：V1 战斗是核心路径 → 每切一块跑全量 unit + integration；worktree 用完即 `git worktree remove`；数值迁 JSON 后断言从 catalog 取
- **验收标准**：`resolver.gd` < 1200 行；动作表在 JSON 且 catalog 校验覆盖；unit + integration 全绿；`git ls-remote` 校验推送
- **交付物**：独立分支串行提交，验收后合入 master
- **闭环记录**：分支 `chore/w11-resolver-split`（worktree `.worktrees/resolver-split`，A1–A7 用户批准 ff 合入后已 remove）。resolver.gd 2407→**205 行**（路由保留），命令族模块 `shop/refine/social/run_command_rules.gd` + `resolver_helpers.gd`；动作表已迁 `data/v1_battle.json`（措施 2，先补 `test_v1_basic_actions` 后迁）；M1 达标（resolver < 1200 ✓，unit + integration 全绿）

### W12 snapshot_builder / controller 拆分（✅ 已闭环：轨道 B，2026-09-10，合入 `fc7cb3e`）

- **负责人**：AI 会话，独立 worktree
- **时间**：W4 合入后逐屏推进，每屏 2-3h
- **措施**：`run_snapshot_builder.gd` 按屏切 builder（battle/map/rest/shop/refine），聚合入口保持；`run_controller.gd` 抽「视图挂载 / 命令分发 / 存档生命周期」三职责；每切一块跑 W4 契约测试 + 全量
- **风险与应对**：并行视觉会话同文件高冲突 → 每屏一个聚焦提交，拆分期间与视觉会话错峰；契约测试红即回滚该屏
- **验收标准**：单文件 < 1200 行；W4 契约测试绿；unit + integration 全绿
- **交付物**：串行聚焦提交
- **闭环记录**：分支 `chore-w12-snapshot-split`（worktree `.worktrees/snapshot-split`，B1–B9 用户批准 ff 合入后已 remove）。`run_snapshot_builder.gd` 2373→**767 行**（12 屏各自 `snapshots/*_snapshot.gd`）；controller 抽出 `run_save_flow.gd` / `run_debug_facade.gd` / `run_screen_router.gd`，主文件 1760→**1241 行**（<900 未达，`_show_*` 家族与命令构建转后续债务条目）；快照契约键零漂移（`test_snapshot_contract` 未改即绿）；master 合入后 `check.ps1` rc=0

### W13/W14 已并入 W11 / 随手

- W13（school_rules 删除）→ W11 第 4 步
- W14（audio randi）→ 任一会话在 `audio_manager.gd:100` 加注释「表现层音效变体，非玩法随机，豁免种子化约束」，并在 AGENTS 技术约定补一行豁免条款（0.2h）

---

## 3. 时间节点总览

```
D0（09-10）：W1 导出隔离
D1（09-11）：W2 停止跟踪 build + W3a LICENSE(用户拍板) + W9 卫生
D2（09-12）：W5 重复加载实测
D3（09-13）：W4 快照契约测试
D4（09-14）：W3b 署名界面
D5（09-15）：W6 + W7 + W8（架构收尾与守门）
下一迭代  ：✅ W11（轨道 A，`49ffbe5`）→ ✅ W12（轨道 B，`fc7cb3e`）✅ W10 随视觉会话（`158aef4`）——2026-09-10 全部闭环
```

里程碑判据：**D5 结束时** unit 应回到 1100/1100 全绿、`check.ps1` exit 0、`.git` 停止增长、Release PCK 无开发产物。

---

## 4. 全局风险登记

| 风险 | 概率 | 影响 | 应对 |
|---|---|---|---|
| 并行视觉会话同文件冲突 | 高 | 中 | 执行前查 `ls -lt scripts/presentation/screens/`；聚焦提交；大改走 worktree |
| `.git` 再次损坏 | 低 | **高** | 全程只用只读检查 + wincred 推送；禁 `stash`/`reset --hard`/重写历史；损坏按 MEMORY.md 既定流程恢复 |
| W4 契约测试写完即红 | 中 | 低 | 它是安全网：红=发现真漂移，先改契约文档再改代码，逐键消化 |
| W3b 真窗验收缺位 | 中 | 中 | headless 断言过 ≠ 交互可用（AGENTS 铁律），验收遗留项显式标注，等用户键鼠复验 |
| 导出测试与 W1 联动回归 | 中 | 低 | 改 exclude 必跑 `test_export_presets_exclude_filter`；断言方向 2026-09-09 刚对齐过（`4c3dccc`） |
| LLM 越权（若署名/文案引入生成文本） | 低 | 高 | 署名内容全部来自 CREDITS.md 静态文本，不接 LLM |

---

## 5. 验收与验证总则

1. **每张工单卡**：卡内验收清单逐项勾选 + 卡内验证命令原样执行贴回执
2. **每批合入后**：`tools/test.ps1 -Suite unit`（后台跑，约 2 分钟）+ `-Suite integration` + `tools/check.ps1` 三件套
3. **推送后**：`git ls-remote origin refs/heads/master` 必须等于本地 HEAD
4. **完成定义**：验收清单全勾 + 三件套绿 + 已推送 = 工单闭环，回写本文件 §1 总表状态
5. **禁止**：为让红灯变绿而改断言数值——要么消除硬编码改从配置取，要么证明断言过时并记录 `git log` 证据（先例：`4c3dccc`）

---

## 6. 状态回写区

| 工单 | 状态 | 执行会话 | 完成日期 | 提交 |
|---|---|---|---|---|
| W1 | ✅ 闭环 | 本会话 | 2026-09-09 | `d0ed0d2` |
| W2 | ✅ 闭环 | 本会话 | 2026-09-09 | `a4b5528` |
| W3a | ✅ 闭环（用户拍板 MIT） | 本会话 | 2026-09-09 | `6841333`（根 LICENSE + README 许可段；同人 IP 声明） |
| W3b | ✅ 闭环（守门补齐；关于界面本体为第 18 批既有产物） | 本会话 | 2026-09-09 | `9acc158`（test_about_attribution.gd：目录非空 + 源含 game-icons/CC BY）。真窗验收标注：headless 断言过，交互验收待用户（AGENTS 契约） |
| W4 | ✅ 闭环（首版） | 本会话 | 2026-09-09 | `04c389d`（Battle/Hall 契约 v2 待 state-advance 工具，见工单） |
| W5 | ✅ 闭环（实测 ~60ms < 200ms 阈值，**不改代码**） | 本会话 | 2026-09-09 | `89f0202`（计时工具落档） |
| W6-W8 | W6 ✅ W7 ✅ W8 ✅（2026-09-09 同批收口） | 本会话 | 2026-09-09 | W7+W8+契约拼写修正 `7772b58`；W6 `6aefc1e` + catalog 预热 `5bd9c1d`；W8 守门 python→GDScript 迁移 + beckett 导出隔离 `1a00ca5` |
| W9 | ✅ 闭环 | 本会话 | 2026-09-09 | `a4b5528`（含 .claude ignore + 删临时分支；远端同名分支已 `push --delete`） |
| W10 | ✅ 视觉会话闭环（方案甲） | 轨道 C | 2026-09-10 | `158aef4`（continue_run=读档继续；`test_map_exit_persistence` 直读直恢复；真窗验收待办） |
| W11 | ✅ 闭环（措施 1/2/4 + 措施 3=轨道 A） | 本会话 / 轨道 A | 2026-09-10 | `6753065`+`10122fb`（m1/2/4）；轨道 A 分支 `chore/w11-resolver-split` 合入 `49ffbe5`（resolver 2407→205 行，M1 达标） |
| W12 | ✅ 闭环（轨道 B，M2 达标；controller <900 转后续债务） | 轨道 B | 2026-09-10 | 分支 `chore-w12-snapshot-split` 合入 `fc7cb3e`（builder 2373→767 行；controller 1760→1241 行） |
| W13 | ✅ 并入 W11 措施 4（2026-09-09） | 本会话 | 2026-09-09 | `10122fb`。**审计误判修正**：school_rules.gd 整体非死——`is_soul` 被 relic_hook_resolver 真用；真死仅 3 个零引用函数（drain_blood_stacks/overchannel_benefit/apply_overchannel_soul，overchannel 规则在 V1 无实现） |
| W14 | ✅ 闭环 | 本会话 | 2026-09-09 | `d322387`（audio_manager.gd:100 豁免注释 + AGENTS 技术约定补种子化豁免条款） |

> **执行事故记录（2026-09-09）**：W2 的 `git gc` 后台执行期间 .git 被外部进程整目录清空（第 5 次损坏，只剩 1K 空壳）。已按 MEMORY.md 六步恢复流程重建：mv 取证 → init → fetch（296M 对象完整）→ FETCH_HEAD 取 sha → update-ref 双引用 → 恢复 git 身份 → add -A + plain reset 对齐。HEAD 与 `ls-remote` 均为 `89f0202`。`.git.broken-20260909-223844/` 空壳（1K，无 pack）保留待用户确认删除。

> **守门平台坑（2026-09-09，已固化到代码注释）**：check.ps1 不可依赖 `python`——Windows App Execution Alias 下 PS 解析到 Microsoft Store stub，`python` 调用必失败致整脚本 exit 1。契约漂移守门（W8）重写为 `tools/check_contract_drift.gd`（`extends SceneTree`，经 godot.ps1 headless 调用），与既有探针同一调用路径。审计 P0 遗留 addons/beckett/（第三方编辑器插件，untracked）已同步 `.gitignore` + 双 preset exclude_filter 隔离（`1a00ca5`）。
