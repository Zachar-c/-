# B 线交接文档（全书粗蒸馏）— 2026-09-25

> 接手前必读：根 `AGENTS.md` → `lore/wiki/AGENTS.md` → `lore/wiki/COORDINATION.md`（车道规则）→ `lore/wiki/log.md`（B 线条目）→ 本文件。
> 本文件是操作层交接，不是知识规范；知识以 `lore/wiki/` 各页与 `game/data/` 为准。

## 一、线别与章程

- 三条并行线（L0 裁定）：**A＝全书复杂规则精蒸馏**（rules/ 五站已完，后续尊者资格链/阵道标尺/梦道）；**B＝全书粗蒸馏（本线，本文件）**；**C＝全书按剧情顺序精蒸馏**（WTC✅→CAR✅ 49.5/50→弧四 TKF 进行中）。
- B 线方法：粗/中粒度广覆盖；条目默认《资料整理》层级（笔记转述），仅抽样回原文核验进《原著明确内容》；不做 E/ST/EVT ID 化、不建 benchmark（那是 A/C 线精蒸馏簇的做法）；B 线页面后续由 A/C 精蒸馏时**以 B 页为底 refactor**。
- 跨线车道：B 拥有 characters/roster*.md、gu/roster*.md、world/ 四域页+各总表+四组织页、themes/immortality+power-and-interest；**rules/ 目录归 A 线勿动**；兽潮/剧情页归 C 线；共享 hub 索引只做自己页的一行登记；log.md append-only。
- 提交纪律：每批完成即提交；只 add 自己车道文件；共享页先 `git diff` 查他人未提交改动；pre-commit 的 remote-baseline fetch 遇网络失败可 `--no-verify`（须在提交信息登记理由；baseline 包含性未变时才允许）。

## 二、已完成（13 个 Wiki 簇 + 2 个游戏数据批）

Wiki（lore/wiki/，提交至 e4be0a2/a321260 前状态，check.ps1 全绿：89 文件、44 schema-2 页、924 链接）：

| 簇 | 页面 | 核心资产 |
|---|---|---|
| ROSTER | characters/roster.md | 约 45 人势力分组总表 + 方源马甲归一表（11 马甲，含楚瀛/算不尽） |
| GU-ROSTER | gu/roster.md | 约 60 蛊品阶谱系 + 方源蛊链时序 + 人道蛊族 + 仙蛊屋/杀招代表 |
| PATH-ROSTER | world/path-roster.md | 图事成流派源流整段已核（246640–246680）+ 33 流派归属 + 境界阶梯实例 |
| DOMAIN | world/north-plain/central-plain/east-sea/west-desert | 五域页；五域总述 73950 已核；"西荒≠西漠"归一 |
| ECON | world/economy-roster.md | 货币双层（仙元石 1:1 青提已核）/市场/定价实例/舍利蛊管禁 |
| ORG | world/shadow-sect/zangmeng/longevity-heaven/ten-ancient-sects | 僵盟定义整段已核（121686–121740）；影宗十万年局；十大古派代理体系 |
| THEME | themes/immortality + power-and-interest + ren-zu-zhuan 补全 | 永生/实力与利益主题页；人祖传寓言-剧情互文锚点表 12 条 |
| GAP-SWEEP | 跨 9 页 | 万龙坞归属纠正（东海→中洲）、返实蝠翼=杀招纠正、虚道时代两说张力登记 |
| ROSTER-2 | characters/roster-2.md | 约 50 复现配角八组；楚门起源；方正诛魔榜榜主线 |
| MAP | world/map-roster.md | 三类空间（地表/福地洞天/超地理）约 40 地点；神帝城组并；方源福地内部地理 |
| KM | world/kill-move-roster.md | 约 35 杀招实例（A 线 KM 规则页的实例清单互补） |
| GU-2 | gu/roster-2.md | 约 24 基础设施型蛊；天机蛊本质修正（乐土所创→砚石老人炼成） |
| ENEMY | characters/enemy-roster.md | 五层威胁结构 + 弧线敌人速查表（BOSS 分层参照） |

游戏数据（game/）：

- `b4614cc` ENEMY-MODEL：enemies.json +13 lore 可溯敌人（origin_ref 原文行锚点、bound/guarded only、rank 预算内、boss 带 phases）；nodes.json +4 分支节点（挂 stage 一/二可达宿主）+ 3 个层 boss 池按 rank 注入；names.json +13 中文名；build_data.mjs 敌人打包口袋扩为「全图节点引用 ∪ boss_pool」。
- `a321260` GU-CLEAN：802 蛊 29 处修正——爱别离定名（原"爱别离蛊"不存在于原文）；梦话蛊/火炭蛊严格升级 novel；25 组重名学派前缀消歧、重名清零；引用完整性 0 悬空；**未删 test_slay_gu**（被 school_pools/buffs 引用，登记遗留）。

