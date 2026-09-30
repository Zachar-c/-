# 网站窗口

> **问真 · 知识库**（深色 SPA）：知识库浏览 / 世界图谱 / 美术馆 / 审计模式。
> 与 ChatGPT Site `https://wenzhen-wiki-2026.czhmail2026.chatgpt.site/` 同源前端，本地用当前 Wiki 重建数据。

## 快速打开

```powershell
# 重建（Wiki 或美术变更后）
python lore\wiki\web\build_app.py

# 本地预览
python -m http.server 8877 --bind 127.0.0.1 --directory lore\wiki\web\app\dist
```

打开：<http://127.0.0.1:8877/>

构建依赖：`pyyaml`、`beautifulsoup4`、`markdown-it-py`、`pillow`。构建后执行 `node lore/wiki/web/app/check-app.mjs`，核对分类列表与前端源/产物一致性。

## 目录

| 路径 | 作用 |
|---|---|
| `app/index.html` `app.js` `app/style.css` | 前端源（改这里） |
| `app/dist/` | 构建产物（`data.json` + 优化图 + 前端拷贝） |
| `build_app.py` | 从 `lore/wiki` + `game/assets/wenzhen` + `game/data` 生成 `dist/data.json` |
| `gu-relations/蛊虫关系图谱.html` | 既有单页关系图谱（可选窗口） |

## 能看什么

- **知识库**：分类浏览、全局搜索、页面内章节层（原著 / 推导 / 待核对）
- **世界图谱**：世界与流派入口
- **美术馆**：142 张游戏美术（背景 / 敌人 / 蛊卡等）
- **审计模式**：按「待核对 / 含推断 / 缺证据」筛选

## 边界

- 站点**不承载新事实**；正文以 `lore/wiki/**.md` 与 `source/` 为准。
- `dist/` 为生成物，可随时 `python lore\wiki\web\build_app.py` 重建。
- 远程 ChatGPT Site 需单独同步；本地构建不自动发布。

## 相关

- 五条阅读路径：[paths/](../paths/README.md)
- Wiki 根入口：[../index.md](../index.md)
