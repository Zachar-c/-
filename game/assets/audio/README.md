# 音效系统说明

## 概述

《问真》音效系统基于 `AudioManager` 单例管理，支持音效播放、音量控制和资源池管理。

## 架构

- **音效管理器**：`scripts/audio/audio_manager.gd`（单例）
- **音效目录**：`assets/audio/`（按类别分子目录）
- **音效注册表**：`AudioManager.SFX_REGISTRY` 常量（音效ID → 文件路径映射）

## 音效类别

| 目录 | 类别 | 音效示例 |
|---|---|---|
| `ui/` | UI交互 | click, hover, confirm, cancel, error |
| `battle/` | 战斗 | hit, critical, miss, death, card_play, status_apply |
| `refine/` | 炼蛊 | success, fail, curse |
| `env/` | 环境 | cave_ambient, wind, fog |
| `concept/` | 概念层 | seal_stamp（朱砂盖印）, ink_spread（墨迹扩散）, text_strike（文字划除） |

## 使用方式

```gdscript
# 播放音效（默认音量）
AudioManager.play_sfx("ui_click")

# 播放音效（指定音量缩放）
AudioManager.play_sfx("battle_hit", 0.8)

# 播放音效（指定音量和音调）
AudioManager.play_sfx("battle_critical", 1.0, 1.2)

# 设置音量
AudioManager.set_master_volume(0.5)  # 主音量 0.0-1.0
AudioManager.set_sfx_volume(0.8)     # 音效音量 0.0-1.0
AudioManager.set_music_volume(0.6)   # 音乐音量 0.0-1.0

# 停止所有音效
AudioManager.stop_all_sfx()

# 检查音效文件是否存在
if AudioManager.has_sfx("ui_click"):
    AudioManager.play_sfx("ui_click")
```

## 技术特性

- **对象池**：预创建8个AudioStreamPlayer，避免频繁创建销毁
- **静默失败**：音效文件不存在时静默失败，不打断游戏流程
- **音量控制**：主音量/音效音量/音乐音量三级控制
- **音调缩放**：支持pitch_scale参数，可用于音效变化（如暴击音调升高）

## 开源音效来源（待引入）

当前音效系统为基础架构，实际音效文件待从以下开源库引入：

### Freesound
- **网站**：https://freesound.org/
- **许可证**：CC0 / CC BY / CC BY-NC（需逐个确认）
- **推荐搜索**：UI click, battle hit, sword swing, magic spell, ambient cave

### OpenGameArt
- **网站**：https://opengameart.org/
- **许可证**：CC0 / CC BY / GPL（需逐个确认）
- **推荐搜索**：RPG sound effects, battle sounds, UI sounds

### Kenney
- **网站**：https://kenney.nl/assets
- **许可证**：CC0（完全免费，无需署名）
- **推荐包**：UI Audio, Impact Sounds, Music Loops

## 引入音效的步骤

1. 从开源库下载音效文件（推荐OGG格式，体积小质量好）
2. 放入对应类别目录（`assets/audio/<category>/`）
3. 在 `AudioManager.SFX_REGISTRY` 中注册音效ID和路径
4. 在游戏逻辑中调用 `AudioManager.play_sfx("<id>")`
5. 在 `CREDITS.md` 中记录音效来源和许可证

## 注意事项

- 音效文件推荐使用OGG格式（Godot原生支持，体积小）
- 避免使用MP3格式（专利问题，Godot支持有限）
- 音效文件大小控制在500KB以内（UI音效），环境循环音效可适当放大
- 引入音效时必须确认许可证，CC BY需要署名，CC0可自由使用
- 商业用途需避免CC BY-NC（非商业）许可证的音效
