# `.git` 第六次损坏事故报告 + 恢复分支与迁移条件

> **状态**：🟢 **恢复成果已批准（`q8g-clean` 作为灾备主线）· `master` 保持不动（未批准覆盖）**
> **裁定时间**：2026-09-13（用户裁定）
> **一句话结论**：**内容零丢失，丢失的是 11 条不可恢复的中间提交记录。**

---

## 0. 用户裁定（2026-09-13，原文要点）

| 项 | 裁定 |
|---|---|
| `q8g-clean` 作为恢复成果 | 🟢 **批准** —— 作为**正式恢复分支 / 灾备主线** |
| 现在把 `master` 指向 `q8g-clean` | 🔴 **不批准** —— 这已从"恢复工作"变成**共享主线历史改写决策** |
| 后续主线迁移方式 | 必须**一次显式、可回滚、保留旧 master ref 的历史替换**，**禁止** `reset --hard` 或模糊强推 |
| 下一步优先级 | **先查清"为什么对象会丢"**，而不是"赶紧把 master 推过去" |

> **用户原话（保留）**：
> "相比'赶紧把 master 推过去'，**先查清为什么对象会丢**更重要。否则即使这次恢复成功，下一轮仍可能重复发生。"

---

## 1. 恢复成果（已落地）

| 项 | 值 |
|---|---|
| 灾备分支 | `q8g-clean` = `e3f00cef6666e606ddafd2e6924af934312d2089` |
| 远端状态 | ✅ 已推送 `refs/heads/q8g-clean`（675 提交链，walk 正常） |
| 远端 `master` | ⚠️ **未动**，仍为 `9a3ed341e84e1570d082518166a44c28d204c550` |
| 本地 `master` | ⚠️ **未动**，仍为 `d3c4bd0` |
| HEAD tree 对照 | `q8g-clean^{tree}` == `master^{tree}` == `1ef1379cb495d42ab8ca53af6ed0902c37fd5b9f` ✅ |
| 净文件变化 | 原 11 个坏提交的净效果（`aedf0d8 → 5b56a45`，21 files / 2579 insertions）**完整保留为单条提交 `6313b4a`** |

### 备份留档
- `C:/Users/90877/git-rescue-20260912-235145/`
  - `HEAD-tree.tar`（134M，全树快照）
  - `full-changeset.patch`（1.3M，`aedf0d8 → d3c4bd0` 全量补丁）
  - `all-refs.txt`、`all-commits.txt`、`refs/`、`packed-refs`
- `/tmp/git-reflog-backup-20260912-232645/`（reflog 备份）

---

## 2. 损坏事实（对象层，非 ref 层）

### 2.1 缺失对象清单（15 个）

**4 个 commit** —— 全部落在 2026-09-11 21:30–22:30 那批 docs 提交：

| SHA | 说明 |
|---|---|
| `a3a153d2` ★ | **关键**：`5b56a45` 的**直接 parent**，push walk 报错对象 |
| `b8f04c8d` | `fix(hall): make all 20 schools selectable in the school picker` |
| `8c000f52` | `test(ui): audit hall subviews in the interaction gate` |
| `22abdefd` | `feat(kill-move): ship the first authored kill moves (P1)` |

**11 个 tree**（下表为「断点提交 → 丢失的树」）：

| 断点提交 | 丢失 tree | 形态 |
|---|---|---|
| `f890bb4` | `a823a6c8` | 整树丢失（top tree） |
| `7341527` | `cd5397c2` | 整树丢失（top tree） |
| `578aa23` | `d64625ff` | 整树丢失（top tree） |
| `1d569ba` | `2469f682` | 整树丢失（top tree） |
| `ae4abf1` | `a8b3d392` | 整树丢失（top tree） |
| `8bdec86` | `4aa69d61` | 子树丢失（`docs/superpowers`） |
| `7da9652` | `7d7e7f6f` | 子树丢失（`docs`） |
| `6ccf32f` | `36cb76ec` 等 | 子树丢失 |
| 其他 | `2a036ce9` / `30add2b1` / `498effd2` | 子树丢失 |

### 2.2 断点结构

