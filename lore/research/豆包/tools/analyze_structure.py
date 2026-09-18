# -*- coding: utf-8 -*-
"""
蛊真人原文结构分析工具
功能：
1. 提取所有节的标题、起止行号、字数
2. 搜索人祖传出现位置
3. 生成卷一结构地图
4. 统计重复段落
"""

import re
import os
from pathlib import Path

# 配置
TEXT_PATH = r"C:\Users\Zachary\OneDrive\Workspace\01_Work_Jiawei\05-缺陷报告\测试报告相关代码\gu-zu\豆包\蛊真人-clean.txt"
OUTPUT_DIR = r"C:\Users\Zachary\OneDrive\Workspace\01_Work_Jiawei\05-缺陷报告\测试报告相关代码\gu-zu\豆包\tools"

def read_all_lines():
    """读取全文，返回行列表"""
    with open(TEXT_PATH, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    return lines

def extract_sections(lines):
    """提取所有节的信息"""
    sections = []
    section_pattern = re.compile(r'^第[一二三四五六七八九十百千]+节[：:].+')
    
    current_section = None
    for i, line in enumerate(lines, 1):
        line_stripped = line.strip()
        if section_pattern.match(line_stripped):
            if current_section:
                current_section['end_line'] = i - 1
                current_section['line_count'] = current_section['end_line'] - current_section['start_line'] + 1
                sections.append(current_section)
            current_section = {
                'title': line_stripped,
                'start_line': i,
                'end_line': None,
                'line_count': None
            }
    
    # 最后一节
    if current_section:
        current_section['end_line'] = len(lines)
        current_section['line_count'] = current_section['end_line'] - current_section['start_line'] + 1
        sections.append(current_section)
    
    return sections

def find_renzhuan(lines):
    """查找人祖传相关内容的位置"""
    renzhuan_lines = []
    keywords = ['人祖传', '人祖', '希望蛊', '力量蛊', '智慧蛊', '规矩蛊', '寿蛊', '勇气蛊', '信念蛊']
    
    for i, line in enumerate(lines, 1):
        for kw in keywords:
            if kw in line:
                renzhuan_lines.append((i, line.strip()[:80]))
                break
    
    return renzhuan_lines

def find_volume_markers(lines):
    """查找卷标记"""
    volumes = []
    volume_pattern = re.compile(r'^第[一二三四五六七八九十百千]+卷[：:].+')
    
    for i, line in enumerate(lines, 1):
        line_stripped = line.strip()
        if volume_pattern.match(line_stripped):
            volumes.append({
                'title': line_stripped,
                'line': i
            })
    
    return volumes

def generate_structure_report(sections, volumes, renzhuan_lines, total_lines):
    """生成结构报告"""
    report = []
    report.append("# 蛊真人 · 原文结构分析报告")
    report.append("")
    report.append(f"- 总行数：{total_lines}")
    report.append(f"- 总节数：{len(sections)}")
    report.append(f"- 卷标记数：{len(volumes)}")
    report.append("")
    
    # 卷信息
    report.append("## 卷信息")
    for v in volumes:
        report.append(f"- 第{v['line']}行：{v['title']}")
    report.append("")
    
    # 节列表
    report.append("## 节列表（前50节）")
    report.append("")
    report.append("| 序号 | 行号范围 | 行数 | 标题 |")
    report.append("|------|----------|------|------|")
    
    for i, sec in enumerate(sections[:50], 1):
        report.append(f"| {i} | {sec['start_line']}–{sec['end_line']} | {sec['line_count']} | {sec['title']} |")
    
    if len(sections) > 50:
        report.append("")
        report.append(f"*（共 {len(sections)} 节，此处仅显示前50节）*")
    
    report.append("")
    
    # 人祖传位置
    report.append("## 人祖传相关内容（前30处）")
    report.append("")
    for line_num, content in renzhuan_lines[:30]:
        report.append(f"- 第{line_num}行：{content}")
    
    if len(renzhuan_lines) > 30:
        report.append("")
        report.append(f"*（共 {len(renzhuan_lines)} 处，此处仅显示前30处）*")
    
    return "\n".join(report)

def generate_volume1_map(sections):
    """生成卷一（青茅）的详细结构地图"""
    # 卷一：从第一节到青茅山结束（大概到第30节左右？需要确认）
    # 先输出前40节的详细信息
    
    report = []
    report.append("# 卷一 · 青茅 结构地图")
    report.append("")
    report.append("> 按剧情节点分组，便于精编分章")
    report.append("")
    
    # 剧情节点分组（根据节标题初步判断）
    groups = [
        {
            "name": "重生归来",
            "sections": [0, 1],  # 第1-2节
            "desc": "围杀自爆→重生→祭祀"
        },
        {
            "name": "开窍大典",
            "sections": [2, 3, 4, 5],  # 第3-6节
            "desc": "赴典→测资质→希望蛊寓言→三方争抢"
        },
        {
            "name": "过继风波",
            "sections": [6, 7, 8],  # 第7-9节
            "desc": "学堂→兄弟对峙→过继被拒→沈翠密谋"
        },
        {
            "name": "酒虫遗藏",
            "sections": [9, 10, 11, 12, 13, 14, 15],  # 第10-16节
            "desc": "夜探竹林→发现遗藏→酒虫→炼化"
        },
        {
            "name": "学堂考核",
            "sections": [16, 17, 18, 19, 20],  # 第17-21节
            "desc": "炼化酒虫→考核第一→月刃→养蛊"
        },
        {
            "name": "资源积累",
            "sections": [21, 22, 23, 24, 25, 26, 27, 28],  # 第22-29节
            "desc": "近战蛊→春光→勒索→无本生意→不择手段"
        },
    ]
    
    for group in groups:
        report.append(f"## {group['name']}")
        report.append(f"> {group['desc']}")
        report.append("")
        report.append("| 节 | 行号范围 | 行数 | 标题 |")
        report.append("|----|----------|------|------|")
        
        for idx in group['sections']:
            if idx < len(sections):
                sec = sections[idx]
                report.append(f"| {idx+1} | {sec['start_line']}–{sec['end_line']} | {sec['line_count']} | {sec['title']} |")
        
        # 计算总字数
        total_lines = sum(sections[idx]['line_count'] for idx in group['sections'] if idx < len(sections))
        report.append("")
        report.append(f"**本组总行数：{total_lines}**")
        report.append("")
    
    # 第30节以后的节列表（待分组）
    report.append("## 待分组（第30节起）")
    report.append("")
    report.append("| 节 | 行号范围 | 行数 | 标题 |")
    report.append("|----|----------|------|------|")
    
    for i, sec in enumerate(sections[29:50], 30):
        report.append(f"| {i} | {sec['start_line']}–{sec['end_line']} | {sec['line_count']} | {sec['title']} |")
    
    return "\n".join(report)

def main():
    print("正在读取原文...")
    lines = read_all_lines()
    total_lines = len(lines)
    print(f"总行数：{total_lines}")
    
    print("正在提取节信息...")
    sections = extract_sections(lines)
    print(f"总节数：{len(sections)}")
    
    print("正在查找卷标记...")
    volumes = find_volume_markers(lines)
    print(f"卷标记数：{len(volumes)}")
    
    print("正在查找人祖传内容...")
    renzhuan_lines = find_renzhuan(lines)
    print(f"人祖传相关行数：{len(renzhuan_lines)}")
    
    # 生成报告
    print("正在生成结构报告...")
    report = generate_structure_report(sections, volumes, renzhuan_lines, total_lines)
    report_path = os.path.join(OUTPUT_DIR, "结构分析报告.md")
    with open(report_path, 'w', encoding='utf-8') as f:
        f.write(report)
    print(f"结构报告已保存：{report_path}")
    
    # 生成卷一地图
    print("正在生成卷一结构地图...")
    volume1_map = generate_volume1_map(sections)
    map_path = os.path.join(OUTPUT_DIR, "卷一结构地图.md")
    with open(map_path, 'w', encoding='utf-8') as f:
        f.write(volume1_map)
    print(f"卷一结构地图已保存：{map_path}")
    
    print("\n完成！")

if __name__ == "__main__":
    main()
