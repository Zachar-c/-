# 交接：lab 素材渲染缺陷 + 映射缺口（2026-09-20）

> 定位：`wenzhen-web-lab` 的素材问题交接，供下一位 L2/Worker 接续。
> 产品权威仍是 `docs/PRODUCT_REQUIREMENTS_v1.0.md` 与 L0 冻结件；本文件是执行交接，不是规格。
> 触发来源：用户提交两张 lab 截图，判语「素材有问题」。

## 一句话结论

**素材本身没有问题。**用户看到的「白色鬼影」是 `css/lab.css` 的全局反相滤镜造成的**渲染缺陷**；
另有一层**素材映射缺口**（复用率过高）需要新素材，受视觉生产冻结令阻挡，必须 L0 裁决。

## 现象（用户截图）

- 战斗页「自由演武 · 单一敌人」：13 个敌人里多数渲染为同一类白色剪影，彼此无法区分。
- 炼蛊页「蛊虫 · 8 种在手」：`爱别离蛊` 与 `血滴子` 显示为同一张图。

## 根因 A：渲染层（可修，不需裁决）

`game/wenzhen-web-lab/css/lab.css` 对全部图像统一套用：

```css
mix-blend-mode: screen;
filter: invert(1) hue-rotate(185deg~188deg) saturate(1.15) contrast(1.08~1.12);
```

命中位置（行号为当前工作树）：

| 行 | 选择器 | 用途 |
| --- | --- | --- |
| 173-174 | `.gu img:not(.thumb)` | 蛊卡图标 |
| 187-188 | `.thumb` | 敌人立绘缩略图 |
| 198 | `.recipe .io img` | 炼蛊配方输入/输出 |
| 211 | `.slot img` | 杀招槽位 |
| 231-232 | 图鉴大图 | 收藏页 |
| 413 | `.enemy-actor img` | 战斗内敌人小像 |

原图是**纸本彩绘**（浅纸底 + 深色水墨主体）。`invert(1)` 把纸底反成暗蓝、主体反成近白，
再被 `mix-blend-mode: screen` 叠在深色 UI 上，结果只剩白色剪影。

附带第二个渲染缺陷：`.thumb { height: 132px; object-fit: cover; }` 会把竖构图人物裁掉头/脚
（对照图里 `势力守卫` 头部已被切掉）。

## 根因 B：素材映射层（需 L0 裁决，不得自行开工）

实测（解析 `js/data.js`）：

```text
GU total=25  uniqueIcons=8
  gu_sword x7   刃蛊 / 锋蛊 / 青锋蛊 / 古剑蛊 / 软剑蛊 / 双剑蛊 / 飞剑蛊
  gu_qi    x6   生机草蛊 / 硬气蛊 / 霭蛊 / 青藤蛊 / 骨蛊 / 自己蛊
  gu_moon  x3   月光蛊 / 月芒蛊 / 月影蛊
  gu_water x3   玉皮蛊 / 白玉蛊 / 浪蛊
  gu_blood x3   爱别离蛊 / 血滴子 / 血针蛊
  gu_light / gu_force / gu_earth  各 x1

ENEMIES total=13  uniquePortraits=10
  enemy_sanxiu x4   蚀骨蛊师 / 山脊悍客 / 族长 / 势力守卫
```

映射是 lab 自己的兜底表，**不在 Godot 数据里**，位于 `game/wenzhen-web-lab/tools/build_data.mjs`：

- `ICON_BY_SCHOOL` (L19)
- `GU_ICON` (L25)
- `PORTRAIT_BY_THEME` (L70)
- `ART` (L77)

`js/data.js` 由 `node tools/build_data.mjs` 生成，**不要手改**。
另注：`js/data.js:2909 / 2913` 已自述「clan_patriarch / blue_fur_jiangshi / miasma_vein_lord 缺少对应立绘，
未纳入」「血络主教无专属立绘，借用同流派血道蝙蝠图」——即已知缺口，不是本轮新发现。

## 阻塞依据（为什么 B 不能直接开工）

- `docs/superpowers/specs/2026-09-20-wenzhen-visual-positioning-v1-approved.md`
  —— L0 冻结件：明确「不批量生产」「第一阶段只做月光蛊 POC」。
- `docs/superpowers/specs/2026-09-20-wenzhen-visual-bible-v1.md`
  —— 状态 `READY_FOR_L0_DECISION`，未批准；其 `L2 INTEGRATION NOTE` 写明
  「POC 不进入正式资产库，不修改 `game/`」。

## 待 L0 裁决（三项，引自视觉圣经 §L0_DECISIONS）

1. 是否批准《问真》视觉圣经 v1.0 作为后续视觉任务唯一上位规范。
2. 是否批准后续第一视觉验证继续采用「月光蛊本体 + 主题皮肤」双样本。
3. 是否批准当前阶段进入视觉验证，而非继续视觉研究。

## 复跑验收

映射统计：

```powershell
node -e "const fs=require('fs');const DATA=new Function(fs.readFileSync('game/wenzhen-web-lab/js/data.js','utf8')+'; return DATA;')();const c=(arr,k)=>{const m={};for(const x of arr){(m[x[k]]=m[x[k]]||[]).push(x.name);}return m;};const gi=c(DATA.gu,'icon');console.log('GU',DATA.gu.length,'uniqueIcons',Object.keys(gi).length);for(const k of Object.keys(gi))console.log('  ',k,'x'+gi[k].length,gi[k].join('/'));const ep=c(DATA.enemies,'portrait');console.log('ENEMIES',DATA.enemies.length,'uniquePortraits',Object.keys(ep).length);for(const k of Object.keys(ep))console.log('  ',k,'x'+ep[k].length,ep[k].join('/'));"
```

