# 引擎 v0.2 扩展终审：载体、灾劫实战化与供应消费

日期：2026-09-27。状态：v0.2.0-draft 引擎接线与终审自查；验收门槛为 [validate.mjs](validate.mjs) 全部检查通过，未经独立 L1 审查，不代表产品平衡。入口：[README](README.md)。

## 1. 本轮范围与角色

引擎扩展（[model.mjs](model.mjs)）与参数升版（[parameters.json](parameters.json)）由上一车道交付，供应层由 [supply.json](supply.json)/[supply-model.md](supply-model.md) 车道交付，蛊库 gu-library.json 由第三条车道交付（本轮尾部落盘，接入验证见 §6.2）。本轮按 Astra 口径做架构与跨界集成终审：把 [validate.mjs](validate.mjs) 接线到新引擎能力、补终审文档、重跑验证。允许改动仅 validate.mjs 与本页；model.mjs/parameters.json 原则上不动，发现阻塞验收的真实缺陷时做修复级最小改动并逐条登记（见 §4，共四处，全部在 model.mjs；parameters.json 零改动）。

## 2. 新增能力说明（按 model.mjs 实际实现）

### 2.1 载体选型与理由

载体是不同的防御承载模板，不是同一耐受值的换皮（呼应[模型](model.md) §2.3「特殊魂体、蛊屋、兽群应作为不同防御载体建模板」）。`carriers.tribulationCarrier` 的映射与理由（数值全部是纯游戏假设；概念锚点只取自 lore/wiki，只读引用，不声称原著数值）：

| 灾劫 | 载体 | 机制参数 | 理由 | 概念锚点（只读） |
|---|---|---|---|---|
| 地灾 earth | beastPack | hp300、6 单位、单回合输出随剩余单位数线性衰减且不低于 packDamageFloor=0.25；玩家动作按 packAoeYield 取范围收益（strike 1.2、burst 1.5） | 成灾基数大、多单位聚合、逐波削弱；范围动作对群有额外收益 | 兽潮：多低耐久单位聚合、逐波衰减（lore/wiki/world/beast-tide.md） |
| 天劫 heaven | soulBody | hp70、常规类动作（basic/strike/drain）减免 65%（soulBodyResist.regular），爆发类全额 | 天罚直指魂魄，常规手段难伤，逼爆发窗口 | 魂道：魂魄由虚返实、常规手段难伤（lore/wiki 魂道条目） |
| 浩劫/万劫 grand/myriad | guHouse | hp200、护甲 0.4、输出仅 damage 4 | 仙窍级攻城战：高耐受、高减伤、低机动的阵地战 | 杀招体系 KM-006：蛊屋本质是固定化杀招、高耐受低机动（lore/wiki/rules/killer-moves.md） |

单敌引擎内不构造多载体同场组合；逐级增强用 tribulationPower 威能倍率表达。载体对局数值锚点（默认口径、一转、100 种子）见[验证报告](validation.md)「载体战斗矩阵」：soulBody 使纯常规构筑（balanced/sustain）在一至五转胜率 0–3%（常规减伤不可观测即不合格），burst 构筑保持 100%；guHouse 使战斗拉长到 14–18 回合而敌方输出均值约 4 点；beastPack 敌方输出从首回合 24 衰减到末回合约 8.8。

### 2.2 灾劫实战化口径

`tribulationFight({r,kind,ordinal,count,...})` 复用 `fight()`：敌人 = 载体模板 × `tribulationPower(kind,ordinal,count)` × 同转尺度。返回形状与聚合代理 `resolveTribulation` 完全同形（alive/injury/ecology/marks/power/margin，有同形断言），账本接口一致：

- alive = 战斗胜利；30 回合超时未胜判负，不能靠无限防御刷通过；
- margin = 剩余耐受 / 0.75（`tribulationMarginRef`），仅用于与代理口径同轴对比，不再作为生死门槛；
- injury = 玩家耐受损失比例；ecology 扣减（injury×20%）与修复费公式（injury×8U）与代理口径完全相同；
- 成功按本转对应类型加道痕，失败不给收益，与[模型](model.md) §9.3 相同。

聚合代理仍保留并继续服务升仙、成尊等场景；实战口径目前只替换六至八转灾劫结算。两者完成率对照（默认运行、30 种子、preparation=1、rewardMultiplier=1、未接蛊库的占位动作口径）：

