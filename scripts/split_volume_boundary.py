# -*- coding: utf-8 -*-
"""卷一/卷二边界拆分：在“第一节：黄龙江上竹筏倾”处切开，去重并回写两侧文件。对齐 split_volume_boundary.ps1。"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gu_tools import PsArgs, repo_abs, read_utf8, write_utf8_no_bom, print_console


def main():
    args = PsArgs(specs=[
        ('Source', 'string'),
        ('Destination', 'string'),
    ], defaults={
        'Source': 'volumes/01-魔性不改/vol1-sec181-199.edited.txt',
        'Destination': 'volumes/02-魔子出山/vol2-sec001.edited.txt',
    })
    source = repo_abs(args.get('Source'))
    destination = repo_abs(args.get('Destination'))

    text = read_utf8(source)
    marker = '第一节：黄龙江上竹筏倾'
    first = text.find(marker)
    if first < 0:
        raise SystemExit('Boundary marker not found: {0}'.format(marker))

    volume_one = text[:first].rstrip() + '\r\n'
    volume_two = text[first:]
    duplicate = marker + '\r\n\r\n' + marker
    volume_two = volume_two.replace(duplicate, marker).rstrip() + '\r\n'

    os.makedirs(os.path.dirname(destination), exist_ok=True)
    write_utf8_no_bom(source, volume_one)
    write_utf8_no_bom(destination, volume_two)

    print_console('VolumeOneCharacters: {0}'.format(len(volume_one)))
    print_console('VolumeTwoCharacters: {0}'.format(len(volume_two)))
    print_console('BoundaryOccurrences:  {0}'.format(volume_two.count(marker)))
    print_console('VolumeOneEndsCorrectly: {0}'.format(volume_one.rstrip().endswith('“中洲？！”方正震惊得大叫。')))


if __name__ == '__main__':
    main()
