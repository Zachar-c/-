# P0：自由组合、战斗与续档闭环

工作目标是交付《蛊真人》成品游戏，唯一主实现为 game/wenzhen-web-lab/lab.html。仓库当前路径 /home/usrs/dev/codex-test。不得另造原型、规则引擎或替换技术路线。用户优先级：采购奖励与路线55%，构筑差异30%，操作战斗反馈15%。原著以 lore/wiki/ 与其 EPUB 锚点为依据；游戏数值和会话构想不等于原著事实。

先读根 AGENTS.md、PROJECT_MAP.md、docs/PRODUCT_REQUIREMENTS_v1.0.md、目标目录 README.md 和 docs/lab-runtime-contract.md。以当前未提交工作区为基线，不可仅使用远端或HEAD；当前应存在 composeKillMove、currentKillMoves 和自由同催草案。确认 BASELINE.json 中相关文件的基线。使用独立工作副本；其他包同时工作，严格遵守写入边界。Windows实测也使用独立副本，不覆盖 C:\Users\Public\GuBuildLab\main-game-20261003-r2 主包。若问题跨出本包写入边界，在RESULT定位并交主代理，不直接修改其他包文件。可在自己副本生成 js/data.js 自测，但不回传生成产物，主代理统一重建。不要提交、推送、部署或修改其他原型。

当前正常路径证据：305项非浏览器检查通过；战斗集成13项通过，其中12项真实网页、1项隔离夹具。自由三组件配方有真实保存、续档、扣费和战斗记录；最后一次新增删除续档检查也定向通过。它仍只有月光、小光、月芒三类可组，当前55节点不满足产品200–300有效节点/3–5小时目标。不得把这些局部结果当成成品验收。

回传到本包对应 RESULT 文件：变更文件与diff、问题根因、原著依据/实验适配区分、检查命令与真实输出、浏览器证据路径、未验证项、需主代理集成的接口或生成步骤。没有浏览器时明确未运行，不用模拟状态冒充实际游玩。不修改总README、全局Issue、MANIFEST或其他包结果；主代理最终检查和集成。

## 本包任务

修正自由组合的主流程边界，保持真实组件成本与实例占用。已发现两处具体问题：草案的rankReady仅判断修为，却显示“当前可催动”，没有证明真元/操控足够；损坏存档可保存无法派生的自定义recipe及孤儿equipped ID，currentKillMoves过滤配方后，战斗准备面板仍可能读取不存在的m.label并崩溃、占空槽。优先修正。

允许写入：js/main.js、js/battle.js、js/lab_save.js；tests/lab_combat.test.mjs、tests/lab_lifecycle.test.mjs、tests/lab_transactions.test.mjs、tests/lab_save.test.mjs；本包RESULT。不得改GuRules接口、界面编辑器、数据或其他测试文件。

具体工作：加载时验证/修复无效自定义配方并同步清除孤儿装备，兼容没有新字段的旧档；显示明确且与useMove一致的修为/组件/真元/操控门禁；验证自由配方在卖出或合炼吃掉组件后卸下，结束局不能编辑，新局清空，草案/装备/战斗续档一致。费用每次从组件派生，不接受存档注入费用、效果或原著命名。不得修改战后补元、魂魄上限、伤害或价格。

验收：真实正常按钮完成组装→记忆→装备→战斗→补给→删除→刷新；两份相同组件按两个实例计数，催动占一次行动并付完整成本，反击吞招也不能退费用；损坏档和旧档回归；完整相关测试。纯夹具与真实网页结果分别计数。

回传文件：`game/wenzhen-web-lab/docs/agent-tasks/RESULT_A.md`。