| 构筑 | 聚合代理 | 实战载体 | 实战口径主要失败位置 |
|---|---:|---:|---|
| burst | 100.0% | 63.3% | 7/8 转长期筹备破产 7、8 转灾劫战斗失败 1 |
| balanced | 36.7% | 0.0% | 6 转长期筹备破产 15、6 转灾劫战斗失败 14、7 转破产 1 |
| sustain | 100.0% | 0.0% | 6 转灾劫战斗失败 30 |

解读：实战口径的失败绝大多数不是「打不过」而是「伤损×8U 修复费把账本压穿」（balanced、burst 的破产位置）；sustain 则是纯常规输出打不动 soulBody 天劫（30/30 战斗失败）。这是把 v0.1「准备充分可存活」公式情景换成真实战斗后的如实漂移，登记为已知漂移，不为变绿调参。

### 2.3 CLI 契约

```text
node validate.mjs [--builds <gu-library.json>] [--supply <supply.json>]
                  [--scenarios supply_limited,key_gu_missing,refine_tail] [--campaign-seeds N]
```

- 无参数：v0.1 全部 21 项检查与全部表格 + v0.2 新增 8 项检查 + 载体矩阵节 + 灾劫两口径节（29 项全绿，约 0.9 秒）；不依赖 gu-library.json 存在。
- `--builds`：追加「真实构筑×供应」节（构筑静态审计结论 + 三构筑在基准供应与所选 scenario 下的完成率、失败位置分布、供养/炼制账本对照）。文件缺失或解析失败时打印说明并跳过该节，不视为错误。
- `--supply`：供应数据文件，默认读本目录 supply.json；缺失时供应数据边界检查跳过、场景臂按「全部可得、价格倍率 1」基线运行。
- `--scenarios`：逗号分隔，默认全部三个；未知键报错退出码 2。
- `--campaign-seeds`：两口径节与构筑×供应节的账本种子数，默认 30。
- 运行重新生成 validation.md 与 results.json（生成物）；results.json 新增 `carrierMatrix`、`tribulationCalibers`、`buildsSupply`、`cli`、`runNotes`、`runMs` 键。

### 2.4 gu-library.json / supply.json 消费语义

- `createSupply({supplyJson,seed,scenario})`：supply 行 first-match-wins（各自保持文件内相对顺序）；gu 精确匹配行优先于泛匹配行（与数组顺序无关）；`"*"` 与省略字段同为通配；availability ∈ [0,1] 是整局属性，按「局种子 ⊕ gu id」派生随机数对每只蛊一次判定并在实例内 memo（不可刷）；`key_gu_missing.dropGu` 强制整局不可得（forcedMissing 标记）；`supply_limited.channelMultipliers` 乘到对应渠道行的 availability 上并截断到 [0,1]；无匹配行落到 market 默认（可得、价格倍率 1）。场景 priceMultiplier 不进引擎记账（见 §7）。
- `resolveStage({lib,buildId,r,supply})`：主蛊不可得（供应/越阶/未知）时按 fallbacks 顺序取第一只可得蛊或 `gu:null` 占位；占位不覆盖任何已赋能动作，该动作退回 §4.1 基础占位口径（攻击/防御动作不可用，宿主保留 basic/guard）；同动作多槽取蛊转数最高者；supportUnits = 实际携带蛊逐只×价格倍率之和（按 gu id 去重，一只蛊一份供养）。
- `campaign({lib,supplyJson,scenario,...})`：每阶段按构筑取槽位驱动战斗与供养；`refine_tail` 只把炼制记账从期望尝试次数（1/p）切到理论 95% 次数（ceil(ln 0.05/ln(1−p))），单次费 12U 与成功率公式不变。
- `auditBuilds(lib)`：静态审计，登记 unknown-gu / over-rank-slot / unknown-action / unknown-fallback / no-fallback / capacity-exceeded / fallback-stronger 七类 issue，由验证器呈现，不静默修正。容量口径：L=n(n−1)/2（n=当阶槽位数），容量=基础心智容量+2×构筑声明境界（`stage.attainment`，未声明按 0 的静态保守口径）。

## 3. 终审清单（防套利）

