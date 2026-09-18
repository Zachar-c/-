"""Minimal JSON-Schema (draft-07 subset) validator using ONLY the Python
standard library.

The environment has no `jsonschema` package and we must not install one, so this
module implements the subset of draft-07 that world-model.schema.json actually
uses:

  type (incl. type arrays), enum, const, required, properties,
  additionalProperties (bool | schema), patternProperties, items (schema),
  minItems, maxItems, uniqueItems, minProperties, maxProperties,
  minimum, maximum, exclusiveMinimum, exclusiveMaximum, multipleOf,
  minLength, maxLength, pattern, allOf, anyOf, oneOf, not, if/then/else,
  $ref (local "#/$defs/NAME" pointers only), definitions/$defs lookup.

Errors are returned as a list of human-readable strings carrying a JSON path.
"""

from __future__ import annotations

import re
from typing import Any

MAX_ERRORS = 400

_TYPE_MAP = {
    "object": dict,
    "array": list,
    "string": str,
    "number": (int, float),
    "integer": int,
    "boolean": bool,
    "null": type(None),
}


def _type_ok(value: Any, type_name: str) -> bool:
    if type_name == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if type_name == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if type_name == "boolean":
        return isinstance(value, bool)
    if type_name == "object":
        return isinstance(value, dict)
    if type_name == "array":
        return isinstance(value, list)
    if type_name == "string":
        return isinstance(value, str)
    if type_name == "null":
        return value is None
    return True


def _type_name(value: Any) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, int):
        return "integer"
    if isinstance(value, float):
        return "number"
    if isinstance(value, str):
        return "string"
    if isinstance(value, list):
        return "array"
    if isinstance(value, dict):
        return "object"
    return type(value).__name__


def _resolve_ref(root: dict, ref: str) -> dict:
    if not ref.startswith("#/"):
        raise ValueError(f"unsupported non-local $ref: {ref}")
    node: Any = root
    for part in ref[2:].split("/"):
        part = part.replace("~1", "/").replace("~0", "~")
        if not isinstance(node, dict) or part not in node:
            raise ValueError(f"unresolvable $ref: {ref}")
        node = node[part]
    return node