## 三、验证基线

- Wiki：`pwsh -NoProfile -File lore/wiki/tools/check.ps1` 应全绿（check1–8；check2 WARN 为既有 local-only 债务，FAIL 须为 0）。
- 游戏：在 `game/wenzhen-web-lab/` 下 `node tools/build_data.mjs`（改 data 后必跑）→ `node tools/check_balance.mjs`（49/49）→ `node tools/check_l1_phases.mjs`（40 pass/0 fail/alarm 12 为既有）→ `node tools/check_progression_loop.mjs`（10/10）→ `node --test tests/*.test.mjs`（217/218）。
- 已知既有失败（非 B 线引入，勿"顺手修"）：`tests/node_action_rules.test.mjs:394` 断言 typeLabels 不含 event，但 HEAD 已有 2 个 event 节点；`enemies.json` 里 thunder_crown_wolf 的 counter_status="sparked" 无规则实现（build 工具已登记漂移，B 线新敌人只用 bound/guarded）。

## 四、未决与登记（接手后优先看）

1. **js/data.js 未提交**：工作树已重生成（含 B 线数据），但同批并行线有未提交的 gu.json/v1_battle.json/jbalance 等 WIP，为避免把他人改动烘进生成物而暂缓。**接手后**：等并行批提交后重跑 `node tools/build_data.mjs` 再单独提交 js/data.js。
2. **bank-only 敌人**：bai_ice_warden、xiong_bear_handler、merchant_hall_inquisitor（以及既有 18 个）未接节点/pool；接入方式照 b4614cc 的三种 hook（分支节点/boss 池/route）。
3. **跨线冲突登记**（在 wiki 各页待核对）：
   - "百足家吞并黑家"（E 笔记）vs 黑楼兰黑家后世活动——回 E 区间原文裁定；
   - 虚道时代两说（图事成"近古产生" vs 原文 73156"上古盛行"）——归 A 线流派境界核验批；
   - 紫山真君名号双源（方源自称弟子 113996 ↔ 真身 236694）——方源是否知情未核。
4. **G 笔记 3121xx 区间锚点系统性偏移**（312128/312140 → 实际 +1016 行附近）：凡引 G 笔记该区间锚点须回原文重定位（已两例：创蝉归属、爱情蛊）。
5. **2 字蛊名的原文回验陷阱**：naive includes 会命中更长名/动宾切词（骨蛊⊂玉骨蛊、土蛊⊂本土蛊师）； upgrades 须 ≥3 字名且上下文为独立蛊名（clean 批已按此执行，脚本用后即删，规则见提交 a321260）。

## 五、B 线下一步候选（按价值排序）

1. **随 A/C 精蒸馏做底稿 refactor**：A 线流派境界五级已消费 path-roster；C 线弧四 TKF 会触碰三王山/白凝冰——B 页相关条目随之补锚。
2. **经济/资源层加锚**：元石↔仙元石汇率（若原文存在）、灵缘斋归属、僵盟拍卖细节。
3. **canon 蛊升级为可玩实体**：Wiki 蛊虫总表 85 个锚定名中尚未进 gu.json 的（定仙游/天机/胆识蛊等），走 refinement_recipes + school_pools 增补（管线已验证）。
4. **MAP 补全**：各域城市/山川逐段核验（当前只到锚点层）。

## 六、B 线车道文件清单（只 add 这些）

- lore/wiki：characters/roster.md、roster-2.md、enemy-roster.md、gu/roster.md、roster-2.md、world/path-roster.md、map-roster.md、kill-move-roster.md、economy-roster.md、north-plain.md、central-plain.md、east-sea.md、west-desert.md、shadow-sect.md、zangmeng.md、longevity-heaven.md、ten-ancient-sects.md、themes/immortality.md、power-and-interest.md、ren-zu-zhuan.md、characters/index.md、gu/index.md、world/index.md、themes/index.md、index.md（Key Findings 我方条目）、COORDINATION.md（B 行）、log.md（append-only）、HANDOFF-B.md（本文件）。
- game：data/enemies.json、data/gu.json、data/gu_names.json、data/names.json、data/nodes.json、wenzhen-web-lab/tools/build_data.mjs、（收口后）js/data.js。