| 检查项 | 结论 | 验证位置 |
|---|---|---|
| fallback 不得强于本体 | 通过：同 poweredAction 域内按 系数×蛊转数 比较，更强者登记 fallback-stronger；`gu:null` 占位强弱依赖局内尺度，静态不可比，不在此审计，改由「占位不覆盖已赋能动作」的引擎规则兜底 | validate 检查「构筑审计：…」；results.json buildsSupply.auditIssues |
| availability ∈ [0,1] 且不可刷 | 通过：supply.json 全部渠道值、supply 行、场景乘数在界内（数据检查）；场景乘积经 clamp 截断（行为检查，0.9×0.6=0.54、1.0×1.4→1）；判定为整局一次 + 实例内 memo，同蛊重复 resolve 恒定，同种子可复现 | validate 检查「availability 有界且不可刷…」「supply.json 数据边界…」 |
| gu 精确匹配优先于泛匹配 | 通过：gu 行置前且保持相对顺序，泛匹配行（rank/path/rarity）兜底 | validate 检查「供应解析：…」 |
| refine_tail 只改记账口径不改成功率 | 通过：`refinement()` 概率公式未动；campaign 仅在 period===2 记账处切换尝试次数；成功率相关 v0.1 检查（仙蛊唯一/炼制上限、Monte Carlo 尾部）保持全绿 | 代码路径 + validate 全绿 |
| 兽群输出有地板、魂体减免可观测 | 通过：packDamageFloor、soulBodyResist 断言入检查 | validate 检查「soulBody…」「guHouse…beastPack…」 |

## 4. model.mjs 修复级改动登记（四处；parameters.json 零改动）

原则：以上一车道交付的 model.mjs 为基底，仅修复「阻塞验收的真实缺陷」，每处最小改动并登记位置、原因、改法、影响。

| # | 位置 | 缺陷（实测证据） | 改法 | 影响面 |
|---|---|---|---|---|
| 1 | `createSupply` 内场景乘数应用处 | supply.json 场景乘数是 `{availability,priceMultiplier}` 对象，原实现当标量直接相乘得 NaN，`clamp(NaN,0,1)=NaN`，`availability>0` 恒假 → supply_limited 下所有命中渠道行的蛊全部不可得（实测 moonlight-gu 解析为 `availability:null`、`available:false`），场景对照完全失真 | 兼容对象（取 `.availability`）与标量两种形态，乘后 clamp [0,1] | 仅 v0.2 供应路径；v0.1 路径不经 createSupply，无数字漂移 |
| 2 | `createSupply` 内 `matchLine` | supply.json 以 `path:"*"`/`rarity:"*"` 表达泛匹配（[supply-model.md](supply-model.md) §1 契约「未给出的匹配字段视为通配」），原实现按字面值比较 → rank 泛匹配行（可得性曲线 0.9→0.05）与 unique/wild 特化行全部死行（实测 rank1 common 泛匹配蛊落到 market 默认 1.0），供应稀缺失效 | `gu/path/rarity` 字段值 `"*"` 与省略字段同为通配 | 仅 v0.2 供应路径；无 v0.1 漂移 |
| 3 | `auditBuilds` | 验收要求审计报告「slot 超心智容量、缺 fallback」，原实现只登记 unknown-gu / over-rank-slot / unknown-action / unknown-fallback / fallback-stronger 五类 | 新增两类 issue：`capacity-exceeded`（L=n(n−1)/2 超基础容量+2×声明境界，r 限 1–9）、`no-fallback`（槽位无 fallbacks，主蛊不可得时无降级路径） | 新函数，v0.1 不调用；无漂移。样例验证时该审计实际抓到过一次越阶槽位（样例数据随后修正） |
| 4 | `fight()` 兽群分支 | `packAoeYield` 以动作名为键（basic/strike/burst/drain），原实现按伤害类别（`damageClass`→regular/burst/none）取键 → strike 的 1.2 与 basic/drain 的 1.0 永不命中，仅 burst 因动作与类别同名偶然生效（实测兽群 strike 均值 24.15 而非 28.8），兽群「范围收益」群体特征半失效 | 先按动作名 k 取系数，缺省再按类别 cls 取 | v0.1 战斗矩阵 27 行 beastPack 与敏感性 18 行（聚合含兽群战斗）数字漂移，见 §5；其余敌人行不变 |

## 5. v0.1 数字漂移登记（重跑逐键比对 results.json）

