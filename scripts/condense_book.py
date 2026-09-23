# -*- coding: utf-8 -*-
"""《蛊真人》全书 LLM 浓缩助手（过场优先·保护核心）。

定位：以蛊真人-clean.txt 为底本，把全书按“节”切分，分批交给 LLM 做段落级
浓缩——只压缩过场/冗余叙述/过程注水；保留所有对话、世界观设定、高潮名场面、
《人祖传》、人物弧光与伏笔，不改故事线，不新增句子。每批产出：
  - 压缩正文（接续写入输出文件，保留节标题原样）
  - 红绿对照批注 md（本批删/改写/保留/保护抽查说明）
  - 字数前后统计（追加进汇总）

用法：
  py -3 scripts/condense_book.py -StartSec 0 -EndSec 207 -BatchSub 0
       -Source 蛊真人-clean.txt -Out working/condense
  -StartSec/-EndSec 处理节区间（含首尾，0-based 节序）。
  -BatchSub 本批内的子批次号，用于分小批续跑；-DryRun 列出将生成的任务无需执行。

批次划分（-SubSize 控制，默认 3 节/子批，便于控制单次 token 与上下文连续）：
  每子批 = 连续 SubSize 节的一段完整文本，交给 LLM：
    输入为该段原文（含节标题）。
    输出约束：只交回“压缩后的该段正文”；节标题逐字保留；对话逐字保留；
    不得改写人物姓名/蛊名/地名/设定词；不得调整事件先后与结局；不得新增解释。
  保护抽查：LLM 输出的每节，须在批注中列出该节“保留的核心片段”以便人工复核。

输出文件：
  <Out>/压缩正文-前缀.txt        压缩后的接续文本
  <Out>/批注-<节>-<节>.md        本子批红绿对照与保护抽查
  <Out>/字数汇总.md               累加统计
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gu_tools import PsArgs, repo_abs, read_utf8, write_utf8_no_bom

RE_SECTION_HEAD = re.compile(r'^\s*第\s*[一二三四五六七八九十百千0-9]+\s*节\s*[:：]?\s*\S')


def find_sections(lines):
    starts = [i for i, l in enumerate(lines) if RE_SECTION_HEAD.match(l)]
    bounds = []
    for k, s in enumerate(starts):
        e = starts[k + 1] if k + 1 < len(starts) else len(lines)
        bounds.append((s, e))
    return bounds


def split_subsections(text):
    """把一段文本按节标题切成 [(header, body_chars)]，返回可逐节拆子批的锚点。"""
    lines = text.split(u'\n')
    starts = [i for i, l in enumerate(lines) if RE_SECTION_HEAD.match(l)]
    return starts


def build_prompt(in_text, meta):
    """生成 LLM 浓缩提示词。in_text 为当前子批原文（含节标题）。"""
    return (u'你是《蛊真人》出版级精编助手。对下面的原文做严格的“过场浓缩”，不改故事线。\n\n'
            u'### 必须保留（不得删减、不得改写原意）\n'
            u'1. 所有含引号的对话；人物原话一字不改。\n'
            u'2. 世界观设定（蛊、尊者、仙尊、传承、福地、洞天、境界、流派、宿命、天意等）；'
            u'首次出场的关键设定。\n'
            u'3. 高潮名场面、关键战斗过程与转折、人物弧光关键片段、伏笔与名场面原句。\n'
            u'4. 《人祖传》相关全部内容。\n'
            u'5. 每节标题逐字保留。\n\n'
            u'### 只可压缩（过场/水分）\n'
            u'- 赶路、等待、起床等纯过渡段落；\n'
            u'- 机械围观反应、重复围观、重复宣判；\n'
            u'- 同一结论的反复论证、过程性注水、冗余延伸议论；\n'
            u'- 非关键氛围景物描写；配角群像反应（最多保留 1-2 处典型）。\n\n'
            u'### 输出规则\n'
            u'只输出“压缩后的该段正文”，不输出任何解释、批注或说明。每一节标题保持原样。'
            u'压缩后若该节所剩不足，也要保留至少首个含设定/高潮/关键对白的句子。\n\n'
            u'### 原文\n' + in_text)


def count_visible(text):
    return sum(len(l) for l in text.split(u'\n') if l.strip())


def main():
    ps = PsArgs(specs=[
        ('StartSec', 'int'), ('EndSec', 'int'), ('BatchSub', 'int'),
        ('Source', 'string'), ('Out', 'string'), ('SubSize', 'int'), ('DryRun', 'bool')])
    source = ps.get('Source') or u'蛊真人-clean.txt'
    outdir = ps.get('Out') or repo_abs(u'working/condense')
    s0 = ps.get('StartSec', 0)
    e1 = ps.get('EndSec', 0)
    sub_idx = ps.get('BatchSub', 0)
    sub_size = ps.get('SubSize', 3)
    dry = ps.get('DryRun', False)

    lines = read_utf8(repo_abs(source)).split(u'\n')
    bounds = find_sections(lines)
    n = len(bounds)
    if e1 >= n:
        e1 = n - 1

    # --- 构造每批的任务说明（不执行 LLM，仅输出给会话/子代理去调用） ---
    # 本脚本自身不调用外置 LLM；它产出“任务卡”供本会话的子代理逐批执行，
    # 并把子代理回写的压缩文本粘回输出文件。
    tasks = []
    for sec_no in range(s0, e1 + 1):
        s, e = bounds[sec_no]
        chunk = u'\n'.join(lines[s:e])
        tasks.append({'sec': sec_no, 'chars_in': count_visible(chunk), 'text': chunk})

    # 汇总本批各子批
    sub_batches = []
    for k in range(0, len(tasks), sub_size):
        batch = tasks[k:k + sub_size]
        total = sum(t['chars_in'] for t in batch)
        sub_batches.append({'idx': len(sub_batches), 'secs': [t['sec'] for t in batch],
                            'chars_in': total})
    strides = ', '.join(u'子批{0}(节{1[0]}-{1[-1]} {1[chars_in]}字)'.format(
        b['idx'], b) for b in sub_batches)
    print(u'范围：节 {0}-{1}  子批 {2} 个'.format(s0, e1, len(sub_batches)))
    print(u'子批：{0}'.format(strides))
    print(u'总字数：{0}'.format(sum(t['chars_in'] for t in tasks)))

    sub_dir = os.path.join(outdir, u'sec{0:03d}-{1:03d}'.format(s0, e1))
    if not dry:
        os.makedirs(os.path.join(sub_dir, u'batches'), exist_ok=True)

    # 任务卡目录（供会话/子代理构建 LLM 调用并按卡回写）
    manifest = []
    for b in sub_batches:
        in_text = u'\n\n'.join(t['text'] for t in tasks[min(b['secs']):max(b['secs']) + 1])
        prompt = build_prompt(in_text, b)
        card = {
            'sub': b['idx'],
            'secs': b['secs'],
            'chars_in': b['chars_in'],
            'prompt': prompt,
            'out_file': os.path.join(sub_dir, u'batches', u'sub{0:03d}.txt'.format(b['idx'])),
        }
        manifest.append(card)
        if not dry:
            write_utf8_no_bom(os.path.join(sub_dir, u'batches',
                                           u'sub{0:03d}.brief.md'.format(b['idx'])),
                              u'# 子批 {0} · 节 {1}\n\n{2}'.format(b['idx'], b['secs'], prompt))
    write_utf8_no_bom(os.path.join(sub_dir, u'批次清单.json'),
                      (u'[\n' + u',\n'.join(
                          u'  {0}'.format(_json(c)) for c in manifest) + u'\n]'))
    print(u'任务卡目录：{0}'.format(sub_dir))


def _json(c):
    import json
    return json.dumps(c, ensure_ascii=False)


if __name__ == '__main__':
    main()