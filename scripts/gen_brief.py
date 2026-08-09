# -*- coding: utf-8 -*-
"""批次上下文简报生成器：为 AI 会话生成开工恢复简报，避免逐个全读台账/细纲/正文。
对齐 gen_brief.ps1。用法：
  py -3 scripts/gen_brief.py -Volume vol2 -Batch 001-030
  py -3 scripts/gen_brief.py -Volume vol2 -Batch 151-180 -BriefOut working/brief.md
  py -3 scripts/gen_brief.py -Volume vol2 -Batch 151-180 -WriteState
注意：简报是导航，不是原文；台账匹配行只列举与本批次相关的记录，未命中时仍需读全文。"""
import io
import json
import os
import re
import sys
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gu_tools import PsArgs, REPO_ROOT, git_silent, git_status_short, git_log_oneline, print_console

REGISTER_NAMES = [
    'decision-register',
    'combat-ledger',
    'resource-audit',
    'information-ledger',
    'chronology-geography',
    'character-state-ledger',
    'structural-surgery',
]

STATE_TEMPLATE = u'''# 批内状态卡：{0}-sec{1}

> 本文件在批内维持：换会话、上下文压缩或间隔较久后，先读它恢复中间状态。
> 批末时把实际落地内容并入正式台账（由总编会话执行），随后删除本文件。
> 未落地为正文状态的内容禁止写入"已裁决"；只记录事实。

## 开场状态（开工前自台账核对）

- 时间：
- 人物（修为 / 蛊组 / 伤势）：
- 资源（现金 / 物资 / 债务）：
- 身份 / 位置：
- 读者已知信息边界：
- 本批关联冻结裁决（引用台账 ID）：

## 批内进程

（逐节或每数节记录：该节结束时的状态、裁决与变化）

## 批末状态（收尾并入正式台账）

- 时间：
- 人物：
- 资源：
- 信息边界：
- 待总编裁决项：
'''


def summarize_hit(text):
    """台账命中行收窄展示：表格行抽取关键列 + 裁决/项目摘要，正文行截断。"""
    if text.startswith('|') and text.endswith('|'):
        cells = [c.strip() for c in text.strip('|').split('|')]
        if len(cells) >= 4:
            key_id = cells[0]
            if len(cells) >= 8:
                kind = cells[2]
                scope = cells[3]
                verdict = cells[6]
                status = cells[-1]
            else:
                kind = cells[2] if len(cells) >= 3 else u''
                scope = cells[1]
                verdict = cells[-1]
                status = cells[-2]
            if len(verdict) <= 12 and len(cells) >= 5:
                verdict = cells[4]
            cut = verdict[:44] + (u'…' if len(verdict) > 44 else u'')
            return u'{0} [{1}] {2}：{3}（状态：{4}）'.format(key_id, kind, scope, cut, status)
    if text.startswith('#'):
        return text
    if len(text) > 72:
        for cut_at in (72, 64, 56, 48):
            if len(text) > cut_at and text[cut_at - 1] in u'。．！？；，、':
                return text[:cut_at] + u'…'
        return text[:72] + u'…'
    return text