渲染对照（**不改任何文件**，用 `eval` 注入覆盖样式）：

```powershell
node game/wenzhen-web/tools/drive.mjs `
  "file:///C:/Users/Zachary/DevEnv/06_%E4%B8%AA%E4%BA%BA%E9%A1%B9%E7%9B%AE/gu-zhenren/game/wenzhen-web-lab/index.html?silent=1" `
  "wait:1500,eval:document.querySelector('[data-tab=battle]').click(),wait:800,eval:window.scrollTo(0,300),wait:300,shot:before.png,eval:(()=>{const s=document.createElement('style');s.textContent='.thumb{filter:none!important;mix-blend-mode:normal!important}.gu img:not(.thumb){filter:none!important;mix-blend-mode:normal!important}.recipe .io img,.slot img,.enemy-actor img{filter:none!important;mix-blend-mode:normal!important}';document.head.appendChild(s)})()",wait:500,shot:after.png,log" `
  "1600,900"
```

静态检查：

```powershell
cd game/wenzhen-web-lab
node tools/build_data.mjs
node --check js/data.js
node --check js/main.js
node --check js/battle.js
node --check js/alchemy.js
```

## 修复 A 的建议范围（若 L0 放行）

- 只改 `game/wenzhen-web-lab/css/lab.css` 一个文件。
- 删除上表 6 处 `invert/screen`。
- `.thumb` 与 `.enemy-actor img` 的裁切改为不切头（`object-position` 或高度调整）。
- 不动 `js/**`、`tools/build_data.mjs`、`game/data/**`、Godot 侧、契约文档。
- **需要 L0 点头的可见后果**：纸本底会露出来，卡片变成「小幅纸本画」，而不是抠像贴图；
  抠像属于 B（走正式视觉管线）。

## DO NOT

- 不要批量生成蛊/敌人素材（冻结令未解除）。
- 不要手改 `js/data.js`（由 `build_data.mjs` 生成）。
- 不要用滤镜「修」素材问题——本次缺陷就是这么产生的。
- 不要动 `game/` 的领域数据与契约。

## 本次交接的事实边界

- 本轮**没有修改仓库任何文件**；`git status` 中 `game/wenzhen-web-lab/**` 的改动全部是用户既有改动。
- 对照图与渲染结果保存在 `%TEMP%\wenzhen-asset-proof\`，非仓库资产，不进 Git。
- 上方映射数字与滤镜行为均在真实 Edge（CDP，`1600x900` / `1240x760`）复现过，console 0 错误。

## Worker Task Packet（修复 A；L0 放行后可直接派发）

```text
WORKFLOW ROLE:
L3 Worker

UPSTREAM:
Codex Orchestrator (L2)

DOWNSTREAM:
Codex Review

PROJECT GOAL:
《问真》Godot 单机 Demo 的 Web 原型实验线；lab 用于快速验证页面与视觉表现。

CURRENT PHASE:
视觉定位 v1.0 已由 L0 冻结；视觉圣经 v1.0 待 L0 批准；月光蛊 POC 处于 HOLD。

TASK PURPOSE:
lab 当前用 invert+screen 把纸本彩绘渲染成白色剪影，用户判定「素材有问题」。
本任务只修渲染层缺陷，让既有素材能被正确看见，不生产新素材。

TASK:
只改 game/wenzhen-web-lab/css/lab.css：
1. 移除 6 处 mix-blend-mode: screen 与 filter: invert(...)
   （行 173-174 / 187-188 / 198 / 211 / 231-232 / 413）。
2. 修正 .thumb 与 .enemy-actor img 的裁切，使竖构图人物不被切头。
3. 用 drive.mjs 出 before/after 截图，确认 13 个敌人立绘彼此可区分。

SCOPE:
允许修改：game/wenzhen-web-lab/css/lab.css
允许读取：js/**、tools/**、../assets/wenzhen/**（仅核对）

DO NOT:
- 不改 js/**、tools/build_data.mjs（js/data.js 是生成物，禁止手改）。
- 不改 game/data/**、Godot 侧 scenes/scripts、任何契约文档。
- 不生成、不替换、不新增任何素材。
- 不新增 Provider / Router / 框架 / 依赖。
- 不 commit、不 push。

DECISION AUTHORITY:
滤镜移除写法、裁切参数、object-position 微调由 Worker 自定。

ESCALATE WHEN:
- 发现除 lab.css 外还必须改动才能达标；
- 发现纸本底露出后与既有页面冲突，需要设计取舍；
- 需要新素材或新依赖。

DELIVERABLE:
- lab.css diff
- before/after 截图路径
- Caveman Review Packet（ai-system/WORKER_HANDOFF_TEMPLATE.md）

ACCEPTANCE:
- 6 处 invert/screen 全部移除，rg 无残留；
- 战斗页 13 个敌人立绘彼此可区分，无切头；
- node --check js/*.js 全部通过；
- 浏览器 console 0 error。

STATUS TARGET:
READY_FOR_REVIEW
```
