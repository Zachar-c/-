# -*- coding: utf-8 -*-
"""《蛊真人》编辑工作流共享工具：PowerShell 风格参数解析、中文数字转换、编码与输出辅助。

由各个 .py 脚本 import 使用，行为对齐原 .ps1 脚本（参数名大小写不敏感、GBK/UTF-8 编码规则一致）。
"""
import csv
import io
import json
import os
import re
import subprocess
import sys
from collections import OrderedDict

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def repo_path(relative):
    return os.path.join(REPO_ROOT, relative)


def repo_abs(path):
    """将相对路径解析为绝对路径（相对仓库根）。"""
    return os.path.abspath(os.path.join(REPO_ROOT, path)) if not os.path.isabs(path) else os.path.abspath(path)


def read_gbk_lines(path):
    """按 CP936 读取文本，返回行列表（去掉行尾换行）。"""
    with io.open(path, 'r', encoding='gbk', newline='') as fh:
        return fh.read().splitlines()


def read_source_lines(path):
    """自动检测编码读取源文/底稿：UTF-8（含 BOM）优先，失败退回 CP936。"""
    try:
        with io.open(path, 'r', encoding='utf-8-sig', newline='') as fh:
            return fh.read().splitlines()
    except (UnicodeDecodeError, UnicodeError):
        return read_gbk_lines(path)


def read_utf8(path):
    with io.open(path, 'r', encoding='utf-8', newline='') as fh:
        return fh.read()


def write_utf8_no_bom(path, text):
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    with io.open(path, 'w', encoding='utf-8', newline='') as fh:
        fh.write(text)


def write_utf8_bom(path, text):
    """PS 的 Set-Content -Encoding UTF8 会写 BOM，保持一致。"""
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    with io.open(path, 'w', encoding='utf-8-sig', newline='') as fh:
        fh.write(text)


def write_csv_utf8_bom(path, rows):
    """PS Export-Csv 语法：列头 + 逗号分隔，UTF-8 带 BOM。"""
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    with io.open(path, 'w', encoding='utf-8-sig', newline='') as fh:
        writer = csv.DictWriter(fh, fieldnames=list(rows[0].keys()) if rows else [])
        if rows:
            writer.writeheader()
            for row in rows:
                writer.writerow({k: ('' if v is None else v) for k, v in row.items()})


def write_json(path, obj):
    write_utf8_bom(path, json.dumps(obj, ensure_ascii=False, indent=2))


# ---------------------------------------------------------------- 中文数字

DIGITS = {
    0x96F6: 0,    # 零
    0x3007: 0,    # 〇
    0x4E00: 1,    # 一
    0x4E8C: 2,    # 二
    0x4E24: 2,    # 两
    0x4E09: 3,    # 三
    0x56DB: 4,    # 四
    0x4E94: 5,    # 五
    0x516D: 6,    # 六
    0x4E03: 7,    # 七
    0x516B: 8,    # 八
    0x4E5D: 9,    # 九
}
UNITS = {
    0x5341: 10,    # 十
    0x767E: 100,   # 百
    0x5343: 1000,  # 千
    0x4E07: 10000, # 万
}


def chinese_number(text):
    """把“第一百二十节”里的数字串转成 int。兼容 build_index 的完整实现。"""
    if re.match(r'^\d+$', text):
        return int(text)
    total = 0
    section = 0
    number = 0
    for ch in text:
        code = ord(ch)
        if code in DIGITS:
            number = DIGITS[code]
            continue
        if code in UNITS:
            unit = UNITS[code]
            if number == 0:
                number = 1
            if unit == 10000:
                section = (section + number) * unit
                total += section
                section = 0
            else:
                section += number * unit
            number = 0
    return total + section + number


def chinese_section_number(text):
    """create_volume_baselines 用的简化版（无千/万），处理‘十’与‘零’。"""
    TEN = chr(0x5341)
    ZERO = chr(0x96F6)
    if text == TEN:
        return 10
    text = text.replace(ZERO, '')
    total = 0
    hundred = chr(0x767E)
    idx = text.find(hundred)
    if idx >= 0:
        total += DIGITS[ord(text[0])] * 100
        text = text[idx + 1:]
    idx = text.find(TEN)
    if idx >= 0:
        total += 10 if idx == 0 else DIGITS[ord(text[0])] * 10
        text = text[idx + 1:]
    if len(text) > 0:
        total += DIGITS[ord(text[0])]
    return total


# ---------------------------------------------------------------- 噪声标记

