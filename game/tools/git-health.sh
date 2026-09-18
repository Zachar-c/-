#!/bin/bash
# tools/git-health.sh — .git 健康检查（防第七次损坏）
#
# 背景：本仓库 .git 已六次损坏，第六次根因是两个 pack 丢失 .idx 索引
# （时间戳 2026-09-12 01:33），导致 pack 内对象对 Git "不可见"。
# 详见 docs/q8g/GIT_CORRUPTION_INCIDENT_6.md
#
# 用法：bash tools/git-health.sh
# 退出码：0 = 健康；1 = 发现异常（需人工处理）

set -u

cd "$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "ERROR: not inside a git repository" >&2
    exit 1
}

fail=0

echo "=========================================="
echo " .git 健康检查  ($(date '+%Y-%m-%d %H:%M:%S'))"
echo "=========================================="

# ---------------------------------------------------------------
echo ""
echo "[1/6] pack / idx 配对"
echo "------------------------------------------"
idx_missing=0
for p in .git/objects/pack/*.pack; do
    [ -e "$p" ] || continue
    if [ ! -f "${p%.pack}.idx" ]; then
        echo "  ❌ MISSING IDX: $(basename "$p")"
        echo "     -> 修复：git index-pack \"$p\""
        idx_missing=1
        fail=1
    fi
done
[ "$idx_missing" -eq 0 ] && echo "  ✅ 所有 pack 均有配对 idx"

# ---------------------------------------------------------------
echo ""
echo "[2/6] pack 可读性（verify-pack）"
echo "------------------------------------------"
bad_pack=0
for p in .git/objects/pack/*.pack; do
    [ -e "$p" ] || continue
    if ! git verify-pack -v "$p" >/dev/null 2>&1; then
        echo "  ❌ BAD PACK: $(basename "$p")"
        bad_pack=1
        fail=1
    fi
done
[ "$bad_pack" -eq 0 ] && echo "  ✅ 所有 pack 可正常读取"

# ---------------------------------------------------------------
echo ""
echo "[3/6] fsck 断链计数"
echo "------------------------------------------"
fsck_out=$(git fsck 2>&1)
broken=$(echo "$fsck_out" | grep -cE "^broken link")
missing=$(echo "$fsck_out" | grep -cE "^missing")
echo "  broken link = $broken"
echo "  missing     = $missing"
echo "  已知基线：0（历史遗留固定值 2 亦可接受，见事故报告）"
if [ "$broken" -gt 2 ] || [ "$missing" -gt 2 ]; then
    echo "  ❌ 断链数超出已知基线"
    echo "$fsck_out" | grep -E "^(broken|missing)" | head -20 | sed 's/^/     /'
    fail=1
else
    echo "  ✅ 在已知基线内"
fi

# ---------------------------------------------------------------
echo ""
echo "[4/6] 未推送提交"
echo "------------------------------------------"
if upstream=$(git rev-parse --abbrev-ref '@{u}' 2>/dev/null); then
    unpushed=$(git rev-list --count '@{u}..HEAD' 2>/dev/null || echo "?")
    echo "  upstream = $upstream"
    echo "  unpushed = $unpushed"
    if [ "$unpushed" != "?" ] && [ "$unpushed" -gt 10 ]; then
        echo "  ⚠️  未推送提交偏多（>10）—— 堆积会显著放大损坏时的恢复难度"
    else
        echo "  ✅ 正常"
    fi
else
    echo "  ⚠️  当前分支无 upstream"
fi

# ---------------------------------------------------------------
echo ""
echo "[5/6] 已知损坏的 pack（历史遗留，应保持 0）"
echo "------------------------------------------"
legacy=0
for h in ad72bbbb78e5315385b52c3e28bb3e11a6934941 f3011e857bdc2a9e0c317ac4db34933a54fde58c; do
    if [ -f ".git/objects/pack/pack-$h.pack" ] && [ ! -f ".git/objects/pack/pack-$h.idx" ]; then
        echo "  ❌ 无 idx: pack-$h"
        legacy=1
        fail=1
    fi
done
[ "$legacy" -eq 0 ] && echo "  ✅ 无"

# ---------------------------------------------------------------
echo ""
echo "[6/6] 自动维护配置（应为关闭）"
echo "------------------------------------------"
ga=$(git config gc.auto || echo "(unset)")
ma=$(git config maintenance.auto || echo "(unset)")
echo "  gc.auto           = $ga"
echo "  maintenance.auto  = $ma"
if [ "$ga" = "(unset)" ] || [ "$ma" = "(unset)" ]; then
    echo "  ⚠️  建议执行以下命令防复发："
    echo "     git config gc.auto 0"
    echo "     git config maintenance.auto false"
    echo "     git config fetch.writeCommitGraph false"
fi

echo ""
echo "=========================================="
if [ "$fail" -eq 0 ]; then
    echo " ✅ 健康检查通过"
else
    echo " ❌ 发现异常，请按上述提示处理"
    echo "    详见 docs/q8g/GIT_CORRUPTION_INCIDENT_6.md"
fi
echo "=========================================="

exit $fail
