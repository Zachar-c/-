# 背景音乐素材（第二批A-F-05）

## 目录说明

本目录存放游戏背景音乐，按场景分类。音乐文件统一使用 OGG 格式（循环播放友好）。

## 场景音乐清单

| 场景 | 文件名 | 风格 | 状态 |
|---|---|---|---|
| 大厅 | `hall.ogg` | 清雅古风，命簿纸面 | ⏳ 待引入 |
| 地图 | `map.ogg` | 悠远探索，南疆山水 | ⏳ 待引入 |
| 战斗 | `battle.ogg` | 紧张压迫，洞窟战斗 | ⏳ 待引入 |
| BOSS战 | `battle_boss.ogg` | 激烈决战，高潮 | ⏳ 待引入 |
| 休整 | `rest.ogg` | 放松神秘，篝火休憩 | ⏳ 待引入 |
| 交易 | `shop.ogg` | 市井繁华，黑市交易 | ⏳ 待引入 |
| 炼蛊 | `refine.ogg` | 诡异神秘，炼蛊炉鼎 | ⏳ 待引入 |
| 遭遇 | `encounter.ogg` | 悬疑紧张，事件触发 | ⏳ 待引入 |
| 结算 | `ending.ogg` | 苍凉悠远，结局回顾 | ⏳ 待引入 |

## 开源音乐来源推荐

### 1. OpenGameArt（推荐）
- 网址：https://opengameart.org/
- 许可证：CC0 / CC BY / CC BY-SA
- 搜索关键词：`ancient chinese`, `oriental`, `asian`, `ambient`, `calm`, `battle`, `mystical`
- 推荐作者：
  - **Matthew Pablo** - 多首东方风格背景音乐
  - **Brandon75689** - 古风/亚洲风格音乐
  - **Alexandr Zhelanov** - 环境/战斗音乐
  - **TAD** - 多首免费游戏音乐

### 2. Freesound
- 网址：https://freesound.org/
- 许可证：CC0 / CC BY / CC BY-NC
- 搜索关键词：`chinese ambient`, `guzheng`, `erhu`, `bamboo flute`, `cave ambience`
- 注意：需注册账号下载

### 3. Kenney（音效为主，音乐较少）
- 网址：https://kenney.nl/assets
- 许可证：CC0
- 推荐包：`Music Pack`（如果有）
- 注意：需通过浏览器手动下载（直接下载URL可能返回HTML错误页）

### 4. YouTube Audio Library
- 网址：https://studio.youtube.com/channel/UC-9-kyTW8ZkZNDHQJ6FgpwQ/music
- 许可证：免费可商用
- 搜索关键词：`Chinese`, `Asian`, `Oriental`, `Cinematic`, `Ambient`

### 5. 魔音网/Musopen（古典音乐）
- 网址：https://musopen.org/
- 许可证：公共领域
- 适合：结算/结局场景的苍凉悠远感

## 音乐系统使用方式

```gdscript
# 播放音乐（淡入1秒）
AudioManager.play_music("battle", 1.0)

# 停止音乐（淡出1秒）
AudioManager.stop_music(1.0)

# 交叉淡入淡出切换音乐（1.5秒）
AudioManager.crossfade_music("rest", 1.5)

# 设置音乐音量（0.0-1.0）
AudioManager.set_music_volume(0.6)

# 检查音乐文件是否存在
if AudioManager.has_music("battle"):
    AudioManager.play_music("battle")
```

## 技术说明

- 音乐播放器使用单独的 `AudioStreamPlayer`，与音效玩家池分离
- 所有音乐默认循环播放（`AudioStreamOggVorbis.loop = true`）
- 淡入淡出通过 `Tween` 动画实现，平滑过渡
- 单播放器实现交叉淡入淡出（先淡出再淡入），如需真正同时播放的交叉淡入淡出需要双播放器
- 音乐文件尚未引入时，`play_music()` 静默失败，不打断游戏流程

## 待办

- [ ] 从 OpenGameArt 下载9首场景背景音乐
- [ ] 转换为 OGG 格式并设置循环点
- [ ] 在 `run_controller.gd` 中接入场景音乐切换
- [ ] 在 `CREDITS.md` 中记录音乐来源和许可证
