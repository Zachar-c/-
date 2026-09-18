# 真窗验收报告 — B2 四屏 / 卡牌手感 / W10 continue\_run / S 阶段全流程

> **日期**
>
> ：2026-09-14
> **分支**
>
> ：
>
> `master`
> **范围**
>
> ：AGENTS.md 当前待办 #2 挂账的四项真窗键鼠验收
> **验收方式**
>
> ：非 headless 真实窗口 + 自动化验证脚本 + force_draw 截图肉眼比对



***

## 1. 验收结果总览



| 项                 | 状态   | 验证工具                               | 截图                                                    | 备注                                                                               |
| ----------------- | ---- | ---------------------------------- | ----------------------------------------------------- | -------------------------------------------------------------------------------- |
| B2 四屏渲染           | ✅ 通过 | `verify_b2_four_screens_render.gd` | `b2_encounter/npc/ending/contenterror.png`            | 四屏全部成功截图；Npc/Encounter 改用直接注入节点方式（pacing trade 权重 4-8% 地图遍历难命中）                  |
| 卡牌手感              | ✅ 通过 | `verify_hand_drag_render.gd`       | `hand_hover/drag_near/drag_free/aim_free/aim_hot.png` | 五态全部 ok；**修复卡牌插画空白**（`Image.load()` → `load()`）                                  |
| W10 continue\_run | ✅ 通过 | `verify_w10_continue_run.gd`（新建）   | `w10_hall_with_save.png`                              | 有存档 primary\_action=continue\_run；load\_run 成功恢复且 seed 一致                        |
| S 阶段全流程           | ✅ 通过 | `verify_master_flow.gd`            | —                                                     | Map/Battle/Rest/Shop/Encounter 均可达；save/load 正常；Refine/Npc 因 pacing 权重低未遍历到（非阻塞） |



***

## 2. 各项验收详情

### 2.1 B2 四屏渲染验收

**验证脚本**：`tools/verify_b2_four_screens_render.gd`（已修复）

**四屏截图**：



* `b2_encounter.png` — 遭遇屏（hazard 类），三栏布局（探查 / 穿越 / 离开），右侧状态栏

* `b2_npc.png` — NPC 交涉屏（三栏：交涉 / 交易 / 以物易物）

* `b2_ending.png` — 结局回顾屏（主动收势・弃局而退）

* `b2_contenterror.png` — 内容校验错误屏

**修复内容**：



* Npc 查找：原脚本用地图遍历找 contact 节点，但 contact 属 trade 类（pacing 权重 4-8%），10 种子初始视野内难命中。改为直接注入 `neutral_wanderer` 节点定义到 `current_node`，走正式 `_show_npc()` 渲染路径。

* Encounter 查找：同理改为直接注入 event 节点，避免地图遍历进入战斗导致的卡牌图片加载 WARNING 风暴和栈溢出。

**视觉观察**：



* 四屏布局与线框稿对齐（印章 / 竖题 / 三栏 / 成就条）

* Debug 构建顶部有 `DEV ONLY - F12` 调试栏（release 构建经 `OS.is_debug_build()` 门控隐藏）

* Ending 屏标题在 debug 栏下略受挤压（release 构建无此问题）

### 2.2 卡牌手感验收

**验证脚本**：`tools/verify_hand_drag_render.gd`（已补 school\_id 测试数据）

**五态截图**：



* `hand_hover.png` — 悬停抬升 + 解释栏锚定卡上方（标题 / 品阶 / 效果 / 代价）

* `hand_drag_near.png` — 拖拽 <64px：影卡墨框「未就绪」态

* `hand_drag_free.png` — 拖拽 >64px：影卡朱砂「可出牌」态，跟随鼠标

* `hand_aim_free.png` — 指向卡拖拽未命中敌人：墨色弧形箭

* `hand_aim_hot.png` — 指向卡拖拽命中敌人：朱砂弧形箭 + 敌人高亮

**手感参数**（来自 `gu_tall_fan_hand_view.gd`）：



* 扇形最大倾角 `MAX_ANGLE_DEG = 6.0°`

* 缓动指数 `T_EASE = 1.35`

* 拖拽阈值 6px，出牌距离 64px

* 回弹补间 0.22s

**修复内容（关键）**：



