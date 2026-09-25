# Figma 搭建计划（MCP 接入后执行）

> 前置：Figma MCP 可用（`use_figma` / `create_new_file` / `get_screenshot` / `get_metadata`）。  
> 严格执行 `generate-library.md` 分阶段 + 用户检查点；禁止一把梭。

## Phase 0 · Discovery
1. 新建 Design 文件：`Destiny Card Roguelike · DS`
2. 与用户确认 v1 范围（以 `00-OVERVIEW.md` + `COMPONENTS.md` 为准）
3. 锁定字体：检查 `Noto Serif SC` / `Noto Sans SC` 是否可 `loadFontAsync`；缺则备选 `Source Han` / `PingFang SC`

## Phase 1 · Foundations
1. Collections：`Primitives` / `Semantic` / `Spacing` / `Radius` / `Type Scale`
2. 按 `tokens.json` 写入变量 + scopes + code syntax
3. Text Styles：`display/d1·d2`、`ui/h·b·s·cap`、`num/*`
4. Effect Styles：`glow-gold` `glow-soft` `card-rest` `card-hover`
5. 检查点：截图色板页

## Phase 2 · File Structure
页面：`Cover` · `Getting Started` · `Foundations` · `---` · `Components` · `---` · `Screens` · `Flows`

## Phase 3 · Components（原子 → 分子，一次一个）
顺序：
1. Button + IconButton  
2. SegmentedControl · BackLink  
3. StatChip · ResourceBar  
4. Divider · Panel · Sheet · Toast · Dialog · Tooltip  
5. GuCard → KillMoveCard  
6. MapNode · TimelineStep  
7. IntentBadge  
8. TopBar · ActionDock  
9. ShopRow · SynthesisSlot  

每步：`combineAsVariants` → 属性绑定 → 文档区 → `get_metadata` + `get_screenshot` → 用户确认

## Phase 4 · Screens
按 `SCREENS.md` 01→08 用实例拼装（禁止画散件）。

## Phase 5 · Flows
用 FigJam 或 Design 页画 `FLOWS.md` 中 6 张图（或 `generate_diagram`）。

## Phase 6 · QA
- 对比度 / Focus / 命名 / 未绑定 fill 清扫  
- 八屏截图存 `docs/design/destiny-card-roguelike/figma-preview/`

## 本次状态
**MCP 未接入** → Phase 0–6 未在 Figma 执行；规格已齐，可直接按本计划开工。
