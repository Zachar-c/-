#!/usr/bin/env python3
"""契约漂移守门（W8, 2026-09-09）。

提取 docs/contracts/2026-09-02-domain-ui-contract.md 中反引号包裹的 snake_case
标识符，在 scripts/ + tests/ + data/ 全库检索；缺失项即契约-实现漂移，exit 1。

教训（首版比对 2026-09-09）：扫描面必须含 tests/ 与 data/ —— 首版只扫 scripts/
把 test_command_rejections_v2（tests/unit 下）与 gu_rot_pact_accept（data/
dialogues 下）误判为漂移；另一起"真漂移"实为契约文档拼写错误
(beastiality->bestiality_endpoint_check，代码 soul_rules.gd:152 拼写正确)。

用法: python tools/check_contract_drift.py   （cwd=仓库根；check.ps1 调用）
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTRACT = os.path.join(ROOT, "docs", "contracts", "2026-09-02-domain-ui-contract.md")

# 豁免白名单：逐项写理由，不留无注释条目。
WHITELIST = {
    # 契约里引用的旧测试名/历史占位；若重新出现请移除。
}

_SCAN_DIRS = ["scripts", "tests", "data"]
_EXT = (".gd", ".json", ".dialogue")


def main() -> int:
    doc = io.open(CONTRACT, encoding="utf-8").read()
    ids = {i for i in re.findall(r"`([a-z][a-z0-9]*(?:_[a-z0-9]+)+)`", doc)
           if not i.endswith((".gd", ".json", ".dialogue"))}

    src = ""
    for d in _SCAN_DIRS:
        base = os.path.join(ROOT, d)
        if not os.path.isdir(base):
            continue
        for root, _dirs, files in os.walk(base):
            for f in files:
                if f.endswith(_EXT):
                    # 拼接相对路径 + 文件名：契约里对测试/数据的引用常指文件名
                    # （如 test_command_rejections_v2），仅内容匹配会漏。
                    src += f + "\n"
                    src += io.open(os.path.join(root, f), encoding="utf-8",
                                   errors="ignore").read()

    missing = sorted(i for i in ids
                     if i not in src and i not in WHITELIST)
    if missing:
        print("CONTRACT DRIFT: %d identifier(s) declared in the contract are "
              "missing from scripts/ tests/ data/:" % len(missing))
        for m in missing:
            print("  - %s" % m)
        return 1
    print("contract drift: ok (%d identifiers resolved)" % len(ids))
    return 0


if __name__ == "__main__":
    sys.exit(main())
