# Caveman Review Packet

> 默认 300–500 中文字；异常可展开。只保留事实、证据、风险、决定。代码符号、路径、命令、错误、测试数字原样保留。

```text
TASK <task-id>
PHASE <phase/batch>
STATUS READY_FOR_REVIEW | PARTIAL | BLOCKED
TYPE architecture | implementation | content | bugfix | infrastructure | migration | canonical_asset | theme_skin_asset
ASK <审阅者要决定什么>

GOAL
<本次目标；范围外事项>

DELTA
+ <新增>
~ <修改>
- <删除>
= <未变但已验证；无则 NONE>

STATE
<当前能力/执行器/模型，使用 VERIFIED | PARTIALLY VERIFIED | CANDIDATE | UNVERIFIED | BLOCKED>

FILES
<path> — <修改>

TEST
focused: <command> → PASS/FAIL + numbers
relevant: <command> → PASS/FAIL + numbers
full: <command> → PASS/FAIL/BLOCKED + decisive reason
diff-check: PASS/FAIL

WORKER
<worker/model>
core patch: YES/NO
tests: YES/NO
protocol: YES/NO
Codex takeover: NONE | audit-only | implementation
independent: YES/NO

RISK
<真实问题、影响、new/pre-existing、是否阻塞>
UNPROVEN <假设/未实证；无则 NONE>

GIT
status: <summary>
commit: <hash/NONE>
merge: <hash/NONE>
push: YES/NO

DECISION
D1 <问题> | recommend YES/NO | <理由>
D2 <问题> | recommend YES/NO | <理由>

NEXT
<最多 3 步>
STOP

EVIDENCE
<需要展开时给路径；不复制长日志>
```

蛊虫视觉任务使用独立任务包模板：
`ai-system/visual-asset-task-packet-template.md`。

Lore 任务额外追加：
```text
FACT <原著事实 + source>
ANALYSIS <分析/推导>
UNCHECKED <待核对>
```