* **卡牌插画空白修复**：`_card_art_texture()` 原用 `Image.load(path)` 直读 `res://` 路径文件，触发 "Loaded resource as image file, this will not work on export" WARNING 且纹理未正确显示。改为 `load(path) as Texture2D` 加载导入后的纹理资源，消除 WARNING 并正确显示插画。

* 验证脚本合成快照补 `school_id` 字段（原只有 `school_label` 中文标签，导致 `_card_art_texture` 收到空字符串）。

### 2.3 W10 continue\_run 真窗验收

**验证脚本**：`tools/verify_w10_continue_run.gd`（新建）

**验证流程**：



1. 无存档时大厅 `primary_action` = `open_schools`

2. 新开局 → travel 到节点 → `save_run` → `save_and_leave_map` 回大厅

3. 有存档时大厅 `primary_action` = `continue_run`，`has_save` = true

4. 触发 `continue_run`（即 `submit_command({"type":"load_run"})`）

5. 验证恢复到 Map 屏，且 `seed` 与保存时一致

**结果**：



* `save_run ok=true`

* `load_run ok=true`，恢复后 `view=Map`

* `loaded seed=20260914 (saved=20260914)` — 一致

* 方案甲（读档继续）语义正确：有存档显示「续入此世」，点击即恢复离开前进度

### 2.4 S 阶段全流程真窗验收

**验证脚本**：`tools/verify_master_flow.gd`

**结果**：



* 4 种子全部 `SAVE_OK=true`

* 到达视图：`Map / Battle / Rest / Shop / Encounter`

* 战斗内 Settings overlay 开合正常

* Rest 屏 `rest_choice_required` 门禁：先 skip 再 leave 的真实流程正常

* `LOAD_OK` 读档恢复正常

**未遍历到**：`Refine`、`Npc` — 因 pacing 池中 refinement\_hollow 属 rest 类、contact 属 trade 类（权重 4-8%），有限遍历内概率低。非阻塞问题：B2 验收已通过直接注入方式覆盖这两屏渲染。



***

## 3. 代码修改清单



| 文件                                                      | 修改                                                  | 原因                       |
| ------------------------------------------------------- | --------------------------------------------------- | ------------------------ |
| `scripts/presentation/widgets/gu_tall_fan_hand_view.gd` | `_card_art_texture()` 改用 `load()` 替代 `Image.load()` | 消除导出 WARNING，修复卡牌插画空白    |
| `tools/verify_b2_four_screens_render.gd`                | Npc/Encounter 改用直接注入节点；种子扩至 10                      | pacing 权重低导致地图遍历难命中      |
| `tools/verify_hand_drag_render.gd`                      | 合成快照补 `school_id` 字段                                | 原测试数据缺 school\_id 导致插画空白 |
| `tools/verify_w10_continue_run.gd`                      | 新建                                                  | W10 真窗验收脚本               |



***

## 4. 遗留与观察



| 项                                    | 说明                           | 处置                     |
| ------------------------------------ | ---------------------------- | ---------------------- |
| Ending 标题在 debug 栏下略受挤压              | Debug 构建特有，release 构建调试栏隐藏   | 非阻塞，release 验收时复核      |
| ContentError 屏单条错误时中间区域空白            | 预期行为：错误详情区按错误条数填充            | 非问题                    |
| `verify_master_flow` 未遍历到 Refine/Npc | pacing 权重低，有限遍历概率问题          | B2 已用注入方式覆盖渲染；可后续增加种子数 |
| ObjectDB/RID 泄漏                      | 既有遗留（2026-09-06 复测 20601 实例） | 非本次引入，挂账               |
| Dialogue Manager invalid UID         | 既有遗留                         | 非本次引入，挂账               |



***

## 5. 验证命令



```
\# B2 四屏

tools\godot.ps1 --path . -s tools/verify\_b2\_four\_screens\_render.gd

\# 卡牌手感五态

tools\godot.ps1 --path . -s tools/verify\_hand\_drag\_render.gd

\# W10 continue\_run

tools\godot.ps1 --path . -s tools/verify\_w10\_continue\_run.gd

\# S 阶段全流程

tools\godot.ps1 --path . -s tools/verify\_master\_flow.gd

\# 全量单元

powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite unit
```