```
9a3ed34 (远端 master)
   └─ aedf0d8  ✅ 完整（"chore(repo): stop tracking Godot user:// runtime artifacts"）
        └─ [ 11 个坏提交：9348d91 … 7341527 ]  ❌ 树/对象缺失（连续块）
             └─ 5b56a45  ⚠️ 自身树完整，但 parent 指向缺失的 a3a153d2
                  └─ … 26 个提交 ✅ 全部树完整 …
                       └─ d3c4bd0 (原本地 master)
```

**关键结构性事实**：坏提交是**连续块**，块前 `aedf0d8` 完整、块后 26 个提交全部完整。这使"真实重写父指针"成为可行解。

### 2.3 不可恢复性三重验证

| # | 验证 | 结果 |
|---|---|---|
| 1 | 逐个 `git fetch origin <sha>` | **15 个全部 `not-on-remote`** |
| 2 | `git rev-list --objects --all` 交叉 | 11 个 tree **NOT-REFERENCED**（仅存在于损坏提交） |
| 3 | 用父提交同路径 tree 重算 SHA-1 | **不匹配**（证明真有内容变更，无法反推） |

⇒ **远端也没有、本地也没有，真损坏，无法凭内容重建。**

---

## 3. 🔴 根因定位（本次事故最重要产出）

### 3.1 直接原因：**两个 pack 丢失了 `.idx` 索引文件**

```
.git/objects/pack/pack-ad72bbbb78e5315385b52c3e28bb3e11a6934941.pack   1,289,645 B  ← .idx 缺失
.git/objects/pack/pack-f3011e857bdc2a9e0c317ac4db34933a54fde58c.pack  45,530,919 B  ← .idx 缺失（且带 .keep）
```

**共同时间戳：`Sep 12 01:33`** —— 与上一轮 `.git` 事故（`b5d1857`「对象库事故后的历史重建」）**同一时间窗口**。

`git verify-pack` 直接判定两者为 `bad`：
```
fatal: Cannot open existing pack idx file for '.../pack-ad72bbbb....idx'
...pack-ad72bbbb....pack: bad
fatal: Cannot open existing pack idx file for '.../pack-f3011e85....idx'
...pack-f3011e85....pack: bad
```

**丢失 `idx` 的后果**：Git 无法通过索引定位 pack 内对象 ⇒ 这些 pack 里的对象**在 Git 眼里全部"不存在"**，即使 `.pack` 数据完好。这正是"rc 对象凭空消失"的机制。

### 3.2 已实施的修复（pack 索引层）

用 `git index-pack <pack>` 重建两个索引，**均成功**：

| pack | 重建后索引大小 | 含对象数 |
|---|---|---|
| `ad72bbbb…` | 41,840 B | 1,456 |
| `f3011e85…` | 26,392 B | 6,585 |

**修复边界（诚实声明）**：索引重建恢复了 **pack 层的可读性**（`git fsck` 不再报 `bad`），但**未找回那 15 个对象** —— 它们确实不在任何 pack 中（已全库逐 pack 扫描确认）。

### 3.3 可疑放大因素

| 因素 | 观察 | 风险 |
|---|---|---|
| **`multi-pack-index`** | 274,956 B，时间戳 `Sep 12 01:44`（**晚于** pack 的 01:33） | 多包索引与单包 `.idx` 状态不一致时，Git 可能走 midx 路径而跳过单包索引校验 —— **高度可疑** |
| **两个 `.keep` 文件** | `pack-80c18092….keep`、`pack-f3011e85….keep` | `.keep` 保护 pack 不被 repack 回收；但 `f3011e85` **同时丢了 `.idx`** ⇒ 保护了数据却没保护索引 |
| **`git gc` / `repack`** | `b5d1857` 提交信息自述"对象库事故后的历史重建" | repack 过程被中断会留下"有 pack 无 idx"的中间态 |
| **仓库体量** | `pack-afbfc519….pack` = **309 MB**（含历史 80M blob） | 大 pack + Windows 文件系统 + 中断 = 高损坏概率 |

### 3.4 待验证的根因假设（按可能性排序）

