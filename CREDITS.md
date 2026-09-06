# 开源素材与第三方资源署名

本项目使用以下开源素材与第三方资源，均遵循各自许可证条款。

## 图标

### game-icons.net
- **来源**: https://game-icons.net/
- **许可证**: CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/)
- **作者**: 多位作者（lorc, delapouite, carl-olsen 等）
- **使用范围**: `assets/wenzhen/icons/game-icons/` 目录下 53 个 SVG 图标
- **图标列表**:
  - 蛊虫类: spider, snake, toad, moth, centipede, beetle, scorpion, insect, leech, worm
  - 状态类: poison, curse, shield, fire, skull, blood, eye
  - 资源/动作类: coin, potion, scroll, soul, sword, fist, run, mask
  - 宝石/生命/魂魄类（第16批新增）: gem_pendant, ball_heart, crystal_cluster, concentration_orb, crown, beveled_star, hourglass, key, locked_chest, lotus_flower
  - 动作/元素类（第16批新增）: battle_axe, feather, leaf_swirl, sun, moon
  - 状态/情感类（第16批新增）: bleeding_heart, broken_heart, cursed_star, burning_eye, beast_eye, bone_knife, spider_web
  - 界面/传说类（第16批新增）: book_cover, scroll_unfurled, bookmark, feathered_wing, dragon_head
- **署名要求**: CC BY 3.0 要求在游戏内「关于」界面署名，光放许可证文件不够。本文件为项目级署名记录，游戏内署名界面待实现。

## 自绘素材

### 问眞命簿图标集
- **来源**: 本项目程序化自绘（线性描边，24 viewBox，4x 导入 = 96px）
- **许可证**: 项目自有
- **使用范围**: `assets/wenzhen/icons/` 目录下 `ic_*.svg` 文件
- **图标列表**:
  - 资源: yuanstone（真元石）, shouyuan（寿元）, hunpo（魂魄）, material（蛊材）
  - 战斗: health（生命）, attack（攻击）, shield（护盾）, dodge（闪避）
  - 蛊虫: insect（蛊虫）, poison（毒）, bone（骨）, flame（火）
  - 状态: curse（诅咒）, seal（封印）, warning（警告）, danger（危险）, death（死亡）
  - 界面: close（关闭）, check（确认）, settings（设置）, scroll（卷轴）, codex（图鉴）, map（地图）

## 美术资产

### 青茅山背景图
- **来源**: AI 生成（豆包 AI）
- **使用范围**: `assets/wenzhen/hall/qing-mao-mountain.png`
- **状态**: 项目自有，含 AI 生成水印

### 主角立绘
- **来源**: AI 生成（豆包 AI）
- **使用范围**: `assets/wenzhen/hall/first-life-character.png`
- **状态**: 项目自有，含 AI 生成水印

### 蛊虫插画（5 张）
- **来源**: AI 生成（seedream）
- **使用范围**: `assets/wenzhen/gu/` 目录
- **图标列表**: gu_blood（血蛊）, gu_light（光蛊）, gu_bone（骨蛊）, gu_poison（毒蛊）, gu_moon（月蛊）
- **状态**: 项目自有

### 敌人立绘（4 张）
- **来源**: AI 生成（seedream）
- **使用范围**: `assets/wenzhen/enemies/` 目录
- **图标列表**: enemy_sanxiu（散修）, enemy_toad（毒蟾）, enemy_moth（尸蛾）, enemy_centipede（骨蜈蚣）
- **状态**: 项目自有

### NPC 立绘（1 张，暂缓接入）
- **来源**: AI 生成（seedream）
- **使用范围**: `assets/wenzhen/npc/npc_merchant.png`
- **状态**: 已生成，因用户要求"多使用开源免费库，少使用 AI 生成"而暂缓接入

## 第三方代码

### GDQuest Open RPG
- **来源**: https://github.com/GDQuest/godot-open-rpg
- **许可证**: MIT
- **使用范围**: `vendor/godot-open-rpg/` 目录（未经审计不得直接耦合或修改）
- **状态**: 引入时保留 MIT 许可证、上游 URL 和固定提交号

### GUT (Godot Unit Test)
- **来源**: https://github.com/bitwes/Gut
- **许可证**: MIT
- **使用范围**: 单元测试框架
- **状态**: 项目依赖

## 待办

- [x] 游戏内「关于」界面实现 game-icons.net CC BY 3.0 署名（2026-09-06 第18批：设置界面→显示与声音→关于本游戏）
- [ ] 寻找开源角色立绘库替代 AI 生成 NPC 立绘
- [ ] 引入更多开源图标覆盖 UI 元素（按钮/标签/状态等）