def main():
    args = PsArgs(specs=[
        ('Volume', 'string'),
        ('Batch', 'string'),
        ('BriefOut', 'string'),
        ('WriteState', 'bool'),
        ('RepoRoot', 'string'),
    ], defaults={
        'Volume': 'vol2',
        'Batch': '',
        'RepoRoot': REPO_ROOT,
    })
    volume_id = args.get('Volume')
    batch = args.get('Batch')
    brief_out = args.get('BriefOut')
    write_state = args.get('WriteState') or False
    repo_root = os.path.abspath(args.get('RepoRoot'))

    def repo_path(relative):
        return os.path.join(repo_root, relative)

    def get_relative(path):
        return path[len(repo_root):].lstrip('\\/')

    def outline_path(vol_id, rng):
        return repo_path(u'outlines\\detail\\{0}-sec{1}.md'.format(vol_id, rng))

    config_path = repo_path('config\\editorial-volumes.json')
    if not os.path.isfile(config_path):
        raise SystemExit('Missing editorial volume configuration: {0}'.format(config_path))
    with io.open(config_path, 'r', encoding='utf-8-sig') as fh:
        volume_config = json.load(fh)
    vol_cfg = next((v for v in volume_config['volumes'] if v['id'] == volume_id), None)
    if not vol_cfg:
        raise SystemExit('Unknown volume: {0}. Known ids: {1}'.format(
            volume_id, ','.join(v['id'] for v in volume_config['volumes'])))

    volume_root = repo_path('volumes')
    volume_dir = None
    if os.path.isdir(volume_root):
        for name in sorted(os.listdir(volume_root)):
            if os.path.isdir(os.path.join(volume_root, name)) and re.fullmatch(
                    vol_cfg['directoryPattern'].replace('.', r'\.').replace('*', '.*'), name):
                volume_dir = os.path.join(volume_root, name)
                break

    lines = []

    def brief(text=''):
        lines.append(text)

    brief(u'# 《蛊真人》批次上下文简报：{0}-sec{1}'.format(vol_cfg['id'], batch if batch else 'ALL'))
    brief('')
    brief(u'- 生成时间：' + datetime.now().strftime('%Y-%m-%d %H:%M'))
    try:
        head = git_silent(repo_root, 'log', '-1', '--oneline')
        if head:
            brief(u'- Git HEAD：' + head[0])
    except Exception:
        pass
    brief('')

    brief('## 1. 本卷批次进度（卷内所有批次）')
    brief('')
    brief('| 批次 | 正文 edited.txt | 细纲 |')
    brief('| --- | --- | --- |')
    for batch_item in vol_cfg['batches']:
        endpoint = u'{0}-sec{1}'.format(vol_cfg['id'], batch_item['range'])
        if volume_dir:
            text_path = os.path.join(volume_dir, endpoint + '.edited.txt')
            if os.path.isfile(text_path):
                size = os.path.getsize(text_path)
                mb = round(size / 1048576.0, 2)
                mtime = datetime.fromtimestamp(os.path.getmtime(text_path)).strftime('%Y-%m-%d')
                text_info = u'{0} MB ({1})'.format(mb, mtime)
            else:
                text_info = '缺'
        else:
            text_info = '卷目录未找到'
        detail_info = '有' if os.path.isfile(outline_path(vol_cfg['id'], batch_item['range'])) else '缺'
        brief(u'| {0} | {1} | {2} |'.format(endpoint, text_info, detail_info))
    brief('')

    if not batch:
        brief('未指定批次，仅输出进度总览。')
        brief('')
        brief('-Batch 使用与本卷 batches 完全一致的范围，例如 -Batch 091-120。')
        brief_text = os.linesep.join(lines)
        if brief_out:
            brief_out_path = repo_path(brief_out)
            os.makedirs(os.path.dirname(brief_out_path), exist_ok=True)
            with io.open(brief_out_path, 'w', encoding='utf-8', newline='') as fh:
                fh.write(brief_text)
            print_console(u'简报已写入：' + get_relative(brief_out_path))
        else:
            print_console(brief_text)
        sys.exit(0)

    batch_def = next((b for b in vol_cfg['batches'] if b['range'] == batch), None)
    if not batch_def:
        raise SystemExit('Unknown batch range: {0}. Known ranges: {1}'.format(
            batch, ','.join(b['range'] for b in vol_cfg['batches'])))
    batch_index = next(i for i, b in enumerate(vol_cfg['batches']) if b['range'] == batch)
    prev_batch = vol_cfg['batches'][batch_index - 1] if batch_index > 0 else None
    next_batch = vol_cfg['batches'][batch_index + 1] if batch_index < len(vol_cfg['batches']) - 1 else None

    brief(u'## 2. 批次定位：{0}-sec{1}（本批 {2} 节）'.format(vol_cfg['id'], batch, batch_def['count']))
    brief('')
    text_path = None
    if volume_dir:
        text_path = os.path.join(volume_dir, u'{0}-sec{1}.edited.txt'.format(vol_cfg['id'], batch))
        if os.path.isfile(text_path):
            size = os.path.getsize(text_path)
            mb = round(size / 1048576.0, 2)
            mtime = datetime.fromtimestamp(os.path.getmtime(text_path)).strftime('%Y-%m-%d %H:%M')
            brief(u'- 正文文件：{0}（{1} MB，最后修改 {2}）'.format(get_relative(text_path), mb, mtime))
        else:
            brief('- 正文文件：尚未生成')
            text_path = None
    else:
        brief(u'- 卷目录未找到：{0}'.format(vol_cfg['directoryPattern']))
    detail_outline = outline_path(vol_cfg['id'], batch)
    if os.path.isfile(detail_outline):
        brief(u'- 细纲：outlines/detail/{0}-sec{1}.md'.format(vol_cfg['id'], batch))
    else:
        brief('- 细纲：缺')
        detail_outline = None
    if prev_batch:
        brief(u'- 上一批：{0}-sec{1}（开工须读其尾节状态）'.format(vol_cfg['id'], prev_batch['range']))
    if next_batch:
        brief(u'- 下一批：{0}-sec{1}（边界不得跨批）'.format(vol_cfg['id'], next_batch['range']))
    brief('')

    if detail_outline:
        brief('## 3. 逐节标题与源文位置（细纲简表）')
        brief('')
        brief('| 节 | 标题 | 源文行 |')
        brief('| --- | --- | --- |')
        with io.open(detail_outline, 'r', encoding='utf-8-sig', newline='') as fh:
            content = fh.read()
        heading_matches = re.findall(r'(?m)^#{2,3}\s+第\s*(\d+)\s*节[：:]\s*(.+?)\s*$', content)
        source_matches = re.findall(r'source_line=(\d+)(?:[-—–]\s*(\d+))?', content)
        source_index = 0
        for match in heading_matches:
            section_no = int(match[0])
            title = match[1].strip()
            if source_index < len(source_matches):
                start, end = source_matches[source_index]
                source_line = u'{0}—{1}'.format(start, end) if end else start
                source_index += 1
            else:
                source_line = '细纲未注'
            brief(u'| {0} | {1} | {2} |'.format(section_no, title, source_line))
        brief('')

    brief('## 4. 台账命中（与批次号直接相关的记录）')
    brief('')
    range_search = re.sub(r'-', r'\\s*[-—–]\\s*', batch)
    for name in REGISTER_NAMES:
        file_path = repo_path(u'notes\\{0}-{1}.md'.format(vol_cfg['id'], name))
        if not os.path.isfile(file_path):
            continue
        with io.open(file_path, 'r', encoding='utf-8-sig', newline='') as fh:
            all_lines = fh.read().splitlines()
        mtime = datetime.fromtimestamp(os.path.getmtime(file_path)).strftime('%m-%d')
        brief(u'- {0}（{1} 行，改于 {2}）：'.format(get_relative(file_path), len(all_lines), mtime))
        status_line = next((ln for ln in all_lines if re.match(r'^\s*>\s*台账状态行', ln)), None)
        if status_line:
            status_text = re.sub(r'^\s*>\s*台账状态行[:：]\s*', '', status_line).strip()
            brief(u'  - 状态行：' + status_text)
        matched_lines = [ln for ln in all_lines if re.search(range_search, ln)]
        exact_matched = [ln for ln in matched_lines if re.search(re.escape(batch), ln)]
        show_lines = exact_matched if exact_matched else matched_lines
        if show_lines:
            shown = 0
            for line_match in show_lines:
                if shown >= 6:
                    break
                trimmed = line_match.strip()
                if not trimmed:
                    continue
                brief('  - ' + summarize_hit(trimmed))
                shown += 1
            if len(show_lines) > 6:
                brief(u'  - …（另 {0} 行命中）'.format(len(show_lines) - 6))
        else:
            brief('  （无直接命中；涉及人物/资源续态仍须读该文件相关章节）')
    brief(u'- 说明：命中行以「ID [类型] 范围：裁决/项目摘要（状态）」收窄展示；须读全文时按 ID 在对应台账中检索。')
    brief('')

    brief('## 5. 工作区与 Git')
    try:
        status = git_status_short(repo_root)
        if status:
            brief('- 未提交改动（编辑前先看 git diff，禁止覆盖用户改动）：')
            for status_line in status[:10]:
                brief('  - ' + status_line)
        else:
            brief('- 工作区干净')
        recent = git_log_oneline(repo_root, 6)
        if recent:
            brief('- 最近提交：')
            for commit_line in recent:
                brief('  - ' + commit_line)
    except Exception:
        pass
    brief('')

    brief('## 6. 原文底稿')
    source_file = repo_path('蛊真人.txt')
    if os.path.isfile(source_file):
        brief('- 完整源文：蛊真人.txt（UTF-8；对照细纲"源文位置"行号区间；编辑时必须读对应区间）')
    else:
        brief('- 完整源文：仓库根目录未找到 蛊真人.txt')
    working_file = repo_path(u'working\\{0}-sec{1}.utf8.txt'.format(vol_cfg['id'], batch))
    if os.path.isfile(working_file):
        size = os.path.getsize(working_file)
        brief(u'- 本地底稿：{0}（{1} KB，UTF-8 编码）'.format(get_relative(working_file), round(size / 1024.0)))

    if write_state:
        state_file = repo_path(u'working\\batch-state-{0}-{1}.md'.format(vol_cfg['id'], batch))
        if not os.path.isfile(state_file):
            os.makedirs(os.path.dirname(state_file), exist_ok=True)
            with io.open(state_file, 'w', encoding='utf-8', newline='') as fh:
                fh.write(STATE_TEMPLATE.format(vol_cfg['id'], batch))
            brief(u'- 批内状态卡（模板已生成）：working/batch-state-{0}-{1}.md'.format(vol_cfg['id'], batch))
        else:
            brief(u'- 批内状态卡（已存在）：working/batch-state-{0}-{1}.md'.format(vol_cfg['id'], batch))
    brief('')

    brief('## 8. 使用提示')
    brief('- 简报只做导航与命中提示：台账无命中的记录、上批尾节状态、source 行区间仍须读取对应文件。')
    brief('- 编辑前先 git diff（或 git diff HEAD^），检查用户批注，禁止覆盖用户改动。')
    brief('- 批内流程：开状态卡 → 对原文与台账逐节 edit → 收尾更新台账（视为建议，由总编会话落账）→ 运行 AGENTS.md 验证命令。')

    brief_text = os.linesep.join(lines)
    if brief_out:
        brief_out_path = repo_path(brief_out)
        os.makedirs(os.path.dirname(brief_out_path), exist_ok=True)
        with io.open(brief_out_path, 'w', encoding='utf-8', newline='') as fh:
            fh.write(brief_text)
        print_console(u'简报已写入：' + get_relative(brief_out_path))
    else:
        print_console(brief_text)


if __name__ == '__main__':
    main()