以下之外，v0.1 全部数字与 2026-09-27 v0.1 报告逐位一致（脚本比对：rankRows、crossRank、boundaryCrossRank、economy、campaigns、representative（126 场 / 1000000 道痕）、aptitudes、refinementRisk、parameterHash 全部 IDENTICAL；checks 前 21 项逐字一致）。

| 漂移 | 原因 | 处置 |
|---|---|---|
| 战斗矩阵 enemy=beastPack 的 27 行（9 转×3 构筑）：一至五转胜率 42/2/31% → 49/7/45%，六至九转剩余耐受 43.2/53.6/68.0% → 46.8/69.3/75.6% | 修复 #4：strike 等动作的范围收益系数真正接通，玩家对兽群输出上升 | 如实接受，不回调参数。这是把参数表中已声明的系数接通，不是平衡性调整 |
| 敏感性 18 行小幅变化（如 enemyMultiplier=1 burst 95.1%→95.4%） | 每行聚合含 30 种子×9 转×8 敌（含 beastPack）战斗，被修复 #4 传导 | 同上 |
| results.json `modelHash` 变化 | model.mjs 四处登记修复 | 预期内；parameterHash 不变 |
| validation.md/results.json 追加 v0.2 节与键、检查行 21→29 | 本轮交付内容 | 非 v0.1 段落改动；v0.1 段落文本未删改 |

## 6. 构筑×供应集成验证记录（--builds）

### 6.1 临时样例验证（CLI 冒烟，样例文件不入仓库、已删除）

在 gu-library.json 交付前，用临时样例构筑库（三构筑×九转×每阶 2 槽，主/备蛊链显式声明，含 `gu:null` 占位）+ 真实 supply.json + 三场景完成 CLI 验证：29 项检查全绿、审计 0 问题、12 行账本对照生成（约 1.0 秒）。样例驱动的诚实观察（仅样例数据结论，不外推）：`key_gu_missing` 使失败位置后移、供养/炼制账本抬升——主攻蛊整局不可得后构筑退回 basic+guard 龟缩流，反而比「备蛊降半功率攻击」存活更久，暴露「弱蛊攻击不如无蛊龟缩」的候选平衡问题；`refine_tail` 把供应模型 §4.3 预测坐实（炼制费合计 +50% 至 +65%）；`supply_limited` 使战败前移。

### 6.2 真实 gu-library.json 接入（并行车道本轮交付后立即只读消费验证）

蛊库车道交付 `gu-library.json`（0.2.0-draft，69 只蛊、三构筑×九转）后，以 `--builds docs/design/rank1-9-model/gu-library.json --supply docs/design/rank1-9-model/supply.json --scenarios supply_limited,key_gu_missing,refine_tail` 做只读集成验证：

- 消费契约兼容（gu[].id/rank/path、builds.*.ranks["1".."9"].slots[].{gu,poweredAction,fallbacks}，fallbacks 含真实备蛊与 `gu:null` 占位）：无崩溃、无 schema 改动；
- `auditBuilds` 静态审计 0 问题（防套利口径全部通过）；
- 账本对照（30 种子/臂）：全部臂完成率 0%，战败位置显著前移——burst 一转战败 26/30、balanced/sustain 二转战败 20/30（key_gu_missing 臂二转 30/30，dropGu 正中月光蛊家族攻击核）。对照占位动作基线（v0.1 economy 表 r1–r3 survival 全 100%）这是真实的内容×引擎校准信号，不是引擎缺陷：构筑口径严格化「未赋能动作不可用」，burst 构筑一转槽位只赋能 strike（失去同名爆发动作）且无 guard 槽，护甲链消耗战打不过；该发现归蛊库车道处置（赋能动作分布/fallback 强度），本轮不调引擎、不调参数使其变绿。

正式蛊库接入后的完整账本结论以蛊库车道或主会话重跑为准；本节只登记集成可行性与上述信号。

## 7. 仍未覆盖的限制

