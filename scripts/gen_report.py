# -*- coding: utf-8 -*-
"""批次审阅简报生成器：批末为 AI 与用户生成审阅报告，浓缩改动范围、决策、台账、验证与遗留问题。
对齐 gen_report.ps1。用法：
  py -3 scripts/gen_report.py -Volume vol2 -Batch 091-120
  py -3 scripts/gen_report.py -Volume vol2 -Batch 151-180 -OutFile notes/batch-report.md
  py -3 scripts/gen_report.py -Volume vol2 -Batch 091-120 -SkipValidate
注意：-OutFile 缺省时写入 notes\\batch-report.md（每批覆盖）；关键裁决与遗留问题两节必须由编辑会话或总编会话填写。"""
import io
import json
import os
import re
import subprocess
import sys
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gu_tools import PsArgs, REPO_ROOT, git_silent, git_status_short, git_log_oneline

REGISTER_NAMES = [
    'decision-register',
    'combat-ledger',
    'resource-audit',
    'information-ledger',
    'chronology-geography',
    'character-state-ledger',
    'structural-surgery',
]


def main():
    args = PsArgs(specs=[
        ('Volume', 'string'),
        ('Batch', 'string'),
        ('OutFile', 'string'),
        ('SkipValidate', 'bool'),
        ('RepoRoot', 'string'),
    ], defaults={
        'Volume': 'vol2',
        'RepoRoot': REPO_ROOT,
    })
    volume_id = args.get('Volume')
    batch = args.get('Batch')
    out_file = args.get('OutFile')
    skip_validate = args.get('SkipValidate') or False
    repo_root = os.path.abspath(args.get('RepoRoot'))

    def repo_path(relative):
        return os.path.join(repo_root, relative)

    def get_relative(path):
        return path[len(repo_root):].lstrip('\\/')

    config_path = repo_path('config\\editorial-volumes.json')
    if not os.path.isfile(config_path):
        raise SystemExit('Missing editorial volume configuration: {0}'.format(config_path))
    with io.open(config_path, 'r', encoding='utf-8-sig') as fh:
        volume_config = json.load(fh)
    vol_cfg = next((v for v in volume_config['volumes'] if v['id'] == volume_id), None)
    if not vol_cfg:
        raise SystemExit('Unknown volume: {0}. Known ids: {1}'.format(
            volume_id, ','.join(v['id'] for v in volume_config['volumes'])))

    endpoint = u'{0}-sec{1}'.format(vol_cfg['id'], batch)
    if not batch:
        raise SystemExit('必须提供 -Batch，例如 -Batch 091-120。')

    lines = []

    def report(text=''):
        lines.append(text)

    report(u'# 批次审阅简报：{0}'.format(endpoint))
    report('')
    report(u'- 生成时间：' + datetime.now().strftime('%Y-%m-%d %H:%M'))
    try:
        head = git_silent(repo_root, 'log', '-1', '--oneline')
        if head:
            report(u'- Git HEAD：' + head[0])
    except Exception:
        pass
    report('- 审阅方式：本简报 + git diff（第一节列出的改动范围）；简报是导航，不是正文替代。')
    report('')

    # 1. 本批改动范围
    report('## 1. 本批改动范围')
    report('')
    related_commits = git_silent(repo_root, 'log', '--oneline', '-20', '--grep', batch)
    if related_commits:
        report('- 关联提交（git log 命中本批号）：')
        for commit_line in related_commits:
            report('  - ' + commit_line)
        related_hash = related_commits[0].split(' ')[0]
        report('')
        report(u'- 最近一次命中本批的提交（{0}）改动文件：'.format(related_hash))
        name_list = [n for n in git_silent(repo_root, 'show', '--name-only', '--format=', related_hash) if n]
        if name_list:
            for name in name_list:
                report('  - ' + name)
        else:
            report('  （无文件，可能是合并提交）')
        report('')
        report('- 该提交统计（--stat）：')
        stat_lines = [s for s in git_silent(repo_root, 'show', '--stat', '--format=', related_hash) if s]
        for stat_line in stat_lines:
            report('  - ' + stat_line)
    else:
        report('- 未找到命中本批号的提交：本批可能在当前未提交改动中，见下。')
    report('')
    status_short = git_status_short(repo_root)
    batch_pattern = re.escape(batch)
    batch_status = [s for s in status_short if re.search(batch_pattern, s)]
    if batch_status:
        report('- 工作区与本批相关的未提交改动：')
        for status_line in batch_status:
            report('  - ' + status_line)
    else:
        report('- 工作区未见本批号的未提交改动（若未提交且改了文件，请核对文件名是否含本批范围）。')
    report('')
    report('- 手改核对命令：')
    report('```')
    report('  git diff HEAD -- volumes/ notes/ outlines/   # 未提交改动的完整 diff')
    report('  git log --oneline -5                       # 分批提交记录')
    report('```')
    report('')

    # 2. 关键裁决及理由（骨架）
    report('## 2. 关键裁决及理由')
    report('')
    report('> 批末由编辑会话填写；每条注明台账 ID、正文落地节号与理由。脚本只附台账命中。')
    report('')
    range_search = re.sub(r'-', r'\\s*[-—–]\\s*', batch)
    any_hit = False
    for name in REGISTER_NAMES:
        file_path = repo_path(u'notes\\{0}-{1}.md'.format(vol_cfg['id'], name))
        if not os.path.isfile(file_path):
            continue
        with io.open(file_path, 'r', encoding='utf-8-sig', newline='') as fh:
            all_lines = fh.read().splitlines()
        matched_lines = [ln for ln in all_lines if re.search(range_search, ln)]
        if matched_lines:
            any_hit = True
            for line_match in matched_lines:
                trimmed = line_match.strip()
                if trimmed:
                    report(u'- 台账命中（{0}）：{1}'.format(get_relative(file_path), trimmed))
    if not any_hit:
        report('- （台账未命中本批号；如本批有裁决请手工登记到台账并回填此处）')
    report('')

    # 3. 台账落地清单
    report('## 3. 台账落地清单')
    report('')
    report('| 台账 | 本批落账情况 | 顶部状态行 |')
    report('| --- | --- | --- |')
    notes_status = [s for s in status_short if re.search(r'notes/', s)]
    notes_touched = len(notes_status) > 0
    for name in REGISTER_NAMES:
        file_path = repo_path(u'notes\\{0}-{1}.md'.format(vol_cfg['id'], name))
        if not os.path.isfile(file_path):
            report(u'| {0} | 无此文件 | — |'.format(name))
            continue
        with io.open(file_path, 'r', encoding='utf-8-sig', newline='') as fh:
            all_lines = fh.read().splitlines()
        hit_count = sum(1 for ln in all_lines if re.search(range_search, ln))
        touched = [s for s in notes_status if name in s]
        if hit_count > 0:
            status_text = u'已落账（命中 {0} 行）'.format(hit_count)
        elif touched:
            status_text = '文件有未提交改动但未命中本批'
        else:
            status_text = '未落账'
        status_line = next((ln for ln in all_lines if re.match(r'^\s*>\s*台账状态行', ln)), None)
        if status_line:
            status_line_text = re.sub(r'^\s*>\s*台账状态行[:：]\s*', '', status_line).strip()
        else:
            status_line_text = '（缺状态行，见台账维护规范）'
        report(u'| {0} | {1} | {2}'.format(name, status_text, status_line_text))
    report('')
    if notes_touched:
        report('- 说明：notes/ 有未提交改动，请按台账约定（顶部状态行 + 底部追加式维护）核对。')
    else:
        report('- 说明：notes/ 无未提交改动；若本批产生了裁决记录，请更新台账后重跑本脚本。')
    report('')

    # 4. 验证结果
    report('## 4. 验证结果')
    report('')
    validate_path = repo_path('scripts\\validate_editorial_assets.py')
    if not skip_validate and os.path.isfile(validate_path):
        report('- 运行 validate_editorial_assets.py -Phase detail：')
        try:
            proc = subprocess.Popen(
                [sys.executable, validate_path, '-Phase', 'detail', '-Volume', volume_id, '-RepoRoot', repo_root],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            stdout, _ = proc.communicate()
            validate_exit = proc.returncode
            for line_out in stdout.decode('utf-8', errors='replace').splitlines():
                report('  - ' + line_out)
            if validate_exit == 0:
                report('  - 结果：PASS')
            else:
                report(u'  - 结果：FAIL（exit={0}）'.format(validate_exit))
        except Exception as exc:
            report(u'  - 运行失败：{0}'.format(exc))
        report('')
    else:
        report('- 跳过自动验证（-SkipValidate 或脚本缺失），请手动运行：')
        report('```')
        report('  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate_editorial_assets.ps1 -Phase detail')
        report('  git diff --check')
        report('```')
        report('')
    diff_check = git_silent(repo_root, 'diff', '--check')
    if not diff_check:
        report('- git diff --check：无空白错误')
    else:
        report('- git diff --check：发现以下问题：')
        for line_diff in diff_check:
            report('  - ' + line_diff)
    report('')

    # 5. 遗留问题
    report('## 5. 遗留问题 / 待总编裁决项')
    report('')
    report('> 由编辑会话填写：本批未决的 P2/P3、待核算口径、跨批伏笔、待用户裁决项。')
    report('- ')

    report_text = os.linesep.join(lines)
    target = out_file if out_file else 'notes\\batch-report.md'
    out_path = repo_path(target)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with io.open(out_path, 'w', encoding='utf-8', newline='') as fh:
        fh.write(report_text)
    print(u'审阅简报已写入：' + get_relative(out_path))


if __name__ == '__main__':
    main()