def noise_flags(line, title):
    """与 build_index / normalize_source_index 的 Get-NoiseFlags 行为一致。"""
    text = u'{0} {1}'.format(line, title)
    flags = []
    if re.search(u'目录|章节目录', text):
        flags.append('directory')
    if re.search(u'作者|作家|卷末感言|完本感言|新书|更新|订阅|月票|推荐票|未完待续|（?\\s*(?:ps|PS)\\s*[：:]', text):
        flags.append('author_or_site')
    if re.search(u'www\\.|http://|https://|手机用户|请收藏|精彩阅读|</?\\w+[^>]*>', text):
        flags.append('site_markup')
    return ';'.join(flags)


def noise_flags_normalized(line, title):
    """normalize_source_index 的版本（directory_or_page 等）。"""
    text = u'{0} {1}'.format(line, title)
    flags = []
    if re.search(u'目录|章节目录|强弱\\(第\\d+/第\\d+页\\)', text):
        flags.append('directory_or_page')
    if re.search(u'作者|作家|共识感言|完本感言|新书|更新|订阅|月票|推荐票|未完待续|\\(?\\s*(?:ps|PS)\\s*[：:]', text):
        flags.append('author_or_site')
    if re.search(u'www\\.|https?://|手机用户|请收藏|收藏|</?\\w+[^>]*>', text):
        flags.append('site_markup')
    return ';'.join(flags)


# ---------------------------------------------------------------- 参数解析

class PsArgs(object):
    """PowerShell 风格命令行解析：-Name Value / -Switch，大小写与连字符不敏感。"""

    def __init__(self, argv=None, specs=None, defaults=None):
        argv = list(sys.argv[1:] if argv is None else argv)
        specs = specs or []   # [('SourcePath', 'str'), ('StartLine', 'int'), ...]
        defaults = defaults or {}
        self.values = {}
        self.switches = {}
        name_map = {name.lower().replace('-', ''): name for name, _ in specs}
        bool_names = {name.lower().replace('-', ''): name for name, _ in specs if _ == 'bool'}
        i = 0
        while i < len(argv):
            token = argv[i]
            if not token.startswith('-'):
                raise SystemExit('Unexpected positional argument: {0}'.format(token))
            raw = token[1:]
            key = raw.lower().replace('-', '')
            if key in bool_names:
                self.values[bool_names[key]] = True
                i += 1
                continue
            if key not in name_map:
                raise SystemExit('Unknown parameter: -{0}'.format(raw))
            if i + 1 >= len(argv):
                raise SystemExit('Missing value for parameter: -{0}'.format(raw))
            value = argv[i + 1]
            name, kind = next((n, k) for n, k in specs if n.lower().replace('-', '') == key)
            if kind == 'int':
                self.values[name] = int(value)
            elif kind == 'string':
                self.values[name] = value
            elif kind == 'string[]':
                self.values[name] = [v for v in value.split(',') if v]
            elif kind == 'bool':
                self.values[name] = value.lower() in ('true', '1', 'yes')
            else:
                raise SystemExit('Unsupported parameter kind: {0}'.format(kind))
            i += 2
        for name, _ in specs:
            if name not in self.values:
                self.values[name] = defaults.get(name)
        self.specs = specs

    def get(self, name, default=None):
        value = self.values.get(name, default)
        return default if value is None else value

    def require(self, name):
        value = self.values.get(name)
        if value is None or (isinstance(value, list) and not value):
            raise SystemExit('Missing required parameter: -{0}'.format(name))
        return value


def git_silent(repo, *args):
    """带 CRLF 警告抑制的 git 调用（对齐 PS 版 2>$null 语义），仅返回 stdout 行。"""
    proc = subprocess.Popen(['git', '-C', repo] + list(args),
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    stdout, _ = proc.communicate()
    return stdout.decode('utf-8', errors='replace').splitlines()


def git_status_short(repo):
    return git_silent(repo, 'status', '--short')


def git_log_oneline(repo, count=6):
    return git_silent(repo, 'log', '--oneline', '-{0}'.format(count))


def git_ls_files(repo, *pathspec):
    return git_silent(repo, '-c', 'core.quotePath=false', 'ls-files', *pathspec)


def print_console(text):
    """向控制台输出 UTF-8（无论重定向与否都以 utf-8 写出，避免 PS 乱码）。"""
    try:
        sys.stdout.buffer.write(text.encode('utf-8'))
        sys.stdout.buffer.write(b'\n')
        sys.stdout.buffer.flush()
    except Exception:
        print(text)