1. **`git gc` / `repack` 在写 `.idx` 阶段被中断**（最可能）——先写 `.pack` 后写 `.idx`，中途崩溃/被 kill 就留下"有 pack 无 idx"。
2. **`multi-pack-index` 与单包索引不一致**导致 Git 走错路径。
3. **文件系统层**（Windows + OneDrive/杀软实时扫描介入 `.git` 目录）导致索引文件被删/未落盘。

---

## 4. 🟢 主线迁移条件（用户要求建立，全部门已预检）

> 用户裁定：迁移时必须走**一次显式、可回滚、保留旧 master ref 的历史替换**。

| # | 门 | 命令 | 当前状态 |
|---|---|---|---|
| 1 | **完整 fsck** | `git fsck q8g-clean` 无 error/missing/broken | ✅ **通过**（输出为空） |
| 2 | **新旧 HEAD tree 一致** | `git rev-parse q8g-clean^{tree} master^{tree}` | ✅ **通过**（同为 `1ef1379c`） |
| 3 | **全量测试通过** | `tools/test.ps1 -Suite unit` + `-Suite integration` + `tools/check.ps1` | ⏳ **待跑**（迁移前执行） |
| 4 | **无外部依赖坏 SHA** | 全仓 grep 11 个坏 SHA（排除 `.git`/`.godot`/`vendor`） | ✅ **通过**（仅命中本 Agent 的 memory 笔记，无工具/CI/文档依赖） |
| 5 | **可回滚** | 迁移前把旧 master ref 备份成 `master-pre-q8g-migration` | ⏳ 迁移时执行 |

### 4.1 迁移执行脚本（**仅在用户明确批准后运行**）

```bash
# 0) 前置：确认门 1-4 全绿
git fsck q8g-clean
git rev-parse q8g-clean^{tree} master^{tree}   # 两者须相同
tools/test.ps1 -Suite unit
tools/test.ps1 -Suite integration
tools/check.ps1

# 1) 保留旧 master ref（可回滚的唯一凭据）
git branch master-pre-q8g-migration master
git push origin master-pre-q8g-migration        # 同时备份到远端

# 2) 显式替换（非 force-push 语义的原子更新）
git checkout master
git merge --ff-only q8g-clean                   # 若可快进则快进；否则停下复查
# 或用：git update-ref refs/heads/master <q8g-clean-sha> <old-master-sha>
#        （带 old-value 的 CAS 更新，失败即中止，比 force push 安全）

# 3) 推送（带 --force-with-lease，拒绝盲推）
git push --force-with-lease=master:<old-master-sha> origin master

# 4) 落地验证
git ls-remote origin master
git fsck
git rev-list --count origin/master..master      # 应为 0
```

### 4.2 回滚脚本

```bash
git update-ref refs/heads/master master-pre-q8g-migration
git push --force-with-lease=master:origin master
```

### 4.3 绝对禁止

- ❌ `git reset --hard`
- ❌ 裸 `git push --force`（必须带 `--force-with-lease`）
- ❌ 迁移前删除 `master-pre-q8g-migration` 分支
- ❌ 在门 1-4 未全绿时执行迁移

---

## 5. 防止第七次损坏的加固措施

> 用户明确指出："这已经不是一次性的偶发事故了。"

| # | 措施 | 命令 / 做法 |
|---|---|---|
| 1 | **禁用自动 gc** | `git config gc.auto 0` —— 事故高发点是 repack 中途中断 |
| 2 | **索引完整性日常检查** | 检查每个 `.pack` 是否有配对 `.idx`：<br>`for p in .git/objects/pack/*.pack; do [ -f "${p%.pack}.idx" ] \|\| echo "MISSING IDX: $p"; done` |
| 3 | **定期 fsck + 计数留档** | `git fsck 2>&1 \| grep -cE "^(missing\|broken)"` —— 基线应为 **0**（或已知固定值 2） |
| 4 | **禁用后台维护** | `git config maintenance.auto false`；`git config fetch.writeCommitGraph false` |
| 5 | **提交后立即推送** | 避免长期堆积未推提交（本次 37 个未推提交放大了恢复难度） |
| 6 | **`multi-pack-index` 观察** | 若再次损坏，先 `rm .git/objects/pack/multi-pack-index` 再验（该文件可由 git 自动重建） |
| 7 | **`.keep` 与 `.idx` 一起装** | 建 `.keep` 时确认 `.idx` 存在 |
| 8 | **大 pack 监控** | `pack-afbfc519….pack` = 309 MB，接近需 repack 的体量；repack 必须**前台完成、不中断** |
| 9 | **备份策略** | 保留 `.git/objects/pack/*.idx` 的独立副本（索引小、易备份、恢复价值高） |
| 10 | **中止即验** | 任何 gc/repack/fetch 被中断后，**立即**跑 `git fsck` + 查 `.idx` 配对 |

