# 可独立派发的任务包

日期：2026-10-03。每个任务文件全文可直接复制给一个Agent，包含独立上下文、写入边界和验收要求。任务使用当前未提交工作区基线；主代理负责共享状态、生成数据、主包同步和最终验收。

A优先处理续档/战斗闭环；A–E可以在独立副本并行，F先做独立基线审查，最后在集成版本再实测。各包只回传自己的源diff与RESULT，避免同时修改main或js/data.js。

| 包 | 任务 | 回传 |
|---|---|---|
| A | [P0：自由组合、战斗与续档闭环](A_core.md) | [A 包结果](RESULT_A.md) |
| B | [P1：组合规则与跨道准入](B_combat.md) | [B 包结果](RESULT_B.md) |
| C | [P1：后期敌人和路线内容](C_encounters.md) | [C 包结果](RESULT_C.md) |
| D | [P1：经济漏洞与投资竞争](D_economy.md) | [D 包结果](RESULT_D.md) |
| E | [P1：构筑与路线界面可玩性](E_experience.md) | [E 包结果](RESULT_E.md) |
| F | [P0：独立成品差距与实测验收](F_acceptance.md) | [F 包结果](RESULT_F.md) |

基线文件哈希见 [BASELINE.json](BASELINE.json)。任务结果返回后由主代理核对实际改动、重新生成数据、跑集成与整局验证，再同步Windows主包。
