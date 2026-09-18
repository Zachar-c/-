# -*- coding: utf-8 -*-
"""按行号从源文中提取一批文本，写出 UTF-8 无 BOM。
源编码自动检测（UTF-8 优先，失败回退 CP936）；输出命名为 *.utf8.txt。
对齐 extract_batch.ps1 的参数，输出编码按方案 B 统一为 UTF-8。"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gu_tools import PsArgs, read_source_lines, write_utf8_no_bom, print_console


def main():
    args = PsArgs(specs=[
        ('SourcePath', 'string'),
        ('StartLine', 'int'),
        ('EndLine', 'int'),
        ('OutputPath', 'string'),
    ])
    source = args.require('SourcePath')
    start = args.require('StartLine')
    end = args.require('EndLine')
    output = args.require('OutputPath')

    lines = read_source_lines(source)
    if start < 1:
        raise SystemExit('StartLine must be >= 1, got {0}'.format(start))
    if end > len(lines):
        raise SystemExit('EndLine {0} exceeds source line count {1}'.format(end, len(lines)))
    selected = lines[start - 1:end]
    write_utf8_no_bom(output, '\n'.join(selected))
    print_console('提取 {0} 行 -> {1}'.format(len(selected), output))


if __name__ == '__main__':
    main()
