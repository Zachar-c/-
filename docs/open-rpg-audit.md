# GDQuest Open RPG Audit

## Audit Scope

- Upstream URL: https://github.com/gdquest-demos/godot-open-rpg.git
- Pinned commit: `19bd328fae9e4b534d3bb6db380a3d871d6ea58f`
- Upstream license: MIT, retained at `vendor/godot-open-rpg/LICENSE`
- Audited against the vendored source tree on 2026-08-21.

The upstream repository is an educational Godot 4.6.2 demo, not a framework.
It owns mutable scene state, autoloads, traditional party combat, and a
persisted item inventory. Nanjiang domain rules must remain local, pure where
practical, and event-log driven.

## Reuse Through Adapter

- `vendor/godot-open-rpg/src/combat/combat.gd`: candidate reference for
  turn-order presentation only; it may be reached only through
  `OpenRpgAdapter` after the adapter has translated local battle snapshots.
  It cannot decide Gu effects, retreat, outcomes, or mutate `RunState`.
- `vendor/godot-open-rpg/src/combat/ui/ui_combat.gd`: candidate presentation
  unit for later adapter-wrapped combat input and display. The project must
  submit its commands to the local resolver and render the resolver result;
  it must not emit or consume Nanjiang domain mutations directly.
- `vendor/godot-open-rpg/src/combat/ui/action_menu/ui_action_menu.gd`:
  candidate visual action-list behavior only. Any later reuse must map the
  fixed four Gu slots and declared inheritance moves from local data, with no
  upstream `BattlerAction` or target-selection state owning game rules.
- `vendor/godot-open-rpg/src/combat/ui/battler_entry/ui_battler_entry.gd`:
  candidate combat-stat display reference only. It may display an adapter DTO,
  never a mutable `RunState` or upstream `BattlerStats` as the source of truth.
- `vendor/godot-open-rpg/src/field/ui/inventory/ui_inventory_item.gd`:
  candidate count-display reference only. No inventory scene or script may
  persist, add, remove, or interpret Gu, stone, clues, relations, or evidence.

## Do Not Reuse

- `vendor/godot-open-rpg/src/common/inventory.gd` and
  `vendor/godot-open-rpg/src/field/ui/inventory/ui_inventory.gd`: these own a
  fixed traditional-RPG item enum and save to `user://inventory.tres`, which
  conflicts with the local immutable event log and data-driven Gu system.
- `vendor/godot-open-rpg/src/combat/battlers/battler.gd`,
  `vendor/godot-open-rpg/src/combat/battlers/battler_roster.gd`, and
  `vendor/godot-open-rpg/src/combat/actions/`: these own mutable battler,
  action, target, energy, health, and defeat state that cannot be authoritative
  for deterministic local Gu combat.
- `vendor/godot-open-rpg/src/field/`, `vendor/godot-open-rpg/overworld/`, and
  `vendor/godot-open-rpg/src/main.tscn`: upstream world, story, maps,
  cutscenes, character progression, dialogue flow, and traditional RPG
  economy are outside the Nanjiang slice.
- `vendor/godot-open-rpg/addons/dialogic/`: not used for Nanjiang dialogue.
  The game requires a bounded JSON-schema gateway with an offline template
  fallback and replayed validated replies.
- `vendor/godot-open-rpg/assets/`, `vendor/godot-open-rpg/combat/battlers/`,
  and `vendor/godot-open-rpg/combat/arenas/`: upstream art, audio, battlers,
  arenas, and example content are not part of the Nanjiang game design.

## Replace

- The layered node map and fog-of-information rules.
- The Gu catalog, four-slot loadout, inheritance moves, and all data tables.
- Local deterministic social state, NPC knowledge, relations, deadlines, and
  bounded dialogue gateway.
- Combat resolution, fixed enemy behavior tables, nonlethal objectives, and
  retreat costs.
- Cultivation, essence, wounds, body imprints, ascension preparation, and all
  three endings.
- Immutable structured event logs, saves/replay, player-known facts, and
  ending journals.
- Nanjiang scenes, presentation controllers, and all player-facing content.

## Integration Rule

No `gu_zu` script may preload, load, extend, or otherwise import an upstream
path except through `scripts/integration/open_rpg_adapter.gd`, added in Task 2.
The adapter owns all conversion between local immutable state snapshots and
any optional upstream presentation primitive. Vendored source remains
unmodified.