class Validator:
    """Validates instances against a schema document loaded from JSON."""

    def __init__(self, schema: dict):
        self.root = schema
        self.errors: list[str] = []
        self.checks = 0

    # -- public -----------------------------------------------------------
    def validate(self, instance: Any, schema: dict | None = None, path: str = "$") -> list[str]:
        self.errors = []
        self.checks = 0
        self._walk(instance, schema if schema is not None else self.root, path)
        return self.errors

    def validate_document(self, instance: dict, entity_type: str, path: str = "$") -> list[str]:
        """Validate an envelope document, then bind each entity to $defs[entity_type]."""
        self.errors = []
        self.checks = 0
        self._walk(instance, self.root, path)
        entity_schema = self.root.get("$defs", {}).get(entity_type)
        if entity_schema is None:
            self._err(path, f"unknown entity_type {entity_type!r}: no matching $defs entry")
            return self.errors
        if isinstance(instance, dict):
            declared = instance.get("entity_type")
            if declared != entity_type:
                self._err(path + ".entity_type", f"declared {declared!r} but {entity_type!r} was requested")
            entities = instance.get("entities")
            if isinstance(entities, list):
                for i, ent in enumerate(entities):
                    self._walk(ent, entity_schema, f"{path}.entities[{i}]")
        return self.errors

    # -- internals --------------------------------------------------------
    def _err(self, path: str, msg: str) -> None:
        if len(self.errors) < MAX_ERRORS:
            self.errors.append(f"{path}: {msg}")
        elif len(self.errors) == MAX_ERRORS:
            self.errors.append(f"{path}: ... (error list truncated at {MAX_ERRORS})")

    def _walk(self, inst: Any, schema: Any, path: str) -> None:
        if not isinstance(schema, dict):
            return
        self.checks += 1

        if "$ref" in schema:
            self._walk(inst, _resolve_ref(self.root, schema["$ref"]), path)
            # draft-07: other keywords next to $ref are ignored; we keep walking
            # only if the reference target asked for it, matching common practice.

        if "type" in schema:
            allowed = schema["type"]
            allowed = allowed if isinstance(allowed, list) else [allowed]
            if not any(_type_ok(inst, t) for t in allowed):
                self._err(path, f"expected type {allowed}, got {_type_name(inst)}")
                return

        if "const" in schema and inst != schema["const"]:
            self._err(path, f"expected const {schema['const']!r}, got {inst!r}")
        if "enum" in schema and not any(_loose_eq(inst, v) for v in schema["enum"]):
            self._err(path, f"value {inst!r} not in enum {schema['enum']!r}")

        if isinstance(inst, (int, float)) and not isinstance(inst, bool):
            self._numeric(inst, schema, path)
        if isinstance(inst, str):
            self._string(inst, schema, path)
        if isinstance(inst, list):
            self._array(inst, schema, path)
        if isinstance(inst, dict):
            self._object(inst, schema, path)

        for sub in schema.get("allOf", []):
            self._walk(inst, sub, path)
        if "anyOf" in schema:
            if not self._any_pass(inst, schema["anyOf"], path):
                self._err(path, "no anyOf branch matched")
        if "oneOf" in schema:
            hits = sum(1 for sub in schema["oneOf"] if self._passes(inst, sub, path))
            if hits != 1:
                self._err(path, f"oneOf matched {hits} branches (expected exactly 1)")
        if "not" in schema and self._passes(inst, schema["not"], path):
            self._err(path, "instance matched a `not` schema")
        if "if" in schema:
            if self._passes(inst, schema["if"], path):
                if "then" in schema:
                    self._walk(inst, schema["then"], path)
            elif "else" in schema:
                self._walk(inst, schema["else"], path)

    def _numeric(self, inst: float, schema: dict, path: str) -> None:
        if "minimum" in schema and inst < schema["minimum"]:
            self._err(path, f"{inst} < minimum {schema['minimum']}")
        if "maximum" in schema and inst > schema["maximum"]:
            self._err(path, f"{inst} > maximum {schema['maximum']}")
        if "exclusiveMinimum" in schema and inst <= schema["exclusiveMinimum"]:
            self._err(path, f"{inst} <= exclusiveMinimum {schema['exclusiveMinimum']}")
        if "exclusiveMaximum" in schema and inst >= schema["exclusiveMaximum"]:
            self._err(path, f"{inst} >= exclusiveMaximum {schema['exclusiveMaximum']}")
        if "multipleOf" in schema and schema["multipleOf"]:
            if abs(inst / schema["multipleOf"] - round(inst / schema["multipleOf"])) > 1e-9:
                self._err(path, f"{inst} is not a multiple of {schema['multipleOf']}")

    def _string(self, inst: str, schema: dict, path: str) -> None:
        if "minLength" in schema and len(inst) < schema["minLength"]:
            self._err(path, f"string length {len(inst)} < minLength {schema['minLength']}")
        if "maxLength" in schema and len(inst) > schema["maxLength"]:
            self._err(path, f"string length {len(inst)} > maxLength {schema['maxLength']}")
        if "pattern" in schema and not re.search(schema["pattern"], inst):
            self._err(path, f"string {inst!r} does not match pattern {schema['pattern']!r}")

    def _array(self, inst: list, schema: dict, path: str) -> None:
        if "minItems" in schema and len(inst) < schema["minItems"]:
            self._err(path, f"array length {len(inst)} < minItems {schema['minItems']}")
        if "maxItems" in schema and len(inst) > schema["maxItems"]:
            self._err(path, f"array length {len(inst)} > maxItems {schema['maxItems']}")
        if schema.get("uniqueItems") and len({_hashable(x) for x in inst}) != len(inst):
            self._err(path, "array items are not unique")
        item_schema = schema.get("items")
        if isinstance(item_schema, dict):
            for i, item in enumerate(inst):
                self._walk(item, item_schema, f"{path}[{i}]")

    def _object(self, inst: dict, schema: dict, path: str) -> None:
        for key in schema.get("required", []):
            if key not in inst:
                self._err(path, f"missing required property {key!r}")
        if "minProperties" in schema and len(inst) < schema["minProperties"]:
            self._err(path, f"object has {len(inst)} properties < minProperties {schema['minProperties']}")
        if "maxProperties" in schema and len(inst) > schema["maxProperties"]:
            self._err(path, f"object has {len(inst)} properties > maxProperties {schema['maxProperties']}")
        props = schema.get("properties", {})
        for key, sub in props.items():
            if key in inst:
                self._walk(inst[key], sub, f"{path}.{key}")
        patterns = schema.get("patternProperties", {})
        for key, value in inst.items():
            for pat, sub in patterns.items():
                if re.search(pat, key):
                    self._walk(value, sub, f"{path}.{key}")
        extra = schema.get("additionalProperties")
        if extra is not None:
            known = set(props)
            for key, value in inst.items():
                if key in known:
                    continue
                if any(re.search(p, key) for p in patterns):
                    continue
                if extra is False:
                    self._err(path, f"additional property {key!r} is not allowed")
                elif isinstance(extra, dict):
                    self._walk(value, extra, f"{path}.{key}")

    def _passes(self, inst: Any, schema: dict, path: str) -> bool:
        sub = Validator(self.root)
        return not sub.validate(inst, schema, path)

    def _any_pass(self, inst: Any, schemas: list, path: str) -> bool:
        return any(self._passes(inst, s, path) for s in schemas)


def _loose_eq(a: Any, b: Any) -> bool:
    if isinstance(a, bool) or isinstance(b, bool):
        return a is b
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return a == b
    return a == b


def _hashable(value: Any) -> str:
    import json
    return json.dumps(value, sort_keys=True, ensure_ascii=False)


def load_schema(path) -> dict:
    import json
    from pathlib import Path
    with Path(path).open(encoding="utf-8") as fh:
        return json.load(fh)
