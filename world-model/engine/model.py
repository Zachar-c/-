"""Loads and validates the world model, then exposes read-only accessors.

Anything the runner or rules layer needs comes through this object; no other
module reads world-model/data/*.json directly.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from .errors import DataFormatError, DataMissingError

WM_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = WM_ROOT / "data"
SCHEMA_DIR = WM_ROOT / "schema"

ENTITY_FILES = {
    "realm": "realms.json",
    "path": "paths.json",
    "gu": "gu.json",
    "economy": "economy.json",
    "faction": "factions.json",
    "region": "regions.json",
    "event": "events.json",
    "loot": "loot.json",
    "balance": "balance.json",
    "manifest": "manifest.json",
}


def _read_json(path: Path) -> object:
    if not path.exists():
        raise DataMissingError(f"世界模型数据文件缺失：{path.name}", detail=str(path))
    try:
        with path.open(encoding="utf-8") as fh:
            return json.load(fh)
    except json.JSONDecodeError as exc:
        raise DataFormatError(f"世界模型数据文件不是合法 JSON：{path.name}", detail=str(exc)) from exc


class WorldModel:
    """Validated, read-only view over world-model/data/."""

    def __init__(self, data_dir: Path | None = None, validate: bool = True, schema_path: Path | None = None):
        self.data_dir = Path(data_dir) if data_dir else DATA_DIR
        self.documents: dict[str, dict] = {}
        self._entities: dict[str, dict[str, dict]] = {}
        self.data_digest = ""
        self.schema_checks = 0
        self.overrides: dict[tuple, object] = {}
        self._load(schema_path)
        if validate:
            self._validate(schema_path)

    # -- loading ----------------------------------------------------------
    def _load(self, schema_path: Path | None) -> None:
        digests = []
        for entity_type, filename in ENTITY_FILES.items():
            path = self.data_dir / filename
            doc = _read_json(path)
            if not isinstance(doc, dict):
                raise DataFormatError(f"{filename} 顶层必须是对象（实体文档 envelope）")
            declared = doc.get("entity_type")
            if declared != entity_type:
                raise DataFormatError(
                    f"{filename} 的 entity_type 为 {declared!r}，期望 {entity_type!r}")
            entities = doc.get("entities")
            if not isinstance(entities, list):
                raise DataFormatError(f"{filename} 缺少 entities 数组")
            if doc.get("count") != len(entities):
                raise DataFormatError(
                    f"{filename} 的 count={doc.get('count')} 与 entities 长度 {len(entities)} 不符")
            self.documents[entity_type] = doc
            table: dict[str, dict] = {}
            for ent in entities:
                if not isinstance(ent, dict) or "id" not in ent:
                    raise DataFormatError(f"{filename} 存在缺少 id 的实体")
                if ent["id"] in table:
                    raise DataFormatError(f"{filename} 存在重复实体 id：{ent['id']}")
                table[ent["id"]] = ent
            self._entities[entity_type] = table
            digests.append(f"{filename}:{hashlib.sha256(path.read_bytes()).hexdigest()}")
        self.data_digest = hashlib.sha256("\n".join(sorted(digests)).encode("utf-8")).hexdigest()

    def _validate(self, schema_path: Path | None) -> None:
        import sys
        schema_file = Path(schema_path) if schema_path else (SCHEMA_DIR / "world-model.schema.json")
        if not schema_file.exists():
            # schema file optional at runtime; structural checks above still ran
            return
        sys.path.insert(0, str(WM_ROOT))
        from schema.mini_schema import Validator  # type: ignore

        validator = Validator(_read_json(schema_file))  # type: ignore[arg-type]
        problems: list[str] = []
        for entity_type, doc in self.documents.items():
            errs = validator.validate_document(doc, entity_type)
            self.schema_checks += validator.checks
            problems.extend(f"{ENTITY_FILES[entity_type]} {e}" for e in errs)
        if problems:
            raise DataFormatError(
                f"世界模型未通过 schema 校验（{len(problems)} 条）",
                detail="; ".join(problems[:12]))

    # -- accessors --------------------------------------------------------
    @property
    def balance_doc(self) -> dict:
        return self.balance

    @property
    def balance(self) -> dict:
        return self._entities["balance"]["world_balance"]

    def set_override(self, path: tuple, value) -> None:
        """In-memory balance override used by the sensitivity sweep.

        Nothing is written to disk; a fresh WorldModel has no overrides.
        """
        self.overrides[tuple(path)] = value

    def clear_overrides(self) -> None:
        self.overrides.clear()

    def b(self, *path, default=None):
        """Read a nested balance parameter, e.g. `wm.b('growth', 'essence_base')`."""
        if tuple(path) in getattr(self, "overrides", {}):
            return self.overrides[tuple(path)]
        node = self.balance
        for key in path:
            if not isinstance(node, dict) or key not in node:
                if default is not None:
                    return default
                raise DataMissingError(f"balance.json 缺少参数 {'/'.join(str(p) for p in path)}")
            node = node[key]
        return node

    def all(self, entity_type: str) -> list[dict]:
        if entity_type not in self._entities:
            raise DataMissingError(f"未知实体类型：{entity_type}")
        return list(self._entities[entity_type].values())

    def by_id(self, entity_type: str, entity_id: str) -> dict:
        table = self._entities.get(entity_type)
        if table is None:
            raise DataMissingError(f"未知实体类型：{entity_type}")
        if entity_id not in table:
            raise DataMissingError(f"{entity_type} 中不存在 id={entity_id!r}")
        return table[entity_id]

    def maybe(self, entity_type: str, entity_id: str) -> dict | None:
        return self._entities.get(entity_type, {}).get(entity_id)

    # typed shortcuts
    @property
    def realms(self) -> dict[str, dict]:
        return self._entities["realm"]

    @property
    def paths(self) -> dict[str, dict]:
        return self._entities["path"]

    @property
    def gu(self) -> dict[str, dict]:
        return self._entities["gu"]

    @property
    def economy(self) -> dict:
        return self._entities["economy"]["south_jiang_mortal_economy"]

    @property
    def factions(self) -> dict[str, dict]:
        return self._entities["faction"]

    @property
    def regions(self) -> dict[str, dict]:
        return self._entities["region"]

    @property
    def events(self) -> dict[str, dict]:
        return self._entities["event"]

    @property
    def loot(self) -> dict:
        return self._entities["loot"]["south_jiang_loot"]

    @property
    def manifest(self) -> dict:
        return self._entities["manifest"]["world_model_manifest"]

    @property
    def version(self) -> str:
        return self.manifest["version"]

    def layers(self) -> list[dict]:
        return sorted((r for r in self.regions.values() if r["entity_kind"] == "layer"),
                      key=lambda r: r["layer"])

    def region(self, layer: int) -> dict:
        return self.by_id("region", f"layer_{int(layer)}")

    def realm(self, rank: int, stage: str = "initial") -> dict:
        rank = max(1, min(9, int(rank)))
        if stage not in ("initial", "middle", "upper", "peak"):
            stage = "initial"
        return self.by_id("realm", f"r{rank}_{stage}")

    def gu_def(self, gu_id: str) -> dict:
        return self.by_id("gu", gu_id)

    def material(self, material_id: str) -> dict:
        for m in self.loot["materials"]:
            if m["id"] == material_id:
                return m
        raise DataMissingError(f"loot.json 中不存在蛊材 id={material_id!r}")

    def summary(self) -> dict:
        return {
            "version": self.version,
            "data_digest": self.data_digest,
            "schema_checks": self.schema_checks,
            "counts": {t: len(tbl) for t, tbl in sorted(self._entities.items())},
            "gu_effect_sources": self.documents["gu"].get("gu_stats", {}).get("by_effect_source", {}),
        }
