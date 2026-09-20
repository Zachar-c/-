# 《问真》视觉 v2.0 · Structure Reuse Inventory

```yaml
STATUS: READY_FOR_REVIEW
TYPE: READ ONLY INVENTORY
SCOPE: 快速结构验证前的现有资产、开源资源与组件盘点
NOT_SCOPE: 新视觉风格验证
NON_GOAL: 生图、生产资产、改游戏代码、改数值
PRIORITY: LOW / NOT MAINLINE
```

## 一、结论

本轮结构验证不需要先做逐只蛊虫正式美术资产。

但本件不是当前视觉线的最高优先级。当前必须先完成视觉定位决策；本盘点只作为 A 轨低成本备用材料。

工程内已经足够支撑一次结构验证：

```text
现有资源够用
→ 直接做单屏结构验证
```

当前默认产出：

```text
A 轨图像生成量 = 0
B 轨图像生成量 = 单样本 POC，且仅在视觉定位冻结并通过 L1 Prompt 审查后
游戏代码改动 = 0
结构验证面 = 大厅 → 图鉴 → 蛊
B 轨视觉验证 = VISUAL BIBLE CANDIDATE / BLOCKED_ON_L0_VISUAL_BIBLE_DECISION
```

本条必须先说清：

```text
旧素材可复用 ≠ 旧风格仍然成立。
旧素材只能证明界面结构能承载信息，不能证明调研后的新视觉方向成立。
```

## 二、可用于结构验证的资产

### 蛊图

| 资源 | 数量 | 位置 | 登记/许可 | 复用判断 |
| --- | ---: | --- | --- | --- |
| 蛊主题图 | 14 | `game/assets/wenzhen/gu/` | 项目自有 AI 图，未逐项写入 `assets_manifest.json` | 可做结构占位；不得作为新风格样本 |

已存在文件：

```text
gu_blood / gu_bone / gu_earth / gu_fire / gu_force / gu_light / gu_moon
gu_poison / gu_qi / gu_refine / gu_sword / gu_thunder / gu_water / gu_wind
```

风险：

```text
这批图属于旧视觉线。若调研已更换视觉风格，它们只能当占位，不能再作为正式风格锚点。
```

### 图标

| 资源 | 数量 | 位置 | 许可证 | 复用判断 |
| --- | ---: | --- | --- | --- |
| game-icons | 52 | `game/assets/wenzhen/icons/game-icons/` | CC BY 3.0 | 可做结构占位；需保留游戏内署名 |
| 自绘 `ic_*` | 23 | `game/assets/wenzhen/icons/` | 项目自有 | 可做结构占位；是否继承旧视觉由 L0/L1 决定 |

现有映射入口：

```text
game/scripts/presentation/widgets/gu_icon_view.gd
```

### 字体与纹理

| 资源 | 位置 | 许可状态 | 复用判断 |
| --- | --- | --- | --- |
| 霞鹜致宋 | `game/assets/wenzhen/fonts/LXGWZhiSongCL-Regular.ttf` | IPA Font License 1.0；manifest 标为用户授权非商业 | 可做结构占位；正式商业资产前必须重新核许可；不得默认继承到新风格 |
| 马善政楷书 | `game/assets/wenzhen/fonts/MaShanZheng-Regular.ttf` | OFL 1.1 | 可做结构占位；不得默认继承到新风格 |
| 纸纹 | `game/assets/wenzhen/textures/paper_texture.png` | texturize royalty-free | 可做旧线占位；若视觉已换代，不得作为新风格材质依据 |
| 印泥纹 | `game/assets/wenzhen/textures/seal_ink_texture.png` | texturize royalty-free | 可做旧线占位；若视觉已换代，不得作为新风格材质依据 |

### UI 组件

| 组件 | 位置 | 可验证内容 |
| --- | --- | --- |
| 蛊卡 | `game/scenes/ui/widgets/gu_card.tscn` / `game/scripts/presentation/widgets/gu_card_view.gd` | 名称、品质、费用、插画、描述、内容槽；组件结构可验证，外观可替换 |
| 面板 | `game/scenes/ui/widgets/gu_panel.tscn` / `game/scripts/presentation/widgets/gu_panel_view.gd` | 章节标题、内容分区；组件结构可验证，外观可替换 |
| 图标 | `game/scenes/ui/widgets/gu_icon.tscn` / `game/scripts/presentation/widgets/gu_icon_view.gd` | 资源、状态、虫形占位；不等于新图标体系 |
| 战斗长卡 | `game/scripts/presentation/widgets/gu_tall_fan_hand_view.gd` | 交互与布局可验证；旧蛊图只做占位 |
| 主题 token | `game/scripts/presentation/gu_style.gd` | 纸、墨、朱砂等旧线 token；不得作为新风格依据 |
| 按钮主题 | `game/scripts/presentation/wenzhen_master_theme.gd` | 按钮态、点击音、hover 缩放；外观可替换 |

