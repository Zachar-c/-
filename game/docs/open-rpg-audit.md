# GDQuest Open RPG Audit

> 2026-09-20 A 清理：上游源码目录已删除；本文只保留审计记录。
> MIT 许可文本与固定提交号已迁入 `THIRD_PARTY_NOTICES.md`。

## Provenance

- Upstream URL: https://github.com/gdquest-demos/godot-open-rpg.git
- Pinned commit: `19bd328fae9e4b534d3bb6db380a3d871d6ea58f`
- Upstream license: MIT, retained at `vendor/godot-open-rpg/LICENSE`
- The upstream source was reviewed on 2026-08-21 and is not a runtime dependency.

## Findings

The project uses its own deterministic domain, presentation and content systems.
No local script imports, loads or extends the upstream source tree. The former
adapter-only battle context was reduced to a two-field local dictionary in
`BattleResolver`; no upstream API remains in the product.

The vendored source was removed after this audit. The license and attribution
remain in the repository because local theme assets were derived from the pinned
MIT-licensed source, as documented in `THIRD_PARTY_NOTICES.md`.
