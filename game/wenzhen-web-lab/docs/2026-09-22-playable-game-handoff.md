# 主链写入移交记录 · 2026-09-22 LAB PLAYABLE

## 移交信号

| 项 | 值 |
| --- | --- |
| 移交者 | 上一会话主链执行者（MVP×Lab 合并 / Integration 收尾；进程已结束，无在途写） |
| 接手者 | 本会话 L2 Orchestrator（Codex）session `ses_ffe5f38901293ffelmycSH4PLP`，后续按 W 批次派 Worker |
| HEAD | `2760160ee96f45afd498ef5a0f73bb57fc84d208` |
| 移交时间 | 2026-09-22（L0 下达《lab.html 可玩游戏本体 Implementation Plan》同日） |
| 写入权 | 自本记录落盘时刻起，主链写区归本会话 L2 调度的单主写 Worker 序列；他人只读 |

## 从该时刻停止写入的文件（主链写区）

- `game/wenzhen-web-lab/lab.html`
- `game/wenzhen-web-lab/css/lab.css`
- `game/wenzhen-web-lab/js/main.js` / `journey.js` / `battle.js` / `combat_core.js` / `mvp_logic.js` / `mvp_content.js` / `balance.js` 及本页其余 `js/*`
- `game/wenzhen-web-lab/tools/*`（`build_data.mjs` / `autoplay.mjs` / `check_*.mjs` 及后续新建）
- `game/wenzhen-web-lab/tests/*`
- 生成物 `game/wenzhen-web-lab/js/data.js`（只经 `build_data.mjs` 再生，不手改）
- 真源 `game/data/{balance,gu,v1_battle,refinement_recipes}.json`（本阶段只读；改数值须 L1/L0）

## 工作树清单（移交时 `git status --short` 摘要）

已跟踪修改（属上一会话产物，**不夹带提交、不覆盖**）：

- `PROJECT_MAP.md` / `docs/debt.md`
- `game/data/v1_battle.json`
- `game/wenzhen-web-lab/css/mvp.css` / `index.html` / `lab.html` / `mvp.html`
- `game/wenzhen-web-lab/js/{battle,main,mvp,mvp_content,mvp_logic}.js`
- `game/wenzhen-web-lab/docs/2026-09-21-v4-calibration-handoff.md`
- `game/wenzhen-web-lab/tests/mvp_logic.test.mjs`
- `game/wenzhen-web-lab/tools/{autoplay,build_data}.mjs`

未跟踪（上一会话新建，保留工作树，待 L2 按批拥有后独立提交）：

- 计划/规格：`docs/superpowers/{plans,specs}/2026-09-22-lab-playable-game*`
- 规则与审计：`docs/ORIGINAL_POWER_SYSTEM_AXIOMS.md`、`docs/code-drift-audit/`、`docs/l1-*`、`docs/power-*`、`docs/wenzhen-thesis/`
- Web 主链：`EXISTING_CAPABILITY_MAP.md`、`js/{balance,combat_core}.js`、`data/`、`balance/`、`golden/`、`vertical/`
- 校验工具与测试：`check_{projection,balance,l1_phases,progression_loop}.mjs`、`l1_boundaries.test.mjs`、`balance.test.mjs`
- 文档：`docs/{MERGE-MVP-LAB,2026-09-21-web-integration-acceptance,lab-mechanics-three-questions}.md`
- 裁定：`game/world-model/rulings/RUL-2026-09-21-010.json`
- Research Requests：`ai-system/RESEARCH-REQUEST-2026-09-21-*.md`

## 写区 SHA-256（移交时实测）

```text
e9481253670f91e17b4cb11661990fee58e89baf15ec8b11a92dbb68930edf48  game/wenzhen-web-lab/lab.html
34b2ac8c028e936c8856a27419366370abc5c3afa212bc2a9d3151e126be92f5  game/wenzhen-web-lab/js/main.js
cdd09774ae87cbc432e2814e8c7fe1af3607665352128bb3b6a7a29c69a2288b  game/wenzhen-web-lab/js/journey.js
ad0efe35331d4ac85c509c29c211c28740901edeadc46783f18287f1e7de9c1f  game/wenzhen-web-lab/js/battle.js
e1de966981c7e4018c1c43ab9ae61abc57f03c10cd06f6274979ec85990190f2  game/wenzhen-web-lab/js/combat_core.js
c441671151e431484d85ee1f35af8233f13bb8039e7fa267a33dcd99f22ddfe9  game/wenzhen-web-lab/js/mvp_logic.js
a1944a51eb20ac9549d696a91b3ff89ba0e19d539b578c30eb7395eec83b0240  game/wenzhen-web-lab/js/mvp_content.js
b7b9a9a5436c8a4ed0d323f16acd001ab652cff12659330ce76da7c1377317f9  game/wenzhen-web-lab/js/balance.js
65fb3c6e3b9bd8ae1a5b0e569d866f6c3c57ed7ad0e5f42caad4bd1c70f4f16b  game/wenzhen-web-lab/css/lab.css
dc7ba872eb12d6393d9271a655739d51407fdf475cc3907019292cefac32572b  game/wenzhen-web-lab/tools/build_data.mjs
c0367e7111f636d4d963fdfe669a83f89605840de0fbd48c8dc075d66083d9c4  game/wenzhen-web-lab/tools/autoplay.mjs
b61d064a82b354d2c9f6a5e5de70dd1d95c93e5d7f7f125894a79fc9b998129c  game/wenzhen-web-lab/tools/check_projection.mjs
51bc9a06a3b2d971e4a00324f1dce114ee08055c4c21fc09e8c2efa658893705  game/wenzhen-web-lab/tools/check_balance.mjs
91b1f3b1b16159a5d0020e515adf9510c5fa3b7fc96c8997ffb9b7326570a5d4  game/wenzhen-web-lab/tools/check_l1_phases.mjs
d607147ee84cc1ac6e1db463ce43410504155eace826237d2c763c001881cd1d  game/wenzhen-web-lab/tools/check_progression_loop.mjs
9580872465070477235b674366d12acd2f96bc1ec23659a96a39c740a29e958b  game/data/balance.json
6508a9fd4fe3743001f8fdb52ffc64092239ff323059915abdde377693e0e912  game/data/gu.json
7aab48d22d1b0659fb9cbf53e9034717f774a1f36bb1653ec541b86f580e103d  game/data/v1_battle.json
cb547f30d8401f9def195723b27a13e26a15a6dbe95019098f33141d463c3897  game/data/refinement_recipes.json
```

## 并发写入者核查

- 无在途 Worker / actor 占用主链写区。
- `.workbuddy/memory/2026-09-21.md` 为历史便签，最近写入 2026-09-21，非本批写者。
- L2 复核结论：**移交成立**。自此刻解除 W0 写入 BLOCKED；契约/状态文档允许写入。

## 基线测量（移交同日实测，V1：只认输出文本）

```text
node --test game/wenzhen-web-lab/tests/*.test.mjs     → tests 126 pass 126 fail 0
node game/wenzhen-web-lab/tools/check_projection.mjs → Projection 34/34（含突变 999）
node game/wenzhen-web-lab/tools/check_balance.mjs    → 38/38
node game/wenzhen-web-lab/tools/check_l1_phases.mjs  → pass=41 fail=0 alarm=11
node game/wenzhen-web-lab/tools/check_progression_loop.mjs → progression probe 10/10（fixture，不计入 G05/G07）
```

警报 11 条为既有经济数据债（R1–R5 蛊价/突破/炼耗），**本阶段不改价**。