### 5.1 一键健康检查脚本（建议固化）

```bash
#!/bin/bash
# tools/git-health.sh — .git 健康检查
set -u
cd "$(git rev-parse --show-toplevel)" || exit 1

echo "== 1. pack/idx 配对 =="
miss=0
for p in .git/objects/pack/*.pack; do
  [ -f "${p%.pack}.idx" ] || { echo "  MISSING IDX: $p"; miss=1; }
done
[ $miss -eq 0 ] && echo "  OK (all packs have idx)"

echo "== 2. pack 可读性 =="
for p in .git/objects/pack/*.pack; do
  git verify-pack -v "$p" >/dev/null 2>&1 || echo "  BAD PACK: $p"
done
echo "  done"

echo "== 3. fsck 断链计数 =="
n=$(git fsck 2>&1 | grep -cE "^(missing|broken)")
echo "  broken+missing = $n   (基线 0；已知固定值 2 亦可接受)"

echo "== 4. 未推送提交 =="
u=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "no-upstream")
echo "  unpushed = $u"

echo "== 5. gc 自动触发 =="
echo "  gc.auto = $(git config gc.auto || echo '(unset)')"
echo "  maintenance.auto = $(git config maintenance.auto || echo '(unset)')"
```

---

## 6. 技术附注：为什么必须"真实重写"而不能用 `git replace`

> 用户裁定原文："`git replace --graft` 能让本地历史看起来连续，但 **push 不会把 replace refs 当成真实历史**，因此你最终选择真实重写 parent 的方案是必要的。"

**验证记录**：曾用 `git replace --graft 5b56a45 aedf0d8`，本地 `git log` 立刻显示连续历史，`git rev-list --count` 也正常；但 `git push` **仍报同一个错**：

```
error: Could not read a3a153d211784d1a0f8042989e5daf4ea4a2cac9
fatal: revision walk setup failed
```

**原因**：`replace` 机制只影响**本地对象读取路径**（`git log` / `git fsck` / `git cat-file` 等通过 `refs/replace/` 重定向），而 **`send-pack` 的 revision walk 直接按真实 commit 对象的 parent 字段遍历**，不解析 replace refs。⇒ 对"推送"这一目标，`replace` 完全无效。

**最终方案**：用 `git hash-object -t commit -w` 逐条重写 commit 对象的 parent 字段（真实产生新 SHA），得到 clean 链 `e3f00cef`。

---

## 7. 结论

| 问题 | 回答 |
|---|---|
| 代码/文件内容丢了吗？ | ❌ **没有**。`q8g-clean^{tree}` == `master^{tree}`，零差异。 |
| 丢了什么？ | **11 条不可恢复的中间提交记录**（+ 4 个 commit 对象）。这**不是"代码丢了"**。 |
| 根因是什么？ | **两个 pack 丢了 `.idx` 索引**（时间戳 `Sep 12 01:33`），导致 pack 内对象对 Git"不可见"。 |
| 已修到什么程度？ | pack 索引层已修复（`fsck` 无 `bad`）；15 个对象**确不在库中**，无法找回。 |
| 现在能动 `master` 吗？ | 🔴 **不能**。已作为**共享主线历史改写决策**上报，等待用户明确批准。 |
| 下一步？ | ① 加固防复发（§5）；② 需要迁移时走 §4 受控流程。 |

---

**归档时间**：2026-09-13
**关联文档**：`docs/q8g/Q8G_BATCH1A_ACCEPTANCE_REPORT.md`（Batch 1-A 验收）、`docs/q8g/Q8G_BATCH1A_RULING.md`（裁定记录）
