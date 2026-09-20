# Handoff · Web parity slice 09 · 险地节点（探查 / 穿越 / 退回）

```text
TASK web-parity-slice-09-hazard-nodes
PHASE Web 全逻辑收敛
STATUS READY_FOR_REVIEW
TYPE implementation

GOAL
把 Godot 的 hazard（险地）节点类型接进 Web lab 固定节点图：每层 3 个候选中确定性换入 1 个险地，
玩家可选探查 / 穿越 / 退回，解析后回统一整备；规则逐条照搬 Godot，不新设计。

DELTA
+ js/hazard_rules.js：险地 standard actions 纯规则（三条转移、可用性判定、拒绝原因、Godot 原文文案）。
+ tests/hazard_rules.test.mjs：9 条新测试（三条转移、真元不足拒绝、事实去重与未知选择兜底、选项文案、放置确定性与每层 1 个险地、图不变量、无模板回退、无 choices 模板不进池、数据契约）。
+ docs/superpowers/specs/2026-09-20-wenzhen-web-hazard-nodes-design.md（仓库 docs/，不在本目录）：范围、Godot 语义来源（含行号）、放置规则、验收、边界。
~ js/run_flow.js：generateGraph 新增 hazardTemplates；每层按 seed 换入 1 个险地槽位（id 空间、后继、层主汇聚全部不变）。
~ js/main.js：fresh 传险地模板、新增 state.knownFacts；chooseNode 分流险地；新增 enterHazard / resolveHazard（eventLog + journal；拒绝不结算）。
~ js/journey.js：节点类型名「险地」、节点图险地标记与摘要、险地页 renderHazard、返回按钮路由（battle / reward / hazard / prep）。
~ index.html / css/lab.css：新增 #panel-hazard 页与险地样式；index.html 加载 js/hazard_rules.js。
~ tools/build_data.mjs：覆盖页新增险地条目；未覆盖清单登记 on_skip（数据有字段、Godot 零实现）；原「路线选择的领域结算」改为「非险地节点」。
~ js/data.js：重新生成（diff 仅 mechanisms 两处，其余逐字节不变）。

DECISIONS
- 每层固定换 1 个险地：槽位 = RunRules.seededIndex(3, seed, 'L{s}D{d}.hazard.slot')，模板 = seededIndex(池长, seed, 'L{s}D{d}.hazard.template')；同 seed + difficulty 同图。
- 险地图节点 id 不变（L{s}D{d}N{slot}），enemyIds 为空，携带 hazardId / name（「险地 · …」）/ summary / choices；精英判定仍按原 (depth+slot)%4===3，险地占位不补精英。
- 险地模板池为空时回退纯战斗图，run_flow 可独立使用（既有测试不传模板仍全绿）；模板没有非空 choices 时不进池（险地页靠模板 choices 出按钮，空列表会卡死节点）。
- 一个险地节点只解析一次：成功后进入统一整备；被拒只提示、不改状态、不开事件（对齐 Resolver._rejected）。
- 未做：on_skip（scripts/ 零命中）、预览的 leave 卡、cross 被拒时指向「静修路线」的 remedy 文案；均已登记理由。

VERIFY
data: node tools/build_data.mjs
      gu 77 | recipes 6 | killMoves 5 | enemies 14 | nodes 37 | route 12 | shopOffers 34
      数据/规则漂移（1）：thunder_crown_wolf 的 counter_status="sparked" 无规则实现（既有问题，未变）
tests: node --test tests/*.test.mjs -> tests 54 / pass 54 / fail 0（既有 45 + 新增 9）
       新增文件单独跑 -> tests 9 / pass 9 / fail 0
syntax: 逐文件 node --check hazard_rules / run_flow / main / journey / build_data -> 5×OK
        注意：`node --check a.js b.js …` 只检查第一个文件，组合写法 exit 0 不能当证据（本仓 V1 教训）；本轮以逐文件为准。
integration（node 侧，真实 DATA 首局 seed 101 / normal）：
      roots: L1D0N0=battle(ridge_hound) | L1D0N1=battle(neutral_stone_wanderer) | L1D0N2=hazard(flooded_cave)
      first hazard: L1D0N2 险地 · 积水石窟 | flooded_cave | choices ["scout","cross","withdraw"]
      options@qi3: scout:ok cross:ok withdraw:ok
      options@qi0: scout:ok cross:blocked(insufficient_essence) withdraw:ok
      resolve cross@3 => {"ok":true,"reason":"action_cross_cost","essence":2,"knownFacts":[],"fact":""}
      resolve cross@0 => {"ok":false,"reason":"insufficient_essence","essence":0,...}
      resolve scout   => {"ok":true,"reason":"action_scout_route","essence":3,"knownFacts":["route_scouted"],...}
diff-check: git diff --check -- game/wenzhen-web-lab -> 无输出，exit 0
browser: 未执行（按任务要求由 L0/L2 实点）

RISK
1. 险地占位改变同层战斗/精英配比（首局 normal：精英 35 -> 21，战斗 115 -> 79；50 个险地 = 14 个原精英槽 + 36 个原战斗槽）。配比与是否保底精英属数值取舍，按 V3 留 L1 裁。
2. 险地模板的 stage 字段（one / three）本轮不参与筛选：lab 段号与转数/阶段没有既有映射，加筛选属新设计；若要按段限制模板，需 L1/L0 先定映射。
3. Godot 社交节点理论上可在同一节点多次 choose_action，并另挂 leave 卡；lab 只做「一节点一次选择」，与战斗节点一战一致，未建模重复行动。
4. 工作树含此前未提交改动（视觉线、parity 等），本轮未 commit / push。
5. 浏览器交互路径（进入险地 -> 三选一 -> 统一整备 -> 下一节点）未经真实点击，仅由规则测试与 node 侧集成检查覆盖。

NEXT
1. L0/L2 实点验收：险地页可用性、真元不足提示、解析后进入整备与下一节点、console 0 error。
2. 若继续 parity：contact / caravan / event 等节点类型沿用同一门禁口径（先取 Godot 实现与行号，再落地）。
3. on_skip 需 Godot 域层先实现，lab 才可搬运；本轮只登记不实现。
```
