# -*- coding: utf-8 -*-
"""按行号从 CP936 源文中提取一批文本，写出 UTF-8 无 BOM。对齐 extract_batch.ps1。"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gu_tools import PsArgs, read_gbk_lines, write_utf8_no_bom


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

    lines = read_gbk_lines(source)
    selected = lines[start - 1:end]
    write_utf8_no_bom(output, '\n'.join(selected))
    print('提取 {0} 行 -> {1}'.format(len(selected), output))


if __name__ == '__main__':
    main()