### 现有屏

| 屏幕 | 复用价值 | 判断 |
| --- | --- | --- |
| 大厅图鉴 | 已列蛊条目，使用 `GuCardScene`，数据含转数/流派/效果/解锁态 | 最适合首个结构验证切片 |
| 商店 / 奖励 | 已使用 `GuCardScene` 展示货品或奖励 | 可作第二验证面 |
| 战斗手牌 | 已按流派映射蛊图，组件较重 | 暂不作为首个验证面 |
| 炼蛊屏 | 已表达配方、代价、失败率、产物 | 可验证组合与代价，但不是双层外观首选 |
| Web 原型 | 有真实 Edge 无头截图循环 `game/wenzhen-web/tools/drive.mjs` | 可作一次性格外验证，不替代 Godot 主线 |

## 三、开源可补

只在验证真的需要时考虑：

| 缺口 | 首选替代 | 条件 |
| --- | --- | --- |
| 通用节点图标 | 现有 game-icons 染色 | 已有映射表，不新增生图 |
| 通用状态徽记 | 现有 game-icons + `apply_seal` | 先复用，不做定制 |
| 纸/印泥/卷轴边框 | CC0 纹理或 SVG 边框 | 必须登记许可证 |
| 占位角色或敌人 | CC0 / CC BY 开源素材 | 仅验证用途；不得污染正式 canon |

## 四、可能需要新资产

以下不进入本轮默认范围：

| 项目 | 为什么暂不做 | 触发条件 |
| --- | --- | --- |
| 逐只蛊虫本体图 | 802 条蛊无法在验证阶段批量做 | 单屏验证证明组件承载不足 |
| 高完成度主题皮肤 | 属于正式生产，不属于原则验证 | L0/L1 明确选择单个对象 |
| 专属敌人 / NPC / 场景 | 不能帮助验证双层体系 | 另行立项 |
| 新视觉系统 | 先证明现有组件不能表达 | 现有组件路线失败 |

## 五、最快验证切片

推荐：

```text
大厅 → 图鉴 → 蛊（仅结构验证）
```

验证同一条目能否清楚显示：

```text
本体形态：世界真实存在的蛊
主题外观：玩家收藏/切换的幻想表达
```

这里只验证界面能不能讲清两层关系。

这里不验证：

```text
新视觉风格是否成立
旧水墨 / 纸面 / 朱砂是否延续
新材质、新光感、新角色化方向是否正确
```

允许的最小改动顺序：

1. 先只改文案、标签或现有组件组合；
2. 再改 `GuCardView` 的本地内容槽；
3. 最后才考虑新增字段、命令或独立屏。

不需要：

- 新生成月亮少女；
- 新生成逐只蛊图；
- 新做图鉴系统；
- 新做资产管线；
- 改数值、能力、配方或世界关系。

新风格验证另开，前提是：

```text
L1 视觉定位 / L0 选择已经提供方向
+ L1 已审查并确认最终 Prompt
+ GPT Image 单样本
+ 通过后才允许下一个样本
```

新风格验证不得复用旧素材做判断样本。

## 六、风险与不一致

- `CREDITS.md` 说 game-icons 为 53 个，实际目录与 manifest 为 52 个；正式交付前应统一。
- `CREDITS.md` 与游戏内关于文本对自绘图标数量的口径不一致；正式交付前应统一。
- 14 张蛊图已在工程中，但未逐项进入 `assets/wenzhen/assets_manifest.json`；若进入正式资产池，应补登记。
- `LXGWZhiSongCL-Regular.ttf` 的 manifest 状态是用户授权非商业；商业化前必须重核。
- 旧 `docs/art/AI-ART-PROMPTS.md` 记录的是旧资产阶段，不应作为本轮生图任务单。
- 如果调研已经更换视觉风格，旧 `wenzhen-visual-style` 只能作为旧线实现参考，不得作为新线权威。

## 七、Review 结论

```text
REVIEW STATUS: PASS WITH FOLLOW-UP

当前证据足够支撑：
1. 不生成新图，先做单屏结构验证；
2. 首个结构验证面选大厅图鉴；
3. 只复用现有蛊图、图标、卡片和面板做占位；
4. 旧素材不得作为新视觉风格的验收样本；
5. 风格验证必须等 L1 视觉定位 / L0 选择后另开最小切片。
```
