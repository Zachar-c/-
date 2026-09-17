#!/usr/bin/env python3
"""Regenerate world-model/docs/原著要素映射表.md from world-model/data/.

映射表要覆盖全部 8 类实体（realm/path/gu/economy/faction/region/event/loot），
再加 balance 与 manifest，每条都标注 CAN-/ADP-/GAME- 编号，或显式写
「原著未明确，属合理扩展」。手写 900 余行必然会漂移，所以由数据生成。

    python world-model/tools/build_mapping_table.py
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

WM_ROOT = Path(__file__).resolve().parents[1]
if str(WM_ROOT) not in sys.path:
    sys.path.insert(0, str(WM_ROOT))

from engine.model import WorldModel  # noqa: E402

OUT = WM_ROOT / "docs" / "原著要素映射表.md"
HEADER = "| 实体类型 | 实体 id | 名称 | 映射到的原著设定/出处 | 改写或合并说明 | 来源类别 | 备注 |"
SEP = "| --- | --- | --- | --- | --- | --- | --- |"

CLASS_ZH = {"canon": "原著事实", "adaptation": "兼容性游戏化", "original_game_content": "原创内容"}


def cell(text) -> str:
    value = str(text if text is not None else "").replace("|", "／").replace("\n", " ").strip()
    return value if value else "—"


def refs(entity: dict) -> str:
    ids = entity.get("source_ids") or []
    if ids:
        return "<br>".join(f"`{i}`" for i in ids[:4]) + ("…" if len(ids) > 4 else "")
    return "原著未明确，属合理扩展"


def row(entity_type: str, eid: str, name: str, mapped: str, rewrite: str, class_zh: str,
        note: str) -> str:
    return f"| {entity_type} | `{cell(eid)}` | {cell(name)} | {cell(mapped)} | {cell(rewrite)} | {class_zh} | {cell(note)} |"


def main() -> int:
    wm = WorldModel()
    lines: list[str] = []
    lines.append("# 原著要素映射表")
    lines.append("")
    lines.append("> 本表把 `world-model/data/` 的每一个实体映射回《蛊真人》原著设定，")
    lines.append("> 并公开它与原著之间的距离。**扩展项不会被伪装成原著设定**：")
    lines.append("> `source_class` 为 `original_game_content` 或 `adaptation` 的行，其 `source_ids`")
    lines.append("> 指向 `docs/lore/game-rule-register.md` 的 GAME- 条目或 `adaptation-register.md` 的 ADP- 条目。")
    lines.append("")
    lines.append("## 来源类别口径")
    lines.append("")
    lines.append("| `source_class` | 中文 | 含义 |")
    lines.append("| --- | --- | --- |")
    lines.append("| `canon` | 原著事实 | 可在原文定位的直接陈述；`source_ids` 指向 `docs/lore/canon-index.md` 的 CAN- 条目 |")
    lines.append("| `adaptation` | 兼容性游戏化 | 有原著依据但经过简化/数值化；指向 ADP- 条目 |")
    lines.append("| `original_game_content` | 原创内容 | 游戏原创机制与内容；指向 GAME- 条目，或显式写「原著未明确，属合理扩展」 |")
    lines.append("")
    lines.append("## 覆盖统计")
    lines.append("")
    lines.append("| 实体类型 | 条数 | 原著事实 | 兼容性游戏化 | 原创内容 | 无 CAN/ADP/GAME 编号（合理扩展） |")
    lines.append("| --- | --- | --- | --- | --- | --- |")

    sections: list[tuple[str, str, list[str]]] = []

    def build(entity_type: str, title: str, rows_fn, entities=None) -> None:
        entities = wm.all(entity_type) if entities is None else entities
        counts = {"canon": 0, "adaptation": 0, "original_game_content": 0}
        unnumbered = 0
        rows = []
        for e in entities:
            counts[e["source_class"]] = counts.get(e["source_class"], 0) + 1
            if not e.get("source_ids"):
                unnumbered += 1
            rows.append(rows_fn(e))
        sections.append((title, entity_type, rows))
        stats.append((entity_type, len(entities), counts["canon"], counts["adaptation"],
                      counts["original_game_content"], unnumbered))

    stats: list[tuple] = []

    def realm_row(e):
        tier = e["essence_tier_zh"] or ""
        mapped = {
            "realm": "蛊师一至九转、每转四小境界、真元品阶",
        }["realm"]
        detail = f"{e['name_zh']}；真元品阶 {tier or '（原著未明确）'}"
        if e["rank"] >= 6:
            detail += "；蛊仙层次"
        note = e["canon_review_status"]
        if e["essence_tier"] is None:
            note += "；品阶留空"
        return row("realm", e["id"], e["name_zh"], refs(e) + "<br>" + mapped, detail, CLASS_ZH[e["source_class"]], note)

    def path_row(e):
        return row("path", e["id"], e["name_zh"], refs(e) + "<br>" + "原著道途/流派（血、气、力、魂、炼…）",
                   e["summary_zh"], CLASS_ZH[e["source_class"]],
                   f"冲突流派={e['conflict_paths'] or '无'}；起始蛊 {len(e['starter_gu_ids'])} 只；池 {e['pool_size']} 只")

    def gu_row(e):
        origin = {"novel": "原文语料命名的蛊虫", "school_derived": "由流派×角色×转数机械派生"}.get(
            e["prototype_source"], "手写策展蛊虫")
        effect_note = {"explicit": "独立效果", "combat_effects": "组合效果",
                       "role_default": "仅角色兜底（非独立效果）"}[e["effect_source"]]
        return row("gu", e["id"], e["name_zh"], refs(e) + "<br>" + origin,
                   f"{e['rank']} 转 {e['school']}／{e['role']}；效果 {effect_note}",
                   CLASS_ZH[e["source_class"]],
                   f"{e['canon_review_status']}；{e['adaptation_note']}")

    def faction_row(e):
        agents = "，".join(e["agents"]) or "无"
        return row("faction", e["id"], e["name_zh"],
                   refs(e) + "<br>" + "南疆山寨/商队/体制外散修/魔道的利害结构" if e["entity_kind"] == "faction" else "恶名与信誉的社会压力",
                   e["summary_zh"], CLASS_ZH[e["source_class"]],
                   f"成员={agents}；关系档 {len(e['relation_levels'])} 级")

    def region_row(e):
        if e["entity_kind"] == "macro_region":
            detail = f"5 层路线图，单局 {e['map_structure']['node_budget_per_run']} 节点；三转方可远游"
            extra = f"敌人名册 {len(e['enemy_roster'])} 条；节点模板 {len(e['node_templates'])} 条；NPC {len(e['npc_roster'])} 条"
        elif e["entity_kind"] == "layer":
            detail = (f"{e['rows_min']}–{e['rows_max']} 行 × {e['row_nodes_min']}–{e['row_nodes_max']} 节点；"
                      f"分类权重 {e['category_weights']}")
            extra = f"Boss 池 {e['boss_pool']}；敌人转数 {e['enemy_rank_min']}–{e['enemy_rank_max']}"
        else:
            detail = "升仙终局窗口（碎窍纳气、三气平衡）"
            extra = f"选项 {e['choices']}；跳过={e['on_skip']}"
        return row("region", e["id"], e["name_zh"],
                   refs(e) + "<br>" + "南疆地理与山寨聚居；层名取自原文地名线索", detail, CLASS_ZH[e["source_class"]], extra)

    def event_row(e):
        return row("event", e["id"], e["name_zh"], refs(e) + "<br>" + f"原著高频场景母题：{e['kind']}",
                   f"{e['summary_zh']}（收益：{e['gain_text_zh']}）", CLASS_ZH[e["source_class"]],
                   f"气血 -{e['health_cost']}｜元石 +{e['stone_gain']}｜延迟魂 -{e['delayed_cost']['soul']}"
                   + (f"｜诅咒 {e['curse_id']}" if e["curse_id"] else ""))

    def loot_material_row(e):
        use = (e.get("use") or {}).get("text", "")
        return row("loot", e["id"], e["name_zh"],
                   refs(e) + "<br>" + (e.get("use") or {}).get("text", "") and "原著材料形态参照"
                   if e["source_class"] == "canon" else "游戏扩展材料",
                   f"价值 {e['value']}／参考价 {e['reference_value']}／流动性 {e['public_liquidity']}；{use}",
                   CLASS_ZH[e["source_class"]],
                   f"{'核心蛊材' if e['is_core_material'] else '派生蛊材'}；{e['origin_status']}")

    def economy_row(e):
        return row("economy", e["id"], e["name_zh"], refs(e) + "<br>" + "元石本位经济；修行/战斗/炼蛊/交易都耗元石",
                   f"{len(e['resources'])} 种资源、{len(e['shop_offers'])} 条报价、"
                   f"{len(e['black_market_exchange'])} 条黑市汇率、{len(e['layer_budget'])} 层预算",
                   CLASS_ZH[e["source_class"]], e["adaptation_note"])

    def balance_row(e):
        return row("balance", e["id"], e["name_zh"], refs(e) + "<br>" + "把原著约束落成可调参数（非原著数值）",
                   f"参数分组：{'、'.join(k for k in e if isinstance(e[k], dict) and k not in ('source_ids',))}",
                   CLASS_ZH[e["source_class"]], e["adaptation_note"])

    def manifest_row(e):
        return row("manifest", e["id"], e["name_zh"], refs(e) + "<br>" + "构建产物，无原著对应",
                   f"{e['file_count']} 个数据文件、{e['total_bytes']} 字节、零第三方依赖",
                   CLASS_ZH[e["source_class"]], e["adaptation_note"])

    build("realm", "1. `realm` 境界（36 条）", realm_row)
    build("path", "2. `path` 道途 / 流派（20 条）", path_row)
    build("gu", "3. `gu` 蛊虫（802 条）", gu_row)
    build("economy", "4. `economy` 资源与经济（1 条，含 8 种资源 / 37 条报价）", economy_row)
    build("faction", "5. `faction` 势力与关系（6 条）", faction_row)
    build("region", "6. `region` 地域与关卡（7 条）", region_row)
    build("event", "7. `event` 事件卡（12 条）", event_row)
    build("loot", "8. `loot` 遗物 / 战利品（每行一种蛊材，共 80 行）", loot_material_row,
          entities=wm.loot["materials"])
    build("balance", "9. `balance` 集中参数表（1 条）", balance_row)
    build("manifest", "10. `manifest` 数据清单（1 条）", manifest_row)

    for entity_type, total, canon, adapt, original, unnumbered in stats:
        lines.append(f"| `{entity_type}` | {total} | {canon} | {adapt} | {original} | {unnumbered} |")
    total_rows = sum(s[1] for s in stats)
    lines.append(f"| **合计** | **{total_rows}** | "
                 f"**{sum(s[2] for s in stats)}** | **{sum(s[3] for s in stats)}** | "
                 f"**{sum(s[4] for s in stats)}** | **{sum(s[5] for s in stats)}** |")
    lines.append("")
    lines.append("### `loot` 的遗物与战利品档位")
    lines.append("")
    lines.append(HEADER)
    lines.append(SEP)
    loot = wm.loot
    for relic in loot["relics"]:
        lines.append(row("loot", relic["id"], relic["id"], "原著未明确，属合理扩展",
                         f"遗物钩子：{relic['hooks']}", CLASS_ZH[relic["source_class"]],
                         f"grade={relic['grade']}；rarity={relic['rarity']}"))
    for tier in ("common", "elite", "boss"):
        spec = loot["tiers"][tier]
        lines.append(row("loot", f"tier:{tier}", f"{tier} 掉落档",
                         "敌人档位分层为游戏规则",
                         f"蛊材 {spec.get('material_count')} 份；出蛊 {spec.get('gu_chance_pct')}%；"
                         f"稀有度权重 {loot['rarity_weights'][tier]}",
                         CLASS_ZH[loot["source_class"]], "掉落按档位分层；保底计数按档位独立"))
    lines.append(row("loot", "pity", "达标保底", "原著未明确，属合理扩展",
                     f"阈值 {loot['pity']['threshold']}；清除稀有度 {loot['pity']['clearing_rarities']}",
                     CLASS_ZH[loot["source_class"]], "只补池内已定义存在的目标带段，不凭空生成"))
    lines.append("")

    for title, entity_type, rows in sections:
        lines.append(f"## {title}")
        lines.append("")
        lines.append(HEADER)
        lines.append(SEP)
        lines.extend(rows)
        lines.append("")

    lines.append("## 未做映射的原著设定（明确不做）")
    lines.append("")
    lines.append("| 原著设定 | 为什么不在本模型内 |")
    lines.append("| --- | --- |")
    lines.append("| 蛊仙阶段机制（仙窍、仙元石、道痕堆叠、灾劫、福地经营） | 首发只做凡人一至五转；`CAN-IMMORTAL-BOUNDARY-001` 明确不把这些做成凡人跑局的常规模块。"
                 "`economy.json` 只把 `immortal_stone` 登记为 `in_launch_scope=false` 的资源占位 |")
    lines.append("| 荒兽 / 上古荒兽 / 太古荒兽 | 「荒兽已可媲美蛊仙战力」（`CAN-BEAST-TIER-003`），不得作为凡人跑局的常规敌人 |")
    lines.append("| 具体家族人物、历史事件与既有结局 | `ADP-FACTION-001` 的不可越界项：不冒用原著家族的具体人物、历史或既有结局 |")
    lines.append("| 蛊屋（真阳楼 / 近水楼台） | 属蛊仙阶段构筑（`02-蛊屋-原始数据.md`），首发不做 |")
    lines.append("| 十绝体 | `CAN-APTITUDE-002`：甲等之上有十种十绝体，元海圆满但伴随空窍崩毁与早夭风险；"
                 "不作为普通满资质奖励或无代价开局选项 |")
    lines.append("| 升仙后的仙界内容 | `ADP-ASCENSION-001`：升仙只作为终局考验，不做成可继续游玩的正式首发内容 |")
    lines.append("")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {OUT}（{total_rows} 行映射 + 遗物/档位补充）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
