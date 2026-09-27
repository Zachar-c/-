# 一局蛊途：两世蛊方闭环验证

日期：2026-09-27。状态：**原型功能已验证，玩家体验未验证**。本页记录 `working/gu-run-proto/` 的本地实验；`working/` 被 Git 忽略，原型尚未接入 Web 产品。它不修改 PRD、不把实验数值写成原著规则。

## 验证问题

同一局面下，已知蛊方能否让第二世改变路线、采购与炼蛊时机，并在战斗中形成可见差异？跨世只保留知识，转数、蛊虫、元石和伤势重置。

## Canon 与原型边界

| 原著依据 | 原型采用 | 边界 |
|---|---|---|
| [月光蛊](../../../lore/wiki/gu/moonlight-gu.md) ST-MOONLIGHT-06 与[小光蛊](../../../lore/wiki/gu/small-light-gu.md) ST-SMALLLIGHT-03：双蛊同催使月刃攻击与体积翻倍，两只小光不叠加 | 月光 + 小光同回合协同 | “月刃同心”等组合名及额外效果为游戏设计 |
| [月芒蛊](../../../lore/wiki/gu/moon-glow-gu.md) ST-MOONGLOW-01/03/04：月光 + 两只小光合炼二转月芒，攻击力为月光三倍 | 知方、凑第二只小光、炼成；基础攻击按三倍对应 72 点 | 72 点、AP、冷却、95% 成功率、失败伤害均为研究模型或原型值；月芒失败的通用损耗仍未核定 |
| [蛊虫总表三期](../../../lore/wiki/gu/roster-3.md) `white_jade_gu` 与[蛊的饲养与炼化](../../../lore/wiki/world/gu-care-and-refinement.md)：白豕 + 玉皮合炼白玉，白玉二转 | 原型持有后按二转门槛限制出战 | 商队抄方、闭关冲转成本与五段节奏都是实验设计 |

Wiki 的[蛊虫关系](../../../lore/wiki/gu/gu-relations.md)现把这两条合炼链的转数和证据锚点列在同一表内。蛊方跨世保存属于《问真》设计，不作为原著轮回法则。

## 已跑通的两世对照

固定种子 `20260927`。第一世选闭关冲二转，在商队花 8 元石并占用该段抄月芒方；后来才买到第二只小光，已错过炼台。完成终验后只提交蛊方知识。

刷新页面进入第二世后，一转、48 元石、初始四蛊重置，月芒方仍已知。同一个商队节点改用来买第二只小光，下一段便能实际合炼月芒；月光和双小光被投入，二转月芒进入编制并对敌造成可观察伤害。另测得：一转可持有炼成的二转白玉蛊，但不能编入战斗；未完成本世即刷新时，刚抄到的方不会进入永久记忆。

## 验收与剩余问题

在 `working/gu-run-proto/playtest/` 运行：

```powershell
node model_link.mjs
node run_test.mjs
node two_lives_test.mjs
```

结果分别为 `MODEL LINK PASS`、`RUN PROTO CHECKS PASSED`、`TWO-LIFE CONTRACT PASSED`；320px 手机宽度无横向溢出。Wiki 门禁 `lore/wiki/tools/check.ps1` 为 `ALL CHECKS PASSED`，G0 `tools/docs-lint.mjs` 为 `FAIL 0 / WARN 0`（Wiki 对本地原文缺席给已知 WARN）。

脚本只证明规则和流程确实运行，**还不能证明人会因为蛊方知识自发改变选择**。下一次产品判断应让不了解脚本的玩家连续玩两世，观察他们是否主动提前买第二只小光、何时愿为破境牺牲首段收益、是否觉得炼成后打法改变有价值。通过前，不把这份五段原型当作 PRD 所要求的完整长局，也不把 `working/` 本地代码直接并入 `game/wenzhen-web-lab/`。