- 升仙、八转后研究/开创、成尊条件仍是聚合代理；实战口径只覆盖六至八转灾劫战斗。
- 场景 `priceMultiplier`（如 supply_limited 的 market ×1.4 稀缺溢价）未进入引擎记账：v0.2 引擎无购置扣费，供养按行内价格倍率计；渠道稀缺表现为「当期不可得 → fallback/占位」，supply-model §4.1 要求的「渠道等待期数」报告未实现。
- 高阶同转沿用同一战术模板，载体矩阵跨转相似（一至五转完全同值）是尺度归一化的产物，不是独立的高阶内容证据；低转与高转的真实差异来自能量池结构（凡人 44 点真元撑不起持续 guard，仙人 15 当量可以）。
- 实战口径与构筑×供应节未接蛊库时用占位动作/样例数据；接入后灾劫难度与账本随构筑变化，须重跑并重新登记。
- `auditBuilds` 容量口径为静态保守值（未声明境界按 0）；跨构筑的 gu 复用、局内临时换装不在静态审计范围。
- 独立 L1 审查与真人实玩未完成；本页只做增量登记，不改写 [复核](review.md) 的结论。README 导航表已由主会话集成批补挂本页。

## 8. 主会话集成收口（2026-09-27 同日第二轮）

### 8.1 两项语义裁决（v0.2 模型修订，待 L1 追认）

1. **未赋能动作回落占位**（model.mjs `resolveStage`）：构筑未赋能的动作回落 §4.1 占位口径，而不是从动作菜单移除。§6.2 的全臂 0% 即旧语义伪影：burst 构筑一转槽位只赋能 strike，脚本失去同名爆发动作后 26/30 战败。构筑是占位工具组的增量替换，内容缺口应体现在账本与高转输出缺口上，不应让策略脚本整体失效。防套利不受影响：占位回落即 v0.1 基线，不高于任何蛊赋能动作。
2. **凡人进度系数对齐**（model.mjs `fight().multOf`）：蛊赋能动作在凡人段乘同一小境界进度系数 (1+0.3q)——g=r 时精确回到同阶预算 c×S，g<r 仍不继承宿主转数基数（跨转禁令不变）。修正前同阶蛊在阶段后半段恒低于所替换占位动作 30%（白玉蛊 40 点盾顶不住 59 点攻击，占位同位 67 点），消耗战系统性失真。仙人段 markFactor 本就同用，无改动。model.md §2.3 已增补对应说明。

### 8.2 重跑后的真实结论（30 种子/臂，supply.json v0.2-draft 参数下）

- **凡人段**：burst 一至五转全通；balanced/sustain 二转仍有 4–8/30 战败，为真实供应机制所致——月芒蛊/白玉蛊（秘方合炼，availability 0.4）30 种子仅 4 个满配二转核，19 个降级一转蛊、2 个落占位。**fallback 反序警示**：降级到低阶真蛊（一转月光/玉皮）比落 `gu:null` 占位更弱（占位=同阶预算），内容侧 fallback 排序应为「同阶蛊→gu:null」，低阶备蛊仅在成本/供应理由下使用。
- **仙段**：burst 基线完成率 27%（六转战败 9/长期筹备破产 7、八转战败 6）——原著当阶战斗核缺口（7–9 转几乎空白，九转强度实际由八转 fallback 承担）与仙段经济的真实交互；balanced/sustain 基线 0%。
- **场景**：supply_limited 使 burst 27%→23%、战败前移；key_gu_missing（月光家族 dropGu）对 balanced/sustain 二转核打击明显，对 burst 无增量（其核心不依赖该列表）；refine_tail 把 burst 压至 3%（九转长期筹备破产 6/30），炼制记账 697→1296 仙元石，与供应模型 §4.3 预测一致。
- **灾劫两口径**（占位动作）：聚合代理 burst/sustain 100%、balanced 36.7% → 实战口径 63.3%/0%/0%；sustain 30/30 败于六转天劫（soulBody 载体）。实战口径显著更难，未调参掩盖。

### 8.3 结果定性

以上是 v0.2-draft 参数下的研究发现，不是平衡结论：availability 0.4、灾劫载体数值、九转 fallback 结构均为设计值。它们回答本轮授权问题「供应限制/炼制失败/关键蛊缺失下的长期可行性」——在当前参数化下答案分别是不稳定、尾部致命、结构性缺口；参数校准与 L1 追认是下一步，不为全绿调参。

关联：[README](README.md)、[模型](model.md)、[参数](parameters.json)、[验证器](validate.mjs)、[验证报告](validation.md)、[完整结果](results.json)、[复核](review.md)、[供应模型](supply-model.md)、[供应数据](supply.json)